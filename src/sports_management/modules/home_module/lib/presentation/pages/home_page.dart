import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:authentication_module/authentication_module.dart';
import '../widgets/complete_profile_section.dart';
import 'admin_dashboard_section.dart';
import 'staff_dashboard_section.dart';
import 'customer_dashboard_section.dart';
import 'package:notification_module/notification_module.dart';

class HomePage extends StatefulWidget {
  final String? initialTab;

  const HomePage({super.key, this.initialTab});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<UserResult?> _userFuture;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() {
    setState(() {
      _userFuture = GetIt.I<GetLocalUserUseCase>()().then(
        (value) => value.fold((_) => null, (user) => user),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserResult?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          final role = user.role?.toLowerCase() ?? 'customer';

          switch (role) {
            case 'admin':
              return const AdminDashboardSection();
            case 'staff':
              return const StaffDashboardSection();
            case 'customer':
            default:
              // Check if user profile is empty (name is null or empty) for customer only
              final name = user.name;
              if (name == null || name.trim().isEmpty) {
                return CompleteProfileSection(
                  userId: user.userId ?? '',
                  onProfileUpdated: _loadUser,
                );
              }
              return CustomerDashboardSection(initialTab: widget.initialTab);
          }
        }

        // Fallback if no user is found (e.g. unauthorized entry)
        return Scaffold(
          body: Center(
            child: Text(
              context.tr(
                vi: 'Chưa đăng nhập. Vui lòng đăng nhập lại.',
                en: 'Not logged in. Please log in again.',
              ),
            ),
          ),
        );
      },
    );
  }
}
