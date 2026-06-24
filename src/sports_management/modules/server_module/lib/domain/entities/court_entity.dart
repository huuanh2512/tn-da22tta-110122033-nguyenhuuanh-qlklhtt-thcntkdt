import 'package:equatable/equatable.dart';

class CourtEntity extends Equatable {
  final String id;
  final String? facilityId;
  final String? sportId;
  final String? name;
  final String? status;

  const CourtEntity({
    required this.id,
    this.facilityId,
    this.sportId,
    this.name,
    this.status,
  });

  @override
  List<Object?> get props => [id, facilityId, sportId, name, status];
}