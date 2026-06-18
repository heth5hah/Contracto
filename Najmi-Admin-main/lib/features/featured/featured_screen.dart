import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'featured_providers.dart';
import '../products/products_provider.dart';
import '../products/product_model.dart';
import '../brands/brands_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dotted_border/dotted_border.dart';

class FeaturedScreen extends ConsumerWidget {
  const FeaturedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredProductsAsync = ref.watch(featuredProductsProvider);
    final featuredBrandsAsync = ref.watch(featuredBrandsProvider);
    final imageSlidesAsync = ref.watch(imageSlidesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 16,
                        spacing: 16,
                        children: [
                          const Text(
                            'Featured Management',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _showAddFeaturedProductDialog(context, ref),
                                icon: const Icon(Icons.star_outline),
                                label: const Text('Add Featured Product'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(180, 42),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showAddFeaturedBrandDialog(context, ref),
                                icon: const Icon(Icons.branding_watermark_outlined),
                                label: const Text('Add Featured Brand'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(180, 42),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showAddSlideDialog(context, ref),
                                icon: const Icon(Icons.add_photo_alternate_outlined),
                                label: const Text('Add Image Slide'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(170, 42),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                delegate: _StickyTabBarDelegate(
                  const TabBar(
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(text: 'Featured Products', icon: Icon(Icons.star_outline)),
                      Tab(text: 'Featured Brands', icon: Icon(Icons.branding_watermark_outlined)),
                      Tab(text: 'Image Slides', icon: Icon(Icons.photo_library_outlined)),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            children: [
              _FeaturedProductsTab(featuredProductsAsync: featuredProductsAsync),
              _FeaturedBrandsTab(featuredBrandsAsync: featuredBrandsAsync),
              _ImageSlidesTab(imageSlidesAsync: imageSlidesAsync),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _StickyTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF8FAFC), // Same as Scaffold background
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
  }
}

class _FeaturedProductsTab extends ConsumerWidget {
  final AsyncValue<List<FeaturedProductEntry>> featuredProductsAsync;
  const _FeaturedProductsTab({required this.featuredProductsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return featuredProductsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text('No featured products yet. Use "Add Featured Product" to select products.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = items[index];
            final product = entry.product;
            final photoUrl = (product.photos != null && product.photos!.isNotEmpty)
                ? product.photos!.first
                : null;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: photoUrl != null
                        ? Image.network(photoUrl, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                          ),
                  ),
                ),
                title: Text(
                  product.productName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (product.brandNames.isNotEmpty) product.brandNames.join(', '),
                        if (product.category != null) 'Category: ${product.category}',
                      ].where((e) => e.isNotEmpty).join(' • '),
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sort order: ${entry.sortOrder}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                trailing: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Move up',
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      onPressed: index == 0
                          ? null
                          : () => ref
                              .read(featuredProductsProvider.notifier)
                              .updateFeaturedProduct(entry.id, sortOrder: entry.sortOrder - 10),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      onPressed: index == items.length - 1
                          ? null
                          : () => ref
                              .read(featuredProductsProvider.notifier)
                              .updateFeaturedProduct(entry.id, sortOrder: entry.sortOrder + 10),
                    ),
                    Switch(
                      value: entry.isActive,
                      onChanged: (value) => ref
                          .read(featuredProductsProvider.notifier)
                          .updateFeaturedProduct(entry.id, isActive: value),
                    ),
                    IconButton(
                      tooltip: 'Remove from featured',
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => ref
                          .read(featuredProductsProvider.notifier)
                          .removeFeaturedProduct(entry.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading featured products: $err')),
    );
  }
}

class _FeaturedBrandsTab extends ConsumerWidget {
  final AsyncValue<List<FeaturedBrandEntry>> featuredBrandsAsync;
  const _FeaturedBrandsTab({required this.featuredBrandsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return featuredBrandsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text('No featured brands yet. Use "Add Featured Brand" to select brands.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = items[index];
            final brand = entry.brand;
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: brand.logo != null && brand.logo!.isNotEmpty
                        ? Image.network(brand.logo!, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.branding_watermark_outlined, color: Colors.grey),
                          ),
                  ),
                ),
                title: Text(
                  brand.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (brand.description != null && brand.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        brand.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Sort order: ${entry.sortOrder}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                trailing: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Move up',
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      onPressed: index == 0
                          ? null
                          : () => ref
                              .read(featuredBrandsProvider.notifier)
                              .updateFeaturedBrand(entry.id, sortOrder: entry.sortOrder - 10),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      onPressed: index == items.length - 1
                          ? null
                          : () => ref
                              .read(featuredBrandsProvider.notifier)
                              .updateFeaturedBrand(entry.id, sortOrder: entry.sortOrder + 10),
                    ),
                    Switch(
                      value: entry.isActive,
                      onChanged: (value) => ref
                          .read(featuredBrandsProvider.notifier)
                          .updateFeaturedBrand(entry.id, isActive: value),
                    ),
                    IconButton(
                      tooltip: 'Remove from featured',
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => ref
                          .read(featuredBrandsProvider.notifier)
                          .removeFeaturedBrand(entry.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading featured brands: $err')),
    );
  }
}

class _ImageSlidesTab extends ConsumerWidget {
  final AsyncValue<List<ImageSlide>> imageSlidesAsync;
  const _ImageSlidesTab({required this.imageSlidesAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(brandsNotifierProvider);

    return imageSlidesAsync.when(
      data: (slides) {
        if (slides.isEmpty) {
          return const Center(
            child: Text('No image slides yet. Use "Add Image Slide" to create one.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: slides.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final slide = slides[index];

            // Resolve linked brand name
            String? brandName;
            if (slide.brandId != null) {
              brandsAsync.whenData((brands) {
                try {
                  brandName = brands.firstWhere((b) => b.id == slide.brandId).name;
                } catch (_) {}
              });
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 48,
                    child: Image.network(slide.imageUrl, fit: BoxFit.cover),
                  ),
                ),
                title: Text(
                  slide.title ?? 'Untitled slide',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (slide.description != null && slide.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        slide.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Sort order: ${slide.sortOrder}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    if (brandName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Linked Brand: $brandName',
                        style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                    if (slide.linkUrl != null && slide.linkUrl!.isNotEmpty)
                      Text(
                        slide.linkUrl!,
                        style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      ),
                  ],
                ),
                trailing: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Edit slide',
                      icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                      onPressed: () => _showAddSlideDialog(context, ref, slide),
                    ),
                    IconButton(
                      tooltip: 'Move up',
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      onPressed: index == 0
                          ? null
                          : () => ref
                              .read(imageSlidesProvider.notifier)
                              .updateSlide(slide.id, sortOrder: slide.sortOrder - 10),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      onPressed: index == slides.length - 1
                          ? null
                          : () => ref
                              .read(imageSlidesProvider.notifier)
                              .updateSlide(slide.id, sortOrder: slide.sortOrder + 10),
                    ),
                    Switch(
                      value: slide.isActive,
                      onChanged: (value) => ref
                          .read(imageSlidesProvider.notifier)
                          .updateSlide(slide.id, isActive: value),
                    ),
                    IconButton(
                      tooltip: 'Delete slide',
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => ref
                          .read(imageSlidesProvider.notifier)
                          .deleteSlide(slide.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading image slides: $err')),
    );
  }
}

Future<void> _showAddFeaturedProductDialog(BuildContext context, WidgetRef ref) async {
  await showDialog(
    context: context,
    builder: (dialogContext) {
      return _AddFeaturedProductDialog(ref: ref, dialogContext: dialogContext);
    },
  );
}

class _AddFeaturedProductDialog extends StatefulWidget {
  final WidgetRef ref;
  final BuildContext dialogContext;
  const _AddFeaturedProductDialog({required this.ref, required this.dialogContext});

  @override
  State<_AddFeaturedProductDialog> createState() => _AddFeaturedProductDialogState();
}

class _AddFeaturedProductDialogState extends State<_AddFeaturedProductDialog> {
  List<Product> _results = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      List response;
      if (_searchQuery.trim().isEmpty) {
        response = await supabase
            .from('products')
            .select('*, brands(name)')
            .order('product_name', ascending: true)
            .limit(100) as List;
      } else {
        final q = '%${_searchQuery.trim()}%';
        final results = await Future.wait([
          supabase.from('products').select('*, brands(name)').ilike('product_name', q).limit(100),
          supabase.from('products').select('*, brands(name)').ilike('product_id', q).limit(50),
          supabase.from('products').select('*, brands(name)').ilike('category', q).limit(50),
        ]);
        final seen = <String>{};
        final merged = <Map<String, dynamic>>[];
        for (final list in results) {
          for (final json in (list as List)) {
            final id = json['id'] as String;
            if (seen.add(id)) merged.add(json);
          }
        }
        response = merged;
      }
      if (mounted) {
        setState(() {
          _results = response.map((json) => Product.fromJson(json as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Featured Product'),
      content: SizedBox(
        width: 500,
        height: 500,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search products (searches all products)',
                prefixIcon: Icon(Icons.search),
                hintText: 'Type to search across all products...',
              ),
              onChanged: (value) {
                _searchQuery = value.toLowerCase();
                _loadProducts();
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text('No products found.'))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final product = _results[index];
                            final imageUrl = (product.photos != null && product.photos!.isNotEmpty)
                                ? product.photos!.first
                                : null;
                            return ListTile(
                              leading: imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(imageUrl, width: 40, height: 40, fit: BoxFit.cover),
                                    )
                                  : const Icon(Icons.image, size: 24),
                              title: Text(product.productName),
                              subtitle: Text([
                                if (product.brandNames.isNotEmpty) product.brandNames.join(', '),
                                if (product.category != null) product.category!,
                              ].where((e) => e.isNotEmpty).join(' \u2022 ')),
                              onTap: () async {
                                await widget.ref
                                    .read(featuredProductsProvider.notifier)
                                    .addFeaturedProduct(product);
                                if (context.mounted) {
                                  Navigator.of(widget.dialogContext).pop();
                                }
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(widget.dialogContext).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

Future<void> _showAddFeaturedBrandDialog(BuildContext context, WidgetRef ref) async {
  await showDialog(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, ref, _) {
          final brandsAsync = ref.watch(brandsNotifierProvider);
          return brandsAsync.when(
            loading: () => const AlertDialog(
              content: SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (err, stack) => AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to load brands: $err'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
            data: (brands) {
              String searchQuery = '';
              return StatefulBuilder(
                builder: (context, setState) {
                  final filtered = brands
                      .where((b) => b.name.toLowerCase().contains(searchQuery))
                      .toList();
                  return AlertDialog(
                    title: const Text('Add Featured Brand'),
                    content: SizedBox(
                      width: 500,
                      height: 500,
                      child: Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Search brands',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) => setState(() {
                              searchQuery = value.toLowerCase();
                            }),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: filtered.isEmpty
                                ? const Center(child: Text('No brands match your search.'))
                                : ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final brand = filtered[index];
                                      return ListTile(
                                        leading: brand.logo != null && brand.logo!.isNotEmpty
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: Image.network(brand.logo!, width: 40, height: 40, fit: BoxFit.cover),
                                              )
                                            : const Icon(Icons.branding_watermark_outlined, size: 24),
                                        title: Text(brand.name),
                                        subtitle: brand.description != null && brand.description!.isNotEmpty
                                            ? Text(
                                                brand.description!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            : null,
                                        onTap: () async {
                                          await ref
                                              .read(featuredBrandsProvider.notifier)
                                              .addFeaturedBrand(brand);
                                          if (context.mounted) {
                                            Navigator.of(dialogContext).pop();
                                          }
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

Future<void> _showAddSlideDialog(BuildContext context, WidgetRef ref, [ImageSlide? slide]) async {
  final titleController = TextEditingController(text: slide?.title);
  final descriptionController = TextEditingController(text: slide?.description);
  final imageUrlController = TextEditingController(text: slide?.imageUrl);
  final linkUrlController = TextEditingController(text: slide?.linkUrl);
  final sortOrderController = TextEditingController(text: slide?.sortOrder.toString() ?? '0');
  String? selectedBrandId = slide?.brandId;
  bool isActive = slide?.isActive ?? true;
  bool isUploading = false;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, ref, child) {
          final brandsAsync = ref.watch(brandsNotifierProvider);
          return StatefulBuilder(
            builder: (context, setState) {
              Future<void> pickAndUploadImage() async {
                try {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.gallery);

                  if (image == null) return;

                  setState(() => isUploading = true);

                  final supabase = Supabase.instance.client;
                  final bytes = await image.readAsBytes();
                  final fileExt = image.name.split('.').last;
                  final fileName =
                      'slides/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

                  await supabase.storage
                      .from('product-photos')
                      .uploadBinary(fileName, bytes);

                  final imageUrl = supabase.storage
                      .from('product-photos')
                      .getPublicUrl(fileName);

                  imageUrlController.text = imageUrl;
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error uploading image: $e')),
                    );
                  }
                } finally {
                  setState(() => isUploading = false);
                }
              }

              return AlertDialog(
                title: Text(slide == null ? 'Add Image Slide' : 'Edit Image Slide'),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(labelText: 'Title (optional)'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(labelText: 'Description (optional)'),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 8),
                        if (isUploading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (imageUrlController.text.isNotEmpty)
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                  image: DecorationImage(
                                    image: NetworkImage(imageUrlController.text),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: pickAndUploadImage,
                                    tooltip: 'Change Image',
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: 120,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!, style: BorderStyle.none),
                            ),
                            child: InkWell(
                              onTap: pickAndUploadImage,
                              borderRadius: BorderRadius.circular(8),
                              child: DottedBorder(
                                borderType: BorderType.RRect,
                                radius: const Radius.circular(8),
                                color: Colors.grey[400]!,
                                dashPattern: const [8, 4],
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined,
                                          size: 40, color: Colors.blue),
                                      SizedBox(height: 8),
                                      Text(
                                        'Upload Image from Device',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Supports JPG, PNG, WEBP',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: imageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Image URL',
                            helperText: 'Or paste a public image URL directly',
                            prefixIcon: Icon(Icons.link),
                          ),
                          onChanged: (value) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        brandsAsync.when(
                          data: (brands) {
                            return DropdownButtonFormField<String>(
                              value: selectedBrandId,
                              decoration: const InputDecoration(
                                labelText: 'Link to Brand (optional)',
                                prefixIcon: Icon(Icons.branding_watermark_outlined),
                              ),
                              hint: const Text('None'),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('None'),
                                ),
                                ...brands.map((brand) => DropdownMenuItem<String>(
                                  value: brand.id,
                                  child: Text(brand.name),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedBrandId = value;
                                });
                              },
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error loading brands: $e'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: linkUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Link URL (optional)',
                            helperText: 'Where to open when user taps the slide',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: sortOrderController,
                          decoration: const InputDecoration(labelText: 'Sort order (0 = default)'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Active'),
                            const SizedBox(width: 8),
                            Switch(
                              value: isActive,
                              onChanged: (value) => setState(() {
                                isActive = value;
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (imageUrlController.text.trim().isEmpty) {
                        return;
                      }

                      final sortOrder = int.tryParse(sortOrderController.text.trim()) ?? 0;

                      if (slide == null) {
                        await ref.read(imageSlidesProvider.notifier).addSlide(
                              title: titleController.text.trim().isEmpty
                                  ? null
                                  : titleController.text.trim(),
                              description: descriptionController.text.trim().isEmpty
                                  ? null
                                  : descriptionController.text.trim(),
                              imageUrl: imageUrlController.text.trim(),
                              linkUrl: linkUrlController.text.trim().isEmpty
                                  ? null
                                  : linkUrlController.text.trim(),
                              brandId: selectedBrandId,
                              sortOrder: sortOrder,
                              isActive: isActive,
                            );
                      } else {
                        await ref.read(imageSlidesProvider.notifier).updateSlide(
                              slide.id,
                              title: titleController.text,
                              description: descriptionController.text,
                              imageUrl: imageUrlController.text,
                              linkUrl: linkUrlController.text,
                              brandId: selectedBrandId,
                              updateBrandId: true,
                              sortOrder: sortOrder,
                              isActive: isActive,
                            );
                      }

                      if (context.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}
