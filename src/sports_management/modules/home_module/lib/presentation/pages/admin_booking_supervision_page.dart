import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:booking_module/booking_module.dart';
import 'package:notification_module/notification_module.dart';
import 'package:server_module/server_module.dart';

class AdminBookingSupervisionPage extends StatefulWidget {
  const AdminBookingSupervisionPage({super.key});

  @override
  State<AdminBookingSupervisionPage> createState() =>
      _AdminBookingSupervisionPageState();
}

class _AdminBookingSupervisionPageState
    extends State<AdminBookingSupervisionPage> {
  String? _selectedStatus; // null for ALL
  List<BookingDetailEntity> _bookings = [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _statusFilters = [
    {'label': 'Tất cả', 'value': null},
    {'label': 'Chờ duyệt', 'value': 'PENDING'},
    {'label': 'Đã xác nhận', 'value': 'CONFIRMED'},
    {'label': 'Đã hoàn thành', 'value': 'COMPLETED'},
    {'label': 'Đã hủy', 'value': 'CANCELLED'},
  ];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final useCase = GetIt.I<GetBookingHistoryUseCase>();
      final response = await useCase(status: _selectedStatus);
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _bookings = response.data!;
        });
      } else {
        setState(() {
          _bookings = [];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.message ?? 'Không thể tải danh sách đặt lịch',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Hủy đặt lịch'),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn hủy lịch đặt sân này? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy bỏ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final useCase = GetIt.I<UpdateBookingStatusUseCase>();
        final response = await useCase(bookingId, 'CANCELLED');
        if (response.success) {
          try {
            GetIt.I<AppNotificationEventBus>().emit(
              const AppNotificationEvent(
                type: AppNotificationEventType.bookingCancelled,
              ),
            );
          } catch (e) {
            debugPrint('Error emitting admin cancel booking event: $e');
          }

          if (response.data != null && response.data!.userId != null) {
            try {
              final createNotification = GetIt.I<CreateNotificationUseCase>();
              await createNotification(
                userId: response.data!.userId!,
                title: 'Lịch đặt sân bị hủy',
                body: 'Lịch đặt sân của bạn đã bị hủy bởi Quản trị viên.',
                type: 'BOOKING',
              );
              GetIt.I<NotificationCubit>().loadNotifications();
            } catch (_) {}
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Hủy đặt lịch thành công'),
                backgroundColor: Colors.green,
              ),
            );
          }
          _loadBookings();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.message ?? 'Không thể hủy đặt lịch'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  String _formatTime(int? minutes) {
    if (minutes == null) return '--:--';
    final hrs = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  String _formatPrice(double? price) {
    if (price == null) return '0 đ';
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return 'Chờ duyệt';
      case 'CONFIRMED':
        return 'Đã xác nhận';
      case 'COMPLETED':
        return 'Hoàn thành';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return status ?? 'Không rõ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Giám sát Đặt lịch',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Row
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusFilters.length,
              itemBuilder: (context, index) {
                final filter = _statusFilters[index];
                final isSelected = _selectedStatus == filter['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(
                      filter['label'],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedStatus = filter['value'];
                        });
                        _loadBookings();
                      }
                    },
                    selectedColor: const Color(0xFFFF5600),
                    checkmarkColor: Colors.white,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFFF5600)
                            : theme.dividerColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Booking List
          Expanded(
            child: _isLoading && _bookings.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF5600)),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBookings,
                    color: const Color(0xFFFF5600),
                    child: _bookings.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.25,
                              ),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.calendar_month_outlined,
                                      size: 72,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Không tìm thấy lịch đặt nào',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Kéo xuống để tải lại',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _bookings.length,
                            itemBuilder: (context, index) {
                              final booking = _bookings[index];
                              final canCancel =
                                  booking.status == 'PENDING' ||
                                  booking.status == 'CONFIRMED';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: theme.dividerColor),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Top Header: Booking ID & Status
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Mã: #${booking.id.substring(booking.id.length - 6).toUpperCase()}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                booking.status,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: _getStatusColor(
                                                  booking.status,
                                                ).withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              _getStatusLabel(booking.status),
                                              style: TextStyle(
                                                color: _getStatusColor(
                                                  booking.status,
                                                ),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),

                                      // Court info & user info
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.stadium_outlined,
                                            size: 20,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              booking.courtName ??
                                                  'Sân thi đấu (${booking.courtId})',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (booking.sportName != null &&
                                          booking.sportName!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.sports_soccer_rounded,
                                              size: 18,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                booking.sportName!,
                                                style: TextStyle(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person_outline,
                                            size: 20,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              booking.user?.name ??
                                                  'Khách hàng',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (booking.user?.email != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const SizedBox(width: 28),
                                            Text(
                                              booking.user!.email!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 12),

                                      // Booking Time & Price Details
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Thời gian',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_formatTime(booking.startMinutes)} - ${_formatTime(booking.endMinutes)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  DateDisplayFormatter.fromApiDate(
                                                    booking.bookingDate,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Tổng thanh toán',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatPrice(
                                                    booking.totalPrice,
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Cancel booking action button
                                      if (canCancel) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 38,
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _cancelBooking(booking.id),
                                            icon: const Icon(
                                              Icons.cancel_outlined,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Hủy lịch đặt sân',
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: BorderSide(
                                                color: Colors.red.withValues(
                                                  alpha: 0.4,
                                                ),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
