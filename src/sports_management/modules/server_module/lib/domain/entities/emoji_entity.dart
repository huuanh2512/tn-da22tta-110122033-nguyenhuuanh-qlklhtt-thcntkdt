import 'package:equatable/equatable.dart';

class EmojiEntity extends Equatable {
  final String id;
  final String? code;
  final String? unicode;
  final String? name;
  final String? status;

  const EmojiEntity({
    required this.id,
    this.code,
    this.unicode,
    this.name,
    this.status,
  });

  @override
  List<Object?> get props => [id, code, unicode, name, status];
}