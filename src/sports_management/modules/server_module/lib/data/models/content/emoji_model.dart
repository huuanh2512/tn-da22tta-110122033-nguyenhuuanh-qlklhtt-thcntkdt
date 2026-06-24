import 'package:equatable/equatable.dart';

class EmojiModel extends Equatable {
  final String id;
  final String? code;
  final String? unicode;
  final String? name;
  final String? status;

  const EmojiModel({
    required this.id,
    this.code,
    this.unicode,
    this.name,
    this.status,
  });

  factory EmojiModel.fromJson(Map<String, dynamic> json) {
    return EmojiModel(
      id: json['id'] ?? json['_id'] ?? '',
      code: json['code'] as String?,
      unicode: json['unicode'] as String?,
      name: json['name'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'unicode': unicode,
      'name': name,
      'status': status,
    };
  }

  @override
  List<Object?> get props => [id, code, unicode, name, status];
}