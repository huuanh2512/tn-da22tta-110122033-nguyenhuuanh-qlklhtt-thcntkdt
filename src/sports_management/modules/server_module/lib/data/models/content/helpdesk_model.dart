import 'package:equatable/equatable.dart';

class HelpdeskModel extends Equatable {
  final String id;
  final String? title;
  final String? content;
  final String? status;

  const HelpdeskModel({
    required this.id,
    this.title,
    this.content,
    this.status,
  });

  factory HelpdeskModel.fromJson(Map<String, dynamic> json) {
    return HelpdeskModel(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] as String?,
      content: json['content'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'status': status,
    };
  }

  @override
  List<Object?> get props => [id, title, content, status];
}