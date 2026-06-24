import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  final String id;
  final String? userId;
  final String? title;
  final String? content;
  final String? type;
  final Map<String, dynamic>? metadata;
  final bool? isRead;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    this.userId,
    this.title,
    this.content,
    this.type,
    this.metadata,
    this.isRead,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? json['_id'] ?? '',
      userId: json['userId'] as String?,
      title: json['title'] as String?,
      content: json['content'] as String?,
      type: json['type']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : (json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : null),
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'content': content,
      'type': type,
      'metadata': metadata,
      'isRead': isRead,
    };
  }

  @override
  List<Object?> get props => [id, userId, title, content, type, metadata, isRead, createdAt];
}
