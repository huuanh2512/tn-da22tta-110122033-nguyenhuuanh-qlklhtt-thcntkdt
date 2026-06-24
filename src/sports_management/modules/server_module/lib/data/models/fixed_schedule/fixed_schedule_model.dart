import 'package:equatable/equatable.dart';
import '../../models/user/user_model.dart';
import '../../models/sport/sport_model.dart';
import '../../models/facility/facility_model.dart';
import '../../models/court/court_model.dart';
import '../../../domain/entities/fixed_schedule_entity.dart';

class FixedScheduleModel extends Equatable {
  final String id;
  final UserModel? user;
  final String? type;
  final SportModel? sport;
  final FacilityModel? facility;
  final CourtModel? court;
  final int? pricePerHour;
  final int? startMinutes;
  final int? endMinutes;
  final String? frequency;
  final List<int>? daysOfWeek;
  final String? startDate;
  final String? endDate;
  final String? status;
  final Map<String, dynamic>? matchingConfig;
  final FixedMatchingConfigEntity? fixedMatchingConfig;
  final String? readiness;
  final List<Map<String, dynamic>>? exceptionDates;
  final Map<String, dynamic>? cancellationSummary;
  final DateTime? pausedAt;
  final DateTime? createdAt;

  const FixedScheduleModel({
    required this.id,
    this.user,
    this.type,
    this.sport,
    this.facility,
    this.court,
    this.pricePerHour,
    this.startMinutes,
    this.endMinutes,
    this.frequency,
    this.daysOfWeek,
    this.startDate,
    this.endDate,
    this.status,
    this.matchingConfig,
    this.fixedMatchingConfig,
    this.readiness,
    this.exceptionDates,
    this.cancellationSummary,
    this.pausedAt,
    this.createdAt,
  });

  factory FixedScheduleModel.fromJson(Map<String, dynamic> json) {
    final courtJson = json['court'] as Map<String, dynamic>?;
    final matchingConfig = json['matchingConfig'] is Map<String, dynamic>
        ? json['matchingConfig'] as Map<String, dynamic>
        : json['matching_config'] is Map<String, dynamic>
        ? json['matching_config'] as Map<String, dynamic>
        : null;

    return FixedScheduleModel(
      id: json['id'] ?? json['_id'] ?? '',
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      type: json['type'] as String?,
      sport: json['sport'] != null ? SportModel.fromJson(json['sport']) : null,
      facility: json['facility'] != null
          ? FacilityModel.fromJson(json['facility'])
          : null,
      court: courtJson != null ? CourtModel.fromJson(courtJson) : null,
      pricePerHour:
          (courtJson?['pricePerHour'] as num?)?.toInt() ??
          (json['pricePerHour'] as num?)?.toInt(),
      startMinutes: json['startMinutes'] as int?,
      endMinutes: json['endMinutes'] as int?,
      frequency: json['frequency'] as String?,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      status: json['status'] as String?,
      matchingConfig: matchingConfig,
      fixedMatchingConfig: matchingConfig != null
          ? FixedMatchingConfigEntity.fromJson(matchingConfig)
          : null,
      readiness:
          json['readiness']?.toString() ??
          matchingConfig?['readiness']?.toString(),
      exceptionDates: (json['exceptionDates'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .toList(),
      cancellationSummary: json['cancellationSummary'] is Map<String, dynamic>
          ? json['cancellationSummary'] as Map<String, dynamic>
          : null,
      pausedAt: json['pausedAt'] != null
          ? DateTime.tryParse(json['pausedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user?.toJson(),
      'type': type,
      'sport': sport?.toJson(),
      'facility': facility?.toJson(),
      'court': court?.toJson(),
      'pricePerHour': pricePerHour,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'frequency': frequency,
      'daysOfWeek': daysOfWeek,
      'startDate': startDate,
      'endDate': endDate,
      'status': status,
      'matchingConfig': matchingConfig,
      'readiness': readiness,
      'exceptionDates': exceptionDates,
      'cancellationSummary': cancellationSummary,
      'pausedAt': pausedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    user,
    type,
    sport,
    facility,
    court,
    pricePerHour,
    startMinutes,
    endMinutes,
    frequency,
    daysOfWeek,
    startDate,
    endDate,
    status,
    matchingConfig,
    fixedMatchingConfig,
    readiness,
    exceptionDates,
    cancellationSummary,
    pausedAt,
    createdAt,
  ];
}
