import 'package:equatable/equatable.dart';

class HelpdeskEntity extends Equatable {
  final String id;
  final String? title;
  final String? content;
  final String? status;

  const HelpdeskEntity({
    required this.id,
    this.title,
    this.content,
    this.status,
  });

  @override
  List<Object?> get props => [id, title, content, status];
}