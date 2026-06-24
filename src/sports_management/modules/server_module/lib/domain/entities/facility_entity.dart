import 'package:equatable/equatable.dart';

class FacilityEntity extends Equatable {
  final String id;
  final String? name;
  final String? address;
  final String? description;
  final String? ownerId;
  final String? status;

  const FacilityEntity({
    required this.id,
    this.name,
    this.address,
    this.description,
    this.ownerId,
    this.status,
  });

  @override
  List<Object?> get props => [id, name, address, description, ownerId, status];
}