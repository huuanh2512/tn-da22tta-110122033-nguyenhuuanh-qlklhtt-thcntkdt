import 'package:equatable/equatable.dart';

class FacilityModel extends Equatable {
  final String id;
  final String? name;
  final String? address;
  final String? description;
  final String? ownerId;
  final String? status;

  const FacilityModel({
    required this.id,
    this.name,
    this.address,
    this.description,
    this.ownerId,
    this.status,
  });

  factory FacilityModel.fromJson(Map<String, dynamic> json) {
    return FacilityModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] as String?,
      address: json['address'] as String?,
      description: json['description'] as String?,
      ownerId: json['ownerId'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'description': description,
      'ownerId': ownerId,
      'status': status,
    };
  }

  @override
  List<Object?> get props => [id, name, address, description, ownerId, status];
}