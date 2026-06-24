import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../cubit/payment_cubit.dart';
import '../../domain/entities/payment_detail_entity.dart';
import 'dart:async';
import 'package:notification_module/notification_module.dart';
import 'package:server_module/server_module.dart';

class PaymentTabWidget extends StatefulWidget {
  const PaymentTabWidget({super.key});

  @override
  State<PaymentTabWidget> createState() => _PaymentTabWidgetState();
}

class _PaymentTabWidgetState extends State<PaymentTabWidget> {
  late PaymentCubit _cubit;
  static const _primaryColor = Color(0xFFFF5600);
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _cubit = PaymentCubit(GetIt.I(), GetIt.I(), GetIt.I());
    _cubit.loadPayments();
    _subscribeEvents();
  }

  void _subscribeEvents() {
    try {
      _eventSubscription = GetIt.I<AppNotificationEventBus>().stream.listen((
        event,
      ) {
        if (mounted) {
          _cubit.loadPayments();
        }
      });
    } catch (e) {
      debugPrint('Error subscribing to EventBus in PaymentTabWidget: $e');
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _cubit.close();
    super.dispose();
  }

  String _formatPrice(BuildContext context, double? price) {
    if (price == null) return context.tr(vi: '0 đ', en: '0 VND');
    final formatted = price.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return context.tr(vi: '$formatted đ', en: '$formatted VND');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(vi: 'HÓA ĐƠN & GIAO DỊCH', en: 'INVOICES & TRANSACTIONS'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: BlocBuilder<PaymentCubit, PaymentState>(
        bloc: _cubit,
        builder: (context, state) {
          if (state is PaymentLoading || state is PaymentInitial) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          if (state is PaymentError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _cubit.loadPayments(),
                    child: Text(context.tr(vi: 'Thử lại', en: 'Retry')),
                  ),
                ],
              ),
            );
          }

          if (state is PaymentLoaded) {
            final pending = state.pendingPayments;
            final completed = state.completedPayments;

            return RefreshIndicator(
              onRefresh: () => _cubit.loadPayments(),
              color: _primaryColor,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- PENDING PAYMENTS ---
                  Text(
                    context.tr(
                      vi: 'HÓA ĐƠN CHỜ THANH TOÁN',
                      en: 'PENDING PAYMENTS',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (pending.isEmpty)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.payment_outlined,
                              size: 40,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr(
                                vi: 'Không có hóa đơn chờ thanh toán',
                                en: 'No pending invoices',
                              ),
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...pending.map((payment) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildInvoiceCard(payment, isPending: true),
                      );
                    }),

                  const SizedBox(height: 28),

                  // --- COMPLETED PAYMENTS ---
                  Text(
                    context.tr(
                      vi: 'LỊCH SỬ GIAO DỊCH',
                      en: 'TRANSACTION HISTORY',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (completed.isEmpty)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              size: 40,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr(
                                vi: 'Không có lịch sử giao dịch',
                                en: 'No transaction history',
                              ),
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...completed.map((payment) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildInvoiceCard(payment, isPending: false),
                      );
                    }),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildInvoiceCard(
    PaymentDetailEntity payment, {
    required bool isPending,
  }) {
    final theme = Theme.of(context);
    final bookingId = payment.bookingId ?? '';
    final courtName =
        payment.courtName ?? context.tr(vi: 'Sân đấu', en: 'Court');
    final sportName = payment.sportName;
    final amount = _formatPrice(context, payment.amount);
    final bookingDate = DateDisplayFormatter.fromApiDate(payment.bookingDate);
    final startM = payment.startMinutes;
    final endM = payment.endMinutes;
    final timeStr = startM != null && endM != null
        ? '$bookingDate • ${(startM ~/ 60).toString().padLeft(2, '0')}:${(startM % 60).toString().padLeft(2, '0')} - ${(endM ~/ 60).toString().padLeft(2, '0')}:${(endM % 60).toString().padLeft(2, '0')}'
        : bookingDate;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPending
              ? _primaryColor.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: isPending ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${context.tr(vi: 'Mã booking: ', en: 'Booking ID: ')}#${(bookingId.length > 6 ? bookingId.substring(0, 6) : bookingId).toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _paymentStatusColor(
                      payment.status,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _paymentStatusLabel(context, payment.status),
                    style: TextStyle(
                      color: _paymentStatusColor(payment.status),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              courtName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (sportName != null && sportName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.sports_soccer_outlined,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sportName,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (timeStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                timeStr,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (isPending)
                  ElevatedButton(
                    onPressed: () async {
                      // Navigate to mock payment screen
                      final success = await context.push<bool>(
                        '/payment/mock',
                        extra: {
                          'bookingId': bookingId,
                          'invoiceId': payment.id,
                          'amount': payment.amount ?? 0.0,
                        },
                      );
                      if (success == true) {
                        _cubit.loadPayments();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      context.tr(vi: 'Thanh toán ngay', en: 'Pay Now'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _paymentStatusColor(String? status) {
    switch (status) {
      case 'SUCCESS':
      case 'REFUNDED':
        return Colors.green.shade700;
      case 'REFUND_PENDING':
      case 'PENDING':
        return Colors.orange.shade800;
      case 'FAILED':
        return Colors.red.shade700;
      case 'CANCELLED':
        return Colors.grey.shade700;
      default:
        return Colors.grey;
    }
  }

  String _paymentStatusLabel(BuildContext context, String? status) {
    switch (status) {
      case 'PENDING':
        return context.tr(vi: 'Chờ thanh toán', en: 'Pending');
      case 'SUCCESS':
        return context.tr(vi: 'Đã thanh toán', en: 'Paid');
      case 'CANCELLED':
        return context.tr(vi: 'Hóa đơn đã hủy', en: 'Invoice cancelled');
      case 'REFUND_PENDING':
        return context.tr(vi: 'Chờ hoàn tiền', en: 'Refund pending');
      case 'REFUNDED':
        return context.tr(vi: 'Đã hoàn tiền', en: 'Refunded');
      case 'FAILED':
        return context.tr(vi: 'Thanh toán thất bại', en: 'Payment failed');
      default:
        return status ?? '';
    }
  }
}
