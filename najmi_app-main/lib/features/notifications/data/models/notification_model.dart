class NotificationModel {
  final String id;
  final String source; // 'admin', 'app', 'system'
  final String target; // 'admin', 'user'
  final String? userId;
  final String title;
  final String message;
  final String type; // 'order', 'quotation', 'return', 'refund', 'payment', 'system', 'other'
  final String? referenceId; // order_id, quotation_id, return_id, etc.
  final bool isRead;
  final bool soundPlayed;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  NotificationModel({
    required this.id,
    required this.source,
    required this.target,
    this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.referenceId,
    this.isRead = false,
    this.soundPlayed = false,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      source: json['source'] as String? ?? 'system',
      target: json['target'] as String? ?? 'user',
      userId: json['user_id'] as String?,
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'other',
      referenceId: json['reference_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      soundPlayed: json['sound_played'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'target': target,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'reference_id': referenceId,
      'is_read': isRead,
      'sound_played': soundPlayed,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }
}
