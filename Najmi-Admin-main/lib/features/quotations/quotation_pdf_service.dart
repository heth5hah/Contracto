import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File; // Keep File but use it conditionally

class QuotationPdfService {
  // Fetch detailed quotation data including items
  static Future<Map<String, dynamic>?> fetchDetailedQuotation(
      String quotationId) async {
    try {
      print('DEBUG: PDF_FETCH - Fetching quotation ID: "$quotationId"');
      if (quotationId.isEmpty || quotationId == 'null') {
        throw Exception('Invalid Quotation ID: "$quotationId"');
      }

      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('quote_requests')
          .select('''
            *,
            quote_request_items(*,products(*,brands(*))),
            quotes(*,quote_items(*)),
            users:user_id(*)
          ''')
          .eq('id', quotationId)
          .maybeSingle();

      if (response == null) {
        print('ERROR: PDF_FETCH - No quotation found with ID: "$quotationId"');
        return null;
      }

      print('DEBUG: PDF - Fetch successful. Data keys: ${response.keys}');
      return response;
    } catch (e, st) {
      print('ERROR: PDF - Exception during fetch: $e');
      print('STACKTRACE: $st');
      throw Exception('Data fetch error: $e');
    }
  }

  // Generate PDF for a quotation
  static Future<Uint8List> generateQuotationPdf(
      Map<String, dynamic> quotationData) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final currencyFormat = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);

    // Extract data
    final quotationId = quotationData['id'] ?? 'N/A';
    final productName = quotationData['product_name'] ?? 'N/A';
    final status = quotationData['status'] ?? 'pending';
    final adminStatus = quotationData['admin_status'] ?? 'new';
    // Extract priced items if available
    List<dynamic> pricedItems = [];
    final quotes = quotationData['quotes'] as List?;
    if (quotes != null && quotes.isNotEmpty) {
      pricedItems = (quotes.first['quote_items'] as List?) ?? [];
    }

    final transportCharges =
        (quotationData['transport_charges'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = (quotationData['tax_amount'] as num?)?.toDouble() ?? 
                     (quotes != null && quotes.isNotEmpty ? (quotes.first['tax_amount'] as num?)?.toDouble() : null) ?? 
                     0.0;
    final createdAt = quotationData['created_at'] != null
        ? DateTime.parse(quotationData['created_at'])
        : DateTime.now();
    final notes = quotationData['notes'] ?? 'No notes provided';
    
    // Extract user information
    final userData = quotationData['users'];
    final userEmail = userData?['email'] ?? quotationData['customer_email'] ?? 'N/A';
    final customerName = quotationData['customer_name'] ?? 
                        userData?['name'] ?? 
                        (userEmail != 'N/A' ? userEmail.split('@')[0] : null) ??
                        productName ??
                        'Unknown Customer';
    final customerEmail = userEmail;
    final customerPhone = quotationData['customer_phone'] ?? 
                         userData?['mobile'] ?? 
                         'N/A';
    final deliveryAddress = quotationData['delivery_address'] ?? 'N/A';

    // Extract items
    final requestItems = (quotationData['quote_request_items'] as List?) ?? [];
    
    
    // Use priced items for total calculation if available
    final displayItems = pricedItems.isNotEmpty ? pricedItems : requestItems;
    
    final totalAmountFromMain =
        (quotationData['total_amount'] as num?)?.toDouble() ?? 0.0;
    
    double subtotal = 0.0;
    for (var item in displayItems) {
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      final price = (item['unit_price'] as num?)?.toDouble() ?? 
                    (item['price'] as num?)?.toDouble() ?? 0.0;
      subtotal += quantity * price;
    }
    
    // Fallback if detailed items don't have prices but the main record does
    final grandTotal = (pricedItems.isEmpty && totalAmountFromMain > 0) 
        ? totalAmountFromMain 
        : (subtotal + transportCharges + taxAmount);

    print('DEBUG: PDF - Subtotal: $subtotal, Transport: $transportCharges, GrandTotal: $grandTotal');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'QUOTE REQUEST',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Request ID: #${quotationId.substring(0, 8)}',
                        style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        dateFormat.format(createdAt),
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: pw.BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          status.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            // Customer Information
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Customer Information',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Name:',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              customerName,
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              'Email:',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              customerEmail,
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (customerPhone != 'N/A') ...[
                              pw.Text(
                                'Phone:',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700,
                                ),
                              ),
                              pw.Text(
                                customerPhone,
                                style: const pw.TextStyle(fontSize: 12),
                              ),
                              pw.SizedBox(height: 8),
                            ],
                            if (deliveryAddress != 'N/A') ...[
                              pw.Text(
                                'Delivery Address:',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700,
                                ),
                              ),
                              pw.Text(
                                deliveryAddress,
                                style: const pw.TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Product Information
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Product: $productName',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Items Table
            pw.Text(
              pricedItems.isNotEmpty ? 'Quoted Items & Pricing' : 'Requested Items',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            
            if (displayItems.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.all(16),
                child: pw.Text(
                  'No items in this request',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Item',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Quantity',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      if (pricedItems.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Price',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          pricedItems.isNotEmpty ? 'Total' : 'Unit',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pricedItems.isNotEmpty ? pw.TextAlign.right : pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  ...displayItems.map((item) {
                     // Robust Brand Extraction
                     final productsData = item['products'];
                     final brandsFromProducts = productsData != null ? productsData['brands'] : null;
                     
                     final brand = (brandsFromProducts != null ? brandsFromProducts['name'] : null) ??
                                  (item['brands'] != null ? item['brands']['name'] : null) ??
                                  item['brand_name'] ??
                                  item['brand'];
                                  
                     // Robust Name Extraction
                     final baseName = item['quality_option_name'] ??
                         item['product_name'] ??
                         item['item_name'] ??
                         item['name'] ??
                         (productsData != null ? productsData['name'] : null) ??
                         (productsData != null ? productsData['product_name'] : null) ??
                         item['product_id'] ??
                         item['item_id'] ??
                         'Unknown Item';
                         
                     final itemName = brand != null ? '$baseName (Brand: $brand)' : baseName.toString();
                     final description = productsData != null ? productsData['description'] : null;
                    
                    final quantity = item['quantity'] ?? 0;
                    final unit = item['unit'] ?? 'units';
                    final price = (item['unit_price'] as num?)?.toDouble() ?? 
                                 (item['price'] as num?)?.toDouble() ?? 0.0;
                    final rowTotal = quantity * price;

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                itemName,
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                              ),
                              if (description != null && (description as String).isNotEmpty)
                                pw.Text(
                                  description,
                                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                                ),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            quantity.toString(),
                            style: const pw.TextStyle(fontSize: 11),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        if (pricedItems.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              currencyFormat.format(price),
                              style: const pw.TextStyle(fontSize: 11),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            pricedItems.isNotEmpty ? currencyFormat.format(rowTotal) : unit,
                            style: const pw.TextStyle(fontSize: 11),
                            textAlign: pricedItems.isNotEmpty ? pw.TextAlign.right : pw.TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            
            pw.SizedBox(height: 20),
            
            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (pricedItems.isNotEmpty)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Subtotal: ',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                        pw.Text(
                          currencyFormat.format(subtotal),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Transport Charges: ',
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        currencyFormat.format(transportCharges),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Tax: ',
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        currencyFormat.format(taxAmount),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Divider(color: PdfColors.grey400),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TOTAL AMOUNT: ',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        currencyFormat.format(grandTotal),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _getAdminStatusColor(adminStatus),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'Admin Status: ${adminStatus.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Notes
            if (notes.isNotEmpty && notes != 'No notes provided')
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Notes',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      notes,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            
            pw.SizedBox(height: 30),
            
            // Footer
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'This is a quote request document. Generated on ${dateFormat.format(DateTime.now())}',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Download PDF - opens print/share dialog
  static Future<void> downloadQuotationPdf(String quotationId) async {
    try {
      // Fetch detailed quotation data
      final quotationData = await fetchDetailedQuotation(quotationId);
      
      if (quotationData == null) {
        throw Exception('[PDF_DOWNLOAD_FETCH_FAIL] Could not retrieve quotation data from database.');
      }

      // Generate PDF
      final pdfBytes = await generateQuotationPdf(quotationData);

      if (!kIsWeb) {
        try {
          // Save to file first (mobile/desktop only)
          final directory = await getApplicationDocumentsDirectory();
          final dateFormat = DateFormat('yyyyMMdd_HHmmss');
          final fileName = 'quotation_${quotationId.substring(0, 8)}_${dateFormat.format(DateTime.now())}.pdf';
          final path = '${directory.path}/$fileName';
          // Using cross-platform way to write file or skipping if needed
        } catch (e) {
          print('Optional file save failed: $e');
        }
      }

      // Share/Print the PDF (this works on Web, iOS, Android, Desktop)
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Quotation_${quotationId.substring(0, 8)}',
      );
    } catch (e) {
      print('Error in PDF process: $e');
      rethrow;
    }
  }

  // Save PDF to file directly (alternative method)
  static Future<String> saveQuotationPdf(String quotationId) async {
    try {
      // Fetch detailed quotation data
      final quotationData = await fetchDetailedQuotation(quotationId);
      
      if (quotationData == null) {
        throw Exception('[PDF_SAVE_FETCH_FAIL] Could not retrieve quotation data from database.');
      }

      // Generate PDF
      final pdfBytes = await generateQuotationPdf(quotationData);

      if (kIsWeb) {
        return 'web_download'; // Return a mock path or handle appropriately on web
      }

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final dateFormat = DateFormat('yyyyMMdd_HHmmss');
      final fileName = 'quotation_${quotationId.substring(0, 8)}_${dateFormat.format(DateTime.now())}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      return file.path;
    } catch (e) {
      print('Error saving PDF: $e');
      rethrow;
    }
  }

  // Helper method to get status color
  static PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return PdfColors.amber;
      case 'quoted':
        return PdfColors.green;
      case 'accepted':
        return PdfColors.green700;
      case 'rejected':
        return PdfColors.red;
      case 'archived':
        return PdfColors.grey;
      default:
        return PdfColors.blue;
    }
  }

  // Helper method to get admin status color
  static PdfColor _getAdminStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return PdfColors.green;
      case 'processing':
        return PdfColors.amber;
      case 'closed':
        return PdfColors.grey;
      default:
        return PdfColors.blue;
    }
  }
}

