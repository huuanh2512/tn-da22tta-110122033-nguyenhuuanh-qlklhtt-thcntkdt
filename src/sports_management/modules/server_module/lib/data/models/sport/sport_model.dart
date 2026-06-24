import 'package:equatable/equatable.dart';

class SportModel extends Equatable {
  final String id;
  final String? name;
  final String? iconUrl;

  const SportModel({
    required this.id,
    this.name,
    this.iconUrl,
  });

  factory SportModel.fromJson(Map<String, dynamic> json) {
    return SportModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] as String?,
      iconUrl: json['iconUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconUrl': iconUrl,
    };
  }

  @override
  List<Object?> get props => [id, name, iconUrl];
}