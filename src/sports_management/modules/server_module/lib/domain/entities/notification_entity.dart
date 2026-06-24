import 'package:equatable/equatable.dart';

class NotificationEntity extends Equatable {
  final String id;
  final String? userId;
  final String? title;
  final String? content;
  final String? type;
  final Map<String, dynamic>? metadata;
  final bool? isRead;
  final DateTime? createdAt;

  const NotificationEntity({
    required this.id,
    this.userId,
    this.title,
    this.content,
    this.type,
    this.metadata,
    this.isRead,
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, userId, title, content, type, metadata, isRead, createdAt];
}
