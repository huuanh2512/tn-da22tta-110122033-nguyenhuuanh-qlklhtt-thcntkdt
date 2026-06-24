import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/booking_detail_entity.dart';
import '../cubit/booking_history_cubit.dart';
import '../utils/booking_ui_helper.dart';
import 'package:review_module/review_module.dart';
import 'dart:async';
import 'package:notification_module/notification_module.dart';
import 'package:server_module/server_module.dart';
import '../widgets/fixed_schedule_list_widget.dart';

class BookingHistoryPage extends StatelessWidget {
  const BookingHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.tr(vi: 'LỊCH SỬ ĐẶT SÂN', en: 'BOOKING HISTORY'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          bottom: TabBar(
            labelColor: const Color(0xFFFF5600),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFFF5600),
            tabs: [
              Tab(
                text: context.tr(vi: 'Tất cả', en: 'All'),
              ),
              Tab(
                text: context.tr(vi: 'Lịch cố định', en: 'Fixed Schedules'),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [BookingHistoryList(), FixedScheduleListWidget()],
        ),
      ),
    );
  }
}

class BookingHistoryList extends StatefulWidget {
  const BookingHistoryList({super.key});

  @override
  State<BookingHistoryList> createState() => _BookingHistoryListState();
}

class _BookingHistoryListState extends State<BookingHistoryList> {
  late BookingHistoryCubit _cubit;
  StreamSubscription? _eventSubscription;
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _cubit = BookingHistoryCubit(GetIt.I());
    _loadHistory();
    _subscribeEvents();
  }

  Future<void> _loadHistory() {
    return _cubit.loadBookingHistory(
      status: _selectedStatus == 'ALL' ? null : _selectedStatus,
    );
  }

  void _changeStatus(String? status) {
    if (status == null) return;
    if (_selectedStatus == status) return;
    setState(() => _selectedStatus = status);
    _loadHistory();
  }

  String _statusFilterLabel(BuildContext context, String? status) {
    switch (status) {
      case 'PENDING':
        return context.tr(vi: 'Chờ duyệt', en: 'Pending');
      case 'CONFIRMED':
        return context.tr(vi: 'Đã xác nhận', en: 'Confirmed');
      case 'COMPLETED':
        return context.tr(vi: 'Đã hoàn thành', en: 'Completed');
      case 'CANCELLED':
        return context.tr(vi: 'Đã hủy', en: 'Cancelled');
      default:
        return context.tr(vi: 'Tất cả trạng thái', en: 'All statuses');
    }
  }

  void _subscribeEvents() {
    try {
      _eventSubscription = GetIt.I<AppNotificationEventBus>().stream.listen((
        event,
      ) {
        if (mounted) {
          _loadHistory();
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to EventBus in BookingHistoryList: $e');
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _cubit.close();
    super.dispose();
  }

  Widget _buildStatusFilter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedStatus,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.tr(vi: 'Trạng thái', en: 'Status'),
          prefixIcon: const Icon(Icons.filter_list_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        items: <String>['ALL', 'PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED']
            .map((status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Text(
                  _statusFilterLabel(context, status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            })
            .toList(),
        onChanged: _changeStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatusFilter(context),
        Expanded(
          child: BlocBuilder<BookingHistoryCubit, BookingHistoryState>(
            bloc: _cubit,
            builder: (context, state) {
              if (state is BookingHistoryLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5600)),
                );
              }

              if (state is BookingHistoryError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(state.message),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadHistory,
                        child: Text(context.tr(vi: 'Thử lại', en: 'Retry')),
                      ),
                    ],
                  ),
                );
              }

              if (state is BookingHistoryLoaded) {
                final visibleBookings = state.bookings;

                if (visibleBookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr(
                            vi: 'Không có lịch sử nào',
                            en: 'No history found',
                          ),
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: const Color(0xFFFF5600),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleBookings.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return BookingHistoryCard(
                        booking: visibleBookings[index],
                      );
                    },
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}

class BookingHistoryCard extends StatelessWidget {
  final BookingDetailEntity booking;

  const BookingHistoryCard({super.key, required this.booking});

  String? get _displayStatus =>
      BookingUiHelper.isFixedSchedulePendingPayment(booking)
      ? 'CONFIRMED'
      : booking.status;

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'PENDING':
        return const Color(0xFFFF5600);
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

  String _getStatusText(BuildContext context, String? status) {
    switch (status) {
      case 'PENDING':
        return context.tr(vi: 'Chờ duyệt', en: 'Pending');
      case 'CONFIRMED':
        return context.tr(vi: 'Đã xác nhận', en: 'Confirmed');
      case 'COMPLETED':
        return context.tr(vi: 'Hoàn thành', en: 'Completed');
      case 'CANCELLED':
        return context.tr(vi: 'Đã hủy', en: 'Cancelled');
      default:
        return status ?? context.tr(vi: 'Không xác định', en: 'Unknown');
    }
  }

  String _formatPrice(BuildContext context, double? price) {
    if (price == null) return context.tr(vi: '0 đ', en: '0 VND');
    final formatted = price.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return context.tr(vi: '$formatted đ', en: '$formatted VND');
  }

  String _paymentPolicyText(BuildContext context) {
    switch (booking.paymentPolicy) {
      case 'TEAM_REPRESENTATIVES_SPLIT':
        return context.tr(
          vi: 'Đại diện hai đội chia đôi',
          en: 'Team representatives split',
        );
      case 'SPLIT_EQUALLY':
        return context.tr(vi: 'Chia đều', en: 'Split equally');
      case 'HOST_PAY_ALL':
        return context.tr(vi: 'Chủ phòng trả', en: 'Host pays');
      default:
        return context.tr(vi: 'Ghép trận', en: 'Matching');
    }
  }

  String _formatTimeRange(BuildContext context) {
    final startMinutes = booking.startMinutes;
    final endMinutes = booking.endMinutes;
    if (startMinutes == null || endMinutes == null) {
      return context.tr(vi: 'Chưa có thời gian', en: 'Time unavailable');
    }

    String formatMinutes(int value) {
      final hour = (value ~/ 60).toString().padLeft(2, '0');
      final minute = (value % 60).toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return '${formatMinutes(startMinutes)} - ${formatMinutes(endMinutes)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(_displayStatus);
    final isFixedPending = BookingUiHelper.isFixedSchedulePendingPayment(
      booking,
    );
    final shouldShowFixedSchedule =
        isFixedPending && (!booking.isMatching || booking.isHost);
    final detailRoute = booking.isMatching && booking.matchingSessionId != null
        ? '/matching/detail/${booking.matchingSessionId}'
        : '/booking/${booking.id}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: () => context.push(detailRoute),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      booking.courtName ??
                          context.tr(vi: 'Sân đấu', en: 'Court'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(context, _displayStatus),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (booking.sportName != null &&
                  booking.sportName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  booking.sportName!,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (booking.isMatching) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoPill(
                      icon: Icons.groups_rounded,
                      text: context.tr(vi: 'Ghép trận', en: 'Matching'),
                      color: const Color(0xFFFF5600),
                    ),
                    _InfoPill(
                      icon: booking.isHost
                          ? Icons.workspace_premium_rounded
                          : Icons.person_rounded,
                      text: booking.isHost
                          ? context.tr(vi: 'Chủ phòng', en: 'Host')
                          : context.tr(vi: 'Thành viên', en: 'Member'),
                      color: Colors.blueGrey,
                    ),
                    _InfoPill(
                      icon: Icons.receipt_long_rounded,
                      text: _paymentPolicyText(context),
                      color: Colors.green,
                    ),
                  ],
                ),
                if (booking.myPaymentStatus != null ||
                    booking.myPaymentAmount != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      vi:
                          'Hóa đơn của bạn: ${booking.myPaymentStatus ?? '-'}'
                          '${booking.myPaymentAmount != null ? ' - ${_formatPrice(context, booking.myPaymentAmount)}' : ''}',
                      en:
                          'Your payment: ${booking.myPaymentStatus ?? '-'}'
                          '${booking.myPaymentAmount != null ? ' - ${_formatPrice(context, booking.myPaymentAmount)}' : ''}',
                    ),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
              if (shouldShowFixedSchedule) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.tr(vi: 'Lịch cố định', en: 'Fixed Schedule'),
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateDisplayFormatter.fromApiDate(booking.bookingDate),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTimeRange(context),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    booking.isMatching && booking.myPaymentAmount != null
                        ? _formatPrice(context, booking.myPaymentAmount)
                        : _formatPrice(context, booking.totalPrice),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Row(
                    children: [
                      if (booking.status == 'COMPLETED') ...[
                        GestureDetector(
                          onTap: () {
                            if (booking.courtId != null) {
                              ReviewBottomSheet.show(
                                context,
                                courtId: booking.courtId!,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF5600,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(
                                  0xFFFF5600,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              context.tr(vi: 'Đánh giá', en: 'Rate'),
                              style: const TextStyle(
                                color: Color(0xFFFF5600),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        booking.isMatching
                            ? context.tr(vi: 'Xem phòng ghép', en: 'View Match')
                            : context.tr(
                                vi: 'Xem chi tiết',
                                en: 'View Details',
                              ),
                        style: const TextStyle(
                          color: Color(0xFFFF5600),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
