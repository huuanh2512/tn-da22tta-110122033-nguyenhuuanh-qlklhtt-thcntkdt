import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:server_module/server_module.dart';
import '../pages/court_booking_page.dart';
import '../pages/booking_detail_page.dart';
import '../pages/booking_catalog_full_page.dart';

class BookingRoutes {
  BookingRoutes._();

  static List<GoRoute> get routes => [
    GoRoute(
      path: '/court/:courtId/booking',
      builder: (context, state) {
        final courtId = state.pathParameters['courtId']!;
        // extra được truyền từ home_module là CourtEntity (BookingCourtModel)
        final court = state.extra as CourtEntity?;
        final startMinutesStr = state.uri.queryParameters['startMinutes'];
        final initialStartMinutes = startMinutesStr != null
            ? int.tryParse(startMinutesStr)
            : null;
        return CourtBookingPage(
          courtId: courtId,
          court: court,
          initialStartMinutes: initialStartMinutes,
        );
      },
    ),
    GoRoute(
      path: '/booking/:bookingId',
      builder: (context, state) {
        final bookingId = state.pathParameters['bookingId']!;
        return BookingDetailPage(bookingId: bookingId);
      },
    ),
    GoRoute(
      path: '/booking-catalog-full',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'customer';
        final facilityId = state.uri.queryParameters['facilityId'];
        final sportId = state.uri.queryParameters['sportId'];
        final sportName = state.uri.queryParameters['sportName'];
        final facilityName = state.uri.queryParameters['facilityName'];
        return BookingCatalogFullPage(
          role: role,
          facilityId: facilityId,
          sportId: sportId,
          sportName: sportName,
          facilityName: facilityName,
        );
      },
    ),
    GoRoute(
      path: '/staff/sport-facilities',
      builder: (context, state) {
        final sportId = state.uri.queryParameters['sportId'];
        final facilityId = state.uri.queryParameters['facilityId'];
        final sportName = state.uri.queryParameters['sportName'];
        if (sportId == null ||
            sportId.isEmpty ||
            facilityId == null ||
            facilityId.isEmpty) {
          return const _MissingStaffFacilityPage();
        }
        return StaffSportFacilitiesPage(
          sportId: sportId,
          facilityId: facilityId,
          sportName: sportName,
        );
      },
    ),
  ];
}

class _MissingStaffFacilityPage extends StatelessWidget {
  const _MissingStaffFacilityPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DANH SÁCH SÂN')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Không xác định được cơ sở staff đang quản lý.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
