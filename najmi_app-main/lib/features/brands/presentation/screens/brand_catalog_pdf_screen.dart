import 'package:flutter/material.dart';
import 'package:contracto_app/shared/widgets/custom_network_image.dart';
import 'package:contracto_app/features/brands/data/models/brand_model.dart';
import 'package:url_launcher/url_launcher.dart';

class BrandCatalogPdfScreen extends StatefulWidget {
  final BrandModel brand;

  const BrandCatalogPdfScreen({
    super.key,
    required this.brand,
  });

  @override
  State<BrandCatalogPdfScreen> createState() => _BrandCatalogPdfScreenState();
}

class _BrandCatalogPdfScreenState extends State<BrandCatalogPdfScreen> {
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    // Automatically try to open the PDF when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openPdfInBrowser();
    });
  }

  Future<void> _openPdfInBrowser() async {
    if (_isOpening) return;
    
    setState(() => _isOpening = true);

    try {
      final catalogUrl = widget.brand.catalogUrl;
      if (catalogUrl == null || catalogUrl.trim().isEmpty) {
        if (mounted) {
          setState(() => _isOpening = false);
          _showErrorDialog('Catalog URL is not available');
        }
        return;
      }

      final uri = Uri.parse(catalogUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (mounted) {
          setState(() => _isOpening = false);
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening catalog in browser...'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isOpening = false);
          _showErrorDialog('Cannot open the catalog URL');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOpening = false);
        _showErrorDialog('Error opening catalog: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openPdfInBrowser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[700]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                
              ),
              child: widget.brand.logoUrl != null
                  ? ClipOval(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CustomNetworkImage(
                          imageUrl: widget.brand.logoUrl!,
                          fit: BoxFit.contain,
                          width: 40,
                          height: 40,
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.business,
                                color: Colors.grey[400], size: 20),
                          ),
                        ),
                      ),
                    )
                  : Icon(Icons.business, color: Colors.grey[400], size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.brand.name} Catalog',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'PDF Catalog',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // PDF Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.picture_as_pdf,
                  size: 64,
                  color: Colors.red[600],
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'View Catalog',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              
              // Description
              Text(
                _isOpening 
                    ? 'Opening catalog in your browser...'
                    : 'The catalog will open in your default browser or PDF viewer app.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Open Button
              if (!_isOpening)
                ElevatedButton.icon(
                  onPressed: _openPdfInBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open Catalog'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                )
              else
                const CircularProgressIndicator(),
              
              const SizedBox(height: 16),
              
              // Info text
              if (widget.brand.catalogUrl != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue[100]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap "Open Catalog" to view the PDF in your browser',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
