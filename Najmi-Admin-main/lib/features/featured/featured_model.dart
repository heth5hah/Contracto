class FeaturedItem {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? type;

  FeaturedItem({required this.id, required this.title, this.subtitle, required this.imageUrl, this.type});

  factory FeaturedItem.fromJson(Map<String, dynamic> json) {
    return FeaturedItem(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      imageUrl: json['image_url'],
      type: json['type'],
    );
  }
}
