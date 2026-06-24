import 'package:flutter/material.dart';
import 'package:notification_module/notification_module.dart';
import '../widgets/customer_booking_catalog_section.dart';

class BookingCatalogFullPage extends StatelessWidget {
  final String role;
  final String? facilityId;
  final String? sportId;
  final String? sportName;
  final String? facilityName;

  const BookingCatalogFullPage({
    super.key,
    required this.role,
    this.facilityId,
    this.sportId,
    this.sportName,
    this.facilityName,
  });

  @override
  Widget build(BuildContext context) {
    final titleText = sportName != null && sportName!.isNotEmpty
        ? sportName!
        : facilityName != null && facilityName!.isNotEmpty
        ? facilityName!
        : context.tr(vi: 'Danh sách khu liên hợp', en: 'Facility list');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titleText.toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: CustomerBookingCatalogSection(
            role: role,
            isShortVersion: false,
            facilityId: facilityId,
            sportId: sportId,
            pageSize: 20,
          ),
        ),
      ),
    );
  }
}

class StaffSportFacilitiesPage extends StatelessWidget {
  final String sportId;
  final String facilityId;
  final String? sportName;

  const StaffSportFacilitiesPage({
    super.key,
    required this.sportId,
    required this.facilityId,
    this.sportName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          sportName?.toUpperCase() ??
              context.tr(vi: 'DANH SÁCH KHU LIÊN HỢP', en: 'FACILITY LIST'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CustomerBookingCatalogSection(
            role: 'staff',
            isShortVersion: false,
            facilityId: facilityId,
            sportId: sportId,
            pageSize: 100,
          ),
        ),
      ),
    );
  }
}
