import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:payment_module/payment_module.dart';
import 'package:notification_module/notification_module.dart';
import 'package:server_module/server_module.dart';

class AdminPaymentSupervisionPage extends StatefulWidget {
  const AdminPaymentSupervisionPage({super.key});

  @override
  State<AdminPaymentSupervisionPage> createState() =>
      _AdminPaymentSupervisionPageState();
}

class _AdminPaymentSupervisionPageState
    extends State<AdminPaymentSupervisionPage> {
  String? _selectedStatus; // null for ALL
  List<PaymentDetailEntity> _payments = [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _statusFilters = [
    {'label': 'Tất cả', 'value': null},
    {'label': 'Chờ duyệt', 'value': 'PENDING'},
    {'label': 'Thành công', 'value': 'SUCCESS'},
    {'label': 'Chờ hoàn tiền', 'value': 'REFUND_PENDING'},
    {'label': 'Đã hoàn tiền', 'value': 'REFUNDED'},
    {'label': 'Đã hủy', 'value': 'CANCELLED'},
    {'label': 'Thất bại', 'value': 'FAILED'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final useCase = GetIt.I<GetPaymentsUseCase>();
      final response = await useCase(status: _selectedStatus);
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _payments = response.data!;
        });
      } else {
        setState(() {
          _payments = [];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.message ?? 'Không thể tải danh sách giao dịch',
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

  Future<void> _updatePaymentStatus(String paymentId, String status) async {
    setState(() => _isLoading = true);
    try {
      String? userId;
      try {
        final currentPayment = _payments.firstWhere((p) => p.id == paymentId);
        userId = currentPayment.booking?.userId;
      } catch (_) {}

      final useCase = GetIt.I<UpdatePaymentStatusUseCase>();
      final response = await useCase(paymentId, status);
      if (response.success) {
        try {
          if (status == 'SUCCESS') {
            final currentPayment = _payments.firstWhere(
              (p) => p.id == paymentId,
            );
            final isOnline =
                currentPayment.method == 'BANK_TRANSFER' ||
                currentPayment.method == 'online';
            GetIt.I<AppNotificationEventBus>().emit(
              AppNotificationEvent(
                type: isOnline
                    ? AppNotificationEventType.paymentOnlineSuccess
                    : AppNotificationEventType.paymentOfflineConfirmed,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error emitting admin payment approval event: $e');
        }

        if (userId != null) {
          try {
            await GetIt.I<CreateNotificationUseCase>().call(
              userId: userId,
              title: 'Cập nhật trạng thái thanh toán',
              body: status == 'REFUNDED'
                  ? 'Giao dịch trị giá ${response.data!.amount ?? 0.0}đ đã được xác nhận hoàn tiền.'
                  : 'Giao dịch thanh toán trị giá ${response.data!.amount ?? 0.0}đ đã được ${status == 'SUCCESS' ? 'phê duyệt' : 'từ chối'}.',
              type: 'PAYMENT',
            );
            GetIt.I<NotificationCubit>().loadNotifications();
          } catch (_) {}
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == 'REFUNDED'
                    ? 'Đã xác nhận hoàn tiền'
                    : status == 'SUCCESS'
                    ? 'Duyệt giao dịch thành công'
                    : 'Đã từ chối giao dịch',
              ),
              backgroundColor: status == 'SUCCESS' || status == 'REFUNDED'
                  ? Colors.green
                  : Colors.orange,
            ),
          );
        }
        _loadPayments();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Cập nhật thất bại'),
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

  void _showApprovalSheet(PaymentDetailEntity payment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Duyệt Giao Dịch',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Mã GD: ${payment.transactionId ?? 'Chưa cập nhật'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const Divider(height: 24),
                Text(
                  'Vui lòng kiểm tra kỹ số tiền ${payment.amount != null ? _formatPrice(payment.amount!) : "0 đ"} trong tài khoản ngân hàng trước khi xác nhận.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _updatePaymentStatus(payment.id, 'FAILED');
                        },
                        child: const Text(
                          'Từ chối (FAILED)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _updatePaymentStatus(payment.id, 'SUCCESS');
                        },
                        child: const Text(
                          'Xác nhận (SUCCESS)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatPrice(double price) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  String _formatTime(int? minutes) {
    if (minutes == null) return '--:--';
    final hrs = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'SUCCESS':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      case 'CANCELLED':
        return Colors.grey.shade700;
      case 'REFUND_PENDING':
        return Colors.orange.shade800;
      case 'REFUNDED':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return 'Chờ duyệt';
      case 'SUCCESS':
        return 'Thành công';
      case 'FAILED':
        return 'Thất bại';
      case 'CANCELLED':
        return 'Đã hủy';
      case 'REFUND_PENDING':
        return 'Chờ hoàn tiền';
      case 'REFUNDED':
        return 'Đã hoàn tiền';
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
          'Thu chi & Giao dịch',
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
                        _loadPayments();
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

          // Payment List
          Expanded(
            child: _isLoading && _payments.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF5600)),
                  )
                : RefreshIndicator(
                    onRefresh: _loadPayments,
                    color: const Color(0xFFFF5600),
                    child: _payments.isEmpty
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
                                      Icons.receipt_long_outlined,
                                      size: 72,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Không tìm thấy giao dịch nào',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Kéo xuống để tải lại',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
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
                            itemCount: _payments.length,
                            itemBuilder: (context, index) {
                              final payment = _payments[index];
                              final isPending = payment.status == 'PENDING';
                              final isRefundPending =
                                  payment.status == 'REFUND_PENDING';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header: Transaction ID & Status
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            payment.transactionId != null
                                                ? 'Mã GD: ${payment.transactionId}'
                                                : 'Mã GD: Chưa cập nhật',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                payment.status,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: _getStatusColor(
                                                  payment.status,
                                                ).withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              _getStatusLabel(payment.status),
                                              style: TextStyle(
                                                color: _getStatusColor(
                                                  payment.status,
                                                ),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),

                                      // Amount & Method
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Số tiền giao dịch',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                payment.amount != null
                                                    ? _formatPrice(
                                                        payment.amount!,
                                                      )
                                                    : '0 đ',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              const Text(
                                                'Phương thức',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                payment.method ??
                                                    'Chuyển khoản',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Court booking details if available
                                      if (payment.courtName != null) ...[
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                payment.courtName!,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (payment.sportName != null &&
                                                  payment
                                                      .sportName!
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .sports_soccer_rounded,
                                                      size: 14,
                                                      color: Color(0xFFFF5600),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        payment.sportName!,
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFFFF5600,
                                                          ),
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              Text(
                                                'Thời gian: ${_formatTime(payment.startMinutes)} - ${_formatTime(payment.endMinutes)} | ${DateDisplayFormatter.fromApiDate(payment.bookingDate)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],

                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Booking ID: #${payment.bookingId?.substring(payment.bookingId!.length - 6).toUpperCase() ?? ""}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          if (payment.createdAt != null)
                                            Text(
                                              DateDisplayFormatter.dateTime(
                                                payment.createdAt!,
                                              ),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                        ],
                                      ),

                                      // Approve button
                                      if (isPending) ...[
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 40,
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _showApprovalSheet(payment),
                                            icon: const Icon(
                                              Icons.rate_review_outlined,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Duyệt giao dịch này',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFFF5600,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              elevation: 0,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (isRefundPending) ...[
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 40,
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _updatePaymentStatus(
                                                  payment.id,
                                                  'REFUNDED',
                                                ),
                                            icon: const Icon(
                                              Icons
                                                  .assignment_turned_in_outlined,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Xác nhận đã hoàn tiền',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              elevation: 0,
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
