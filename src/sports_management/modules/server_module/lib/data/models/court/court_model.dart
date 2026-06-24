import 'package:equatable/equatable.dart';

class CourtModel extends Equatable {
  final String id;
  final String? facilityId;
  final String? sportId;
  final String? name;
  final String? status;

  const CourtModel({
    required this.id,
    this.facilityId,
    this.sportId,
    this.name,
    this.status,
  });

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    return CourtModel(
      id: json['id'] ?? json['_id'] ?? '',
      facilityId: json['facilityId'] as String?,
      sportId: json['sportId'] as String?,
      name: json['name'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'facilityId': facilityId,
      'sportId': sportId,
      'name': name,
      'status': status,
    };
  }

  @override
  List<Object?> get props => [id, facilityId, sportId, name, status];
}