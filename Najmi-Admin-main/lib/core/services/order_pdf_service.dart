import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/orders/order_model.dart';
import 'package:intl/intl.dart';

class OrderPdfService {
  // ─── Brand colours ────────────────────────────────────────────────────────
  static const _primary   = PdfColor.fromInt(0xFF1E3A5F);   // deep navy
  static const _accent    = PdfColor.fromInt(0xFF2563EB);   // blue
  static const _success   = PdfColor.fromInt(0xFF16A34A);   // green
  static const _warning   = PdfColor.fromInt(0xFFD97706);   // amber
  static const _light     = PdfColor.fromInt(0xFFF8FAFC);   // almost-white
  static const _border    = PdfColor.fromInt(0xFFE2E8F0);   // light grey
  static const _textDark  = PdfColor.fromInt(0xFF1E293B);
  static const _textMuted = PdfColor.fromInt(0xFF64748B);

  static Future<void> generateAndDownloadOrderPdf(Order order) async {
    final pdf      = pw.Document();
    final dateFmt  = DateFormat('dd MMM yyyy');
    final timeFmt  = DateFormat('hh:mm a');
    final currFmt  = NumberFormat('#,##0.00', 'en_IN');

    final now        = DateTime.now();
    final invoiceNo  = 'INV-${order.orderId ?? order.id.substring(0, 8).toUpperCase()}';
    final orderDate  = dateFmt.format(order.createdAt);
    final printedOn  = '${dateFmt.format(now)}  ${timeFmt.format(now)}';

    // ── Derived totals ──────────────────────────────────────────────────────
    final items = order.items ?? [];
    final subtotal = items.fold(0.0, (s, i) => s + i.totalPrice);

    // Try to read stored tax / delivery from the order JSON fields
    // These may not be in the model; fall back to estimating 18% GST.
    const gstRate    = 0.18;
    final gstAmount  = subtotal * gstRate;
    final delivery   = 0.0;   // adjust if you store delivery separately
    final grandTotal = order.totalAmount ?? (subtotal + gstAmount + delivery);

    final bool isPaid = [
      'paid', 'captured', 'success', 'completed',
    ].contains(order.paymentStatus?.toLowerCase());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        header: (ctx) => _buildHeader(ctx, invoiceNo, orderDate, printedOn),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 16),

          // ── Bill-To + Payment Status row ─────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _buildBillTo(order)),
              pw.SizedBox(width: 24),
              pw.Expanded(child: _buildOrderMeta(order, isPaid, dateFmt)),
            ],
          ),

          pw.SizedBox(height: 24),

          // ── Items table ──────────────────────────────────────────────────
          _buildItemsTable(items, currFmt),

          pw.SizedBox(height: 20),

          // ── Totals ───────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 280,
                child: _buildTotalsBlock(subtotal, gstAmount, delivery, grandTotal, currFmt),
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // ── Notes / Terms ────────────────────────────────────────────────
          // _buildTerms(),
        ],
      ),
    );

    final pdfName = '$invoiceNo.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: pdfName,
    );
  }

  // ─── Page header ──────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(
    pw.Context ctx,
    String invoiceNo,
    String orderDate,
    String printedOn,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // top bar
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const pw.BoxDecoration(color: _primary),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CONTRACTO',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Building Materials & Supplies',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromInt(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'TAX INVOICE',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    invoiceNo,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColor.fromInt(0xFF93C5FD),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // sub-header: company address + date strip
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          color: _light,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'GST No: 27XXXXX0000X1ZX  |  support@contracto.com  |  +91 9876543210',
                style: const pw.TextStyle(fontSize: 8, color: _textMuted),
              ),
              pw.Text(
                'Printed: $printedOn',
                style: const pw.TextStyle(fontSize: 8, color: _textMuted),
              ),
            ],
          ),
        ),

        pw.Divider(thickness: 0.5, color: _border),
      ],
    );
  }

  // ─── Page footer ──────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5, color: _border),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Thank you for your business!  —  Contracto',
              style: pw.TextStyle(
                fontSize: 8,
                fontStyle: pw.FontStyle.italic,
                color: _textMuted,
              ),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _textMuted),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Bill-To block ────────────────────────────────────────────────────────
  static pw.Widget _buildBillTo(Order order) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _light,
        border: pw.Border.all(color: _border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BILL TO',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _textMuted,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            order.customerName ?? 'N/A',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _textDark,
            ),
          ),
          pw.SizedBox(height: 4),
          if (order.customerEmail != null)
            pw.Text(order.customerEmail!, style: const pw.TextStyle(fontSize: 9, color: _textMuted)),
          if (order.customerPhone != null)
            pw.Text(order.customerPhone!, style: const pw.TextStyle(fontSize: 9, color: _textMuted)),
        ],
      ),
    );
  }

  // ─── Order meta (status, dates) ───────────────────────────────────────────
  static pw.Widget _buildOrderMeta(Order order, bool isPaid, DateFormat dateFmt) {
    final statusColor = _statusColor(order.status);
    final payColor    = isPaid ? _success : _warning;
    final payLabel    = isPaid ? 'PAID' : (order.paymentStatus?.toUpperCase() ?? 'PENDING');

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _light,
        border: pw.Border.all(color: _border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ORDER DETAILS',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _textMuted,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 6),
          _metaRow('Order ID',   order.orderId ?? '#${order.id.substring(0, 8)}'),
          _metaRow('Order Date', dateFmt.format(order.createdAt)),
          if (order.updatedAt != null)
            _metaRow('Updated',  dateFmt.format(order.updatedAt!)),
          pw.SizedBox(height: 8),
          // Status chips
          pw.Row(
            children: [
              _chip(order.status.toUpperCase(), statusColor),
              pw.SizedBox(width: 8),
              _chip(payLabel, payColor),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _textMuted)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textDark)),
        ],
      ),
    );
  }

  static pw.Widget _chip(String label, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static PdfColor _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered': return _success;
      case 'pending':   return _warning;
      case 'cancelled':
      case 'returned':  return PdfColor.fromInt(0xFFEF4444);
      case 'confirmed': return _accent;
      case 'processing':return PdfColor.fromInt(0xFF0EA5E9);
      case 'in_transport': return PdfColor.fromInt(0xFF8B5CF6);
      default:          return _textMuted;
    }
  }

  // ─── Items table ──────────────────────────────────────────────────────────
  static pw.Widget _buildItemsTable(List<OrderItem> items, NumberFormat fmt) {
    const headerStyle = pw.TextStyle(
      fontSize: 9,
      color: PdfColors.white,
    );

    pw.Widget cell(String text, {
      pw.TextAlign align = pw.TextAlign.left,
      pw.TextStyle? style,
      pw.EdgeInsets padding = const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    }) {
      return pw.Padding(
        padding: padding,
        child: pw.Text(text, textAlign: align, style: style),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),   // Product
        1: const pw.FlexColumnWidth(1),   // HSN / SKU
        2: const pw.FlexColumnWidth(1),   // Qty
        3: const pw.FlexColumnWidth(1.2), // Unit Price
        4: const pw.FlexColumnWidth(1.2), // Total
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _primary),
          children: [
            cell('Product / Description', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            cell('HSN / SKU',  style: headerStyle, align: pw.TextAlign.center),
            cell('Qty',        style: headerStyle, align: pw.TextAlign.center),
            cell('Unit Price', style: headerStyle, align: pw.TextAlign.right),
            cell('Amount',     style: headerStyle, align: pw.TextAlign.right),
          ],
        ),

        // Item rows
        ...items.asMap().entries.map((entry) {
          final idx  = entry.key;
          final item = entry.value;
          final bg   = idx.isEven ? PdfColors.white : _light;
          final qty  = item.quantity.truncateToDouble() == item.quantity
              ? item.quantity.toInt().toString()
              : item.quantity.toStringAsFixed(2);
          final unit = item.unit != null ? ' ${item.unit}' : '';

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.productName ?? 'Unknown Product',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textDark),
                    ),
                    if (item.category != null)
                      pw.Text(item.category!, style: const pw.TextStyle(fontSize: 7, color: _textMuted)),
                  ],
                ),
              ),
              cell(item.sku ?? '—',
                style: const pw.TextStyle(fontSize: 8, color: _textMuted),
                align: pw.TextAlign.center),
              cell('$qty$unit',
                style: const pw.TextStyle(fontSize: 9, color: _textDark),
                align: pw.TextAlign.center),
              cell('₹${fmt.format(item.unitPrice)}',
                style: const pw.TextStyle(fontSize: 9, color: _textDark),
                align: pw.TextAlign.right),
              cell('₹${fmt.format(item.totalPrice)}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textDark),
                align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  // ─── Totals block ─────────────────────────────────────────────────────────
  static pw.Widget _buildTotalsBlock(
    double subtotal,
    double gstAmount,
    double delivery,
    double grandTotal,
    NumberFormat fmt,
  ) {
    pw.Widget row(String label, String value, {bool bold = false, bool big = false, PdfColor? valueColor}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: big ? 11 : 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: _textMuted,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: big ? 13 : 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: valueColor ?? _textDark,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _light,
        border: pw.Border.all(color: _border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        children: [
          row('Subtotal (excl. GST)',     '₹${fmt.format(subtotal)}'),
          row('GST @ 18%  (CGST 9 + SGST 9)',  '₹${fmt.format(gstAmount)}'),
          if (delivery > 0)
            row('Delivery Charges', '₹${fmt.format(delivery)}'),
          pw.Divider(thickness: 0.8, color: _border),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const pw.BoxDecoration(color: _primary),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'GRAND TOTAL',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  '₹${fmt.format(grandTotal)}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Terms ────────────────────────────────────────────────────────────────
  static pw.Widget _buildTerms() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _light,
        border: pw.Border.all(color: _border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TERMS & CONDITIONS',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _textMuted,
              letterSpacing: 1.1,
            ),
          ),
          pw.SizedBox(height: 6),
          ...[
            '1. All goods once sold cannot be returned without prior written approval.',
            '2. Payment is due within 30 days of invoice date.',
            '3. Disputes, if any, shall be subject to jurisdiction of Contracto\'s city courts.',
            '4. This is a computer-generated invoice and does not require a signature.',
          ].map(
            (t) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(t, style: const pw.TextStyle(fontSize: 8, color: _textMuted)),
            ),
          ),
        ],
      ),
    );
  }
}
