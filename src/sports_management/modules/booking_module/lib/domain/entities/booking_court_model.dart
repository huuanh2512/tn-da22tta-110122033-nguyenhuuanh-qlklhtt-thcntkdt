import 'package:server_module/server_module.dart';

class BookingCourtModel extends CourtEntity {
  final int? pricePerHour;
  final String? code;

  const BookingCourtModel({
    required super.id,
    super.facilityId,
    super.sportId,
    super.name,
    super.status,
    this.pricePerHour,
    this.code,
  });
}
