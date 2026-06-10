import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:contracto_app/features/brands/data/models/brand_model.dart';
import 'package:contracto_app/features/brands/data/services/brand_service.dart';
import 'package:contracto_app/features/brands/presentation/screens/brand_products_screen.dart';
import 'package:contracto_app/shared/widgets/custom_network_image.dart';

class AllBrandsScreen extends StatefulWidget {
  const AllBrandsScreen({super.key});

  @override
  State<AllBrandsScreen> createState() => _AllBrandsScreenState();
}

class _AllBrandsScreenState extends State<AllBrandsScreen> {
  final _brandService = BrandService();
  List<BrandModel> _brands = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<String> _alphabet = List.generate(26, (index) => String.fromCharCode(index + 65));

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    try {
      setState(() => _isLoading = true);
      final brands = await _brandService.getBrands(activeOnly: true);
      brands.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _brands = brands;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading brands: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchBrands(String query) async {
    try {
      setState(() => _isLoading = true);
      final brands = await _brandService.searchBrands(query);
      setState(() {
        final activeBrands = brands.where((b) => b.isActive).toList();
        activeBrands.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _brands = activeBrands;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching brands: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _navigateToBrandProducts(BrandModel brand) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrandProductsScreen(brand: brand),
      ),
    );
  }

  void _scrollToLetter(String letter) {
    if (_brands.isEmpty) return;
    final index = _brands.indexWhere((b) => b.name.toUpperCase().startsWith(letter));
    if (index != -1) {
      final row = index ~/ 3;
      final screenWidth = MediaQuery.of(context).size.width;
      final gridWidth = screenWidth - 32; 
      final itemWidth = (gridWidth - 32) / 3; 
      final itemHeight = itemWidth / 0.80; 
      final offset = row * (itemHeight + 16);
      
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'All Brands',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for brands...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                        onPressed: () {
                          _searchController.clear();
                          _loadBrands();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onChanged: (value) {
                if (value.isEmpty) {
                  _loadBrands();
                } else {
                  _searchBrands(value);
                }
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildShimmerLoading()
                : _brands.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.business_center_outlined, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No brands found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 16, 28, 16), 
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.80,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _brands.length,
                            itemBuilder: (context, index) {
                              final brand = _brands[index];
                              return GestureDetector(
                                onTap: () => _navigateToBrandProducts(brand),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.95),
                                        Colors.white.withValues(alpha: 0.50),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1E293B).withValues(alpha: 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: brand.logoUrl != null
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(2.0),
                                                      child: CustomNetworkImage(
                                                        imageUrl: brand.logoUrl!,
                                                        fit: BoxFit.contain,
                                                        errorWidget: Icon(Icons.business, color: Colors.grey[400], size: 28),
                                                      ),
                                                    ),
                                                  )
                                                : Icon(Icons.business, color: Colors.grey[400], size: 28),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          brand.name,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E293B),
                                            letterSpacing: -0.2,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (brand.catalogUrl != null) ...[
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFBFDBFE)),
                                            ),
                                            child: const Text(
                                              'Catalog',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (_brands.isNotEmpty && _searchController.text.isEmpty)
                            Positioned(
                              right: 2,
                              top: 2,
                              bottom: 2,
                              child: Container(
                                width: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: GestureDetector(
                                  onVerticalDragUpdate: (details) {
                                    final renderBox = context.findRenderObject() as RenderBox;
                                    final localPosition = renderBox.globalToLocal(details.globalPosition);
                                    final containerTopOffset = 80; 
                                    final index = ((localPosition.dy - containerTopOffset) / 20).clamp(0, 25).toInt();
                                    _scrollToLetter(_alphabet[index]);
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: _alphabet.map((letter) {
                                      return InkWell(
                                        onTap: () => _scrollToLetter(letter),
                                        child: Padding(
                                          padding: const EdgeInsets.all(1.0),
                                          child: Text(
                                            letter,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.80,
        crossAxisSpacing: 10,
        mainAxisSpacing: 16,
      ),
      itemCount: 15,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[200]!,
          highlightColor: Colors.white,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}
