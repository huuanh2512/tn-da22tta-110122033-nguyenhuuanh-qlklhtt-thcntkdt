import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'zalopay_webview_page.dart';

import 'package:server_module/server_module.dart';
import 'package:authentication_module/authentication_module.dart';
import '../../domain/entities/payment_detail_entity.dart';
import '../../domain/usecases/get_payments_usecase.dart';
import '../../domain/usecases/update_payment_status_usecase.dart';
import '../../domain/usecases/create_payment_usecase.dart';
import 'package:notification_module/notification_module.dart';
import '../../data/services/zalopay_service.dart';
import 'package:matching_module/matching_module.dart';

class InvoiceDetailPage extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailPage({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isProcessing = false;
  PaymentDetailEntity? _invoice;
  UserResult? _currentUser;
  UserEntity? _bookingUser;
  String _selectedMethod = 'BANK_TRANSFER';
  bool _isZaloPayWaiting = false;
  bool _paymentSuccess = false;
  String? _zaloPayTransId;
  String? _zaloPayQrCode;
  String? _zaloPayOrderUrl;
  Timer? _pollingTimer;

  MatchingSessionEntity? _matchingSession;
  String _splitMode =
      'HOST_PAYS'; // 'HOST_PAYS', 'SPLIT_EQUALLY', 'PAY_OFFLINE'

  static const _primaryColor = Color(0xFFFF5600);

  Color _statusColor(String? status) {
    switch (status) {
      case 'SUCCESS':
      case 'REFUNDED':
        return Colors.green;
      case 'PENDING':
      case 'REFUND_PENDING':
        return Colors.orange;
      case 'FAILED':
        return Colors.red;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'PENDING':
        return Icons.pending_actions_rounded;
      case 'SUCCESS':
        return Icons.check_circle_outline;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      case 'REFUND_PENDING':
        return Icons.hourglass_top_rounded;
      case 'REFUNDED':
        return Icons.assignment_turned_in_outlined;
      default:
        return Icons.error_outline;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'PENDING':
        return context.tr(vi: 'CHỜ THANH TOÁN', en: 'PENDING PAYMENT');
      case 'SUCCESS':
        return context.tr(
          vi: 'ĐÃ THANH TOÁN THÀNH CÔNG',
          en: 'PAID SUCCESSFULLY',
        );
      case 'CANCELLED':
        return context.tr(vi: 'HÓA ĐƠN ĐÃ HỦY', en: 'INVOICE CANCELLED');
      case 'REFUND_PENDING':
        return context.tr(vi: 'ĐANG CHỜ HOÀN TIỀN', en: 'REFUND PENDING');
      case 'REFUNDED':
        return context.tr(vi: 'ĐÃ HOÀN TIỀN', en: 'REFUNDED');
      case 'FAILED':
        return context.tr(vi: 'THANH TOÁN THẤT BẠI', en: 'PAYMENT FAILED');
      default:
        return status ?? '';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Lắng nghe app lifecycle
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// Khi app resume từ nền (ví dụ: user quay về từ ZaloPay Sandbox),
  /// ngầy lập tức kiểm tra trạng thái thanh toán nếu đang ở trong trạng thái chờ ZaloPay
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _isZaloPayWaiting &&
        _zaloPayTransId != null) {
      debugPrint(
        '[ZaloPay] App resumed — kiểm tra trạng thái thanh toán ngay lập tức',
      );
      _checkZaloPayStatusNow();
    }
  }

  /// Kiểm tra trạng thái ZaloPay ngay khi app resume — không đợi timer
  /// Query trực tiếp backend DB (webhook đã cập nhật) thay vì ZaloPay API
  Future<void> _checkZaloPayStatusNow() async {
    if (!mounted || _invoice == null) return;
    try {
      debugPrint('[ZaloPay] Resume check: query backend DB...');

      // ── Bước 1: Kiểm tra từ backend DB (webhook đã cập nhật status này)
      final getPayments = GetIt.I<GetPaymentsUseCase>();
      final response = await getPayments();
      if (response.success && response.data != null) {
        final updated = response.data!
            .where((p) => p.id == _invoice!.id)
            .firstOrNull;
        if (updated != null && updated.status == 'SUCCESS' && mounted) {
          _pollingTimer?.cancel();
          try {
            GetIt.I<AppNotificationEventBus>().emit(
              const AppNotificationEvent(
                type: AppNotificationEventType.paymentOnlineSuccess,
              ),
            );
          } catch (_) {}
          setState(() {
            _invoice = updated;
            _isZaloPayWaiting = false;
            _paymentSuccess = true;
          });
          debugPrint(
            '[ZaloPay] ✅ Backend DB xác nhận SUCCESS sau khi app resume!',
          );
          return;
        }
      }

      // ── Bước 2: Fallback — vẫn query ZaloPay API (dự phòng)
      if (_zaloPayTransId != null) {
        final isPaid = await GetIt.I<ZaloPayService>().checkOrderStatus(
          _zaloPayTransId!,
          paymentId: _invoice?.id,
        );
        if (isPaid && mounted) {
          _pollingTimer?.cancel();
          final updateStatus = GetIt.I<UpdatePaymentStatusUseCase>();
          final resp = await updateStatus(_invoice!.id, 'SUCCESS');
          if (resp.success && resp.data != null && mounted) {
            try {
              GetIt.I<AppNotificationEventBus>().emit(
                const AppNotificationEvent(
                  type: AppNotificationEventType.paymentOnlineSuccess,
                ),
              );
            } catch (_) {}
            setState(() {
              _invoice = resp.data;
              _isZaloPayWaiting = false;
              _paymentSuccess = true;
            });
            debugPrint(
              '[ZaloPay] ✅ ZaloPay API xác nhận SUCCESS sau khi resume!',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ZaloPay] ❌ Resume check lỗi: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      // Load current logged in user
      _currentUser = (await GetIt.I<GetLocalUserUseCase>()()).fold(
        (_) => null,
        (user) => user,
      );

      // Load all payments and find the matching invoice (payment)
      final getPayments = GetIt.I<GetPaymentsUseCase>();
      final response = await getPayments();

      if (response.success && response.data != null) {
        final found = response.data!.where(
          (p) => p.id == widget.invoiceId || p.bookingId == widget.invoiceId,
        );
        if (found.isNotEmpty) {
          _invoice = found.first;
        } else {
          // Recover a missing invoice only after the booking has been approved.
          final bookingRepo = GetIt.I<BookingRepository>();
          final bookingRes = await bookingRepo.getBookingById(widget.invoiceId);
          if (bookingRes.success && bookingRes.data != null) {
            final booking = bookingRes.data!;
            if (booking.status == 'CONFIRMED') {
              final createPayment = GetIt.I<CreatePaymentUseCase>();
              final paymentRes = await createPayment(
                bookingId: booking.id,
                amount: booking.totalPrice ?? 0.0,
                method: 'BANK_TRANSFER',
                transactionId:
                    'TXN_AUTO_${DateTime.now().millisecondsSinceEpoch}',
              );
              if (paymentRes.success && paymentRes.data != null) {
                _invoice = paymentRes.data;
              }
            }
          }
        }

        // Fetch user details for the booking creator if it exists
        if (_invoice?.booking?.userId != null) {
          final userService = GetIt.I<UserService>();
          final userRes = await userService.getUserById(
            _invoice!.booking!.userId!,
          );
          if (userRes.success && userRes.data != null) {
            final map = userRes.data as Map<String, dynamic>;
            _bookingUser = UserEntity(
              id: map['id'] ?? map['_id'] ?? '',
              email: map['email'],
              name: map['name'],
              avatar: map['avatar'],
              role: map['role'],
              status: map['status'],
            );
          }
        }

        // Find matching session if exists
        try {
          final getMatchingSessions = GetIt.I<GetMatchingSessionsUseCase>();
          final sessionsRes = await getMatchingSessions();
          if (sessionsRes.success && sessionsRes.data != null) {
            final matchedSessions = sessionsRes.data!.where(
              (s) =>
                  s.bookingId == _invoice!.bookingId ||
                  s.bookingId == _invoice!.id,
            );
            if (matchedSessions.isNotEmpty) {
              _matchingSession = matchedSessions.first;
            }
          }
        } catch (e) {
          debugPrint('Error loading matching session for invoice: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading invoice detail: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmPayment({required bool isOnline}) async {
    if (_invoice == null) return;
    if (_invoice!.booking?.status == 'CANCELLED') {
      _showSnackBar(
        context.tr(
          vi: 'Booking đã hủy, hóa đơn không còn hiệu lực.',
          en: 'The booking was cancelled, so this invoice is no longer valid.',
        ),
        isError: true,
      );
      return;
    }
    String lang = 'vi';
    try {
      lang = context.read<LanguageCubit>().state;
    } catch (_) {}
    String translate(String vi, String en) => lang == 'vi' ? vi : en;

    setState(() {
      _isProcessing = true;
    });

    try {
      final transactionRef = isOnline
          ? 'pay-online-${DateTime.now().millisecondsSinceEpoch}'
          : 'pay-cash-staff-${_currentUser?.userId ?? "unknown"}-${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('Transaction ref: $transactionRef');

      final updateStatus = GetIt.I<UpdatePaymentStatusUseCase>();

      // Update payment status to SUCCESS
      final response = await updateStatus(_invoice!.id, 'SUCCESS');

      if (response.success && response.data != null && mounted) {
        try {
          GetIt.I<AppNotificationEventBus>().emit(
            AppNotificationEvent(
              type: isOnline
                  ? AppNotificationEventType.paymentOnlineSuccess
                  : AppNotificationEventType.paymentOfflineConfirmed,
            ),
          );
        } catch (e) {
          debugPrint('Error emitting invoice payment event: $e');
        }

        final userId = _invoice?.booking?.userId;
        if (userId != null) {
          try {
            await GetIt.I<CreateNotificationUseCase>().call(
              userId: userId,
              title: translate(
                'Thanh toán hóa đơn thành công',
                'Payment successful',
              ),
              body: translate(
                'Hóa đơn thanh toán trị giá ${response.data!.amount ?? 0.0}đ đã được xác nhận thành công.',
                'Invoice of ${response.data!.amount ?? 0.0} VND has been successfully confirmed.',
              ),
              type: 'PAYMENT',
            );
            GetIt.I<NotificationCubit>().loadNotifications();
          } catch (_) {}
        }
        // Optimistically update status
        setState(() {
          _invoice = response.data;
        });
        _showSnackBar(
          isOnline
              ? translate(
                  'Thanh toán online qua ví điện tử thành công!',
                  'Online payment via e-wallet successful!',
                )
              : translate(
                  'Xác nhận thu tiền mặt offline thành công!',
                  'Offline cash collection confirmed!',
                ),
          isError: false,
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } else if (mounted) {
        _showSnackBar(
          translate(
            'Cập nhật trạng thái thất bại: ${response.message}',
            'Status update failed: ${response.message}',
          ),
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          context.tr(vi: 'Lỗi thanh toán: $e', en: 'Payment error: $e'),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _checkZaloPayStatus() async {
    if (_zaloPayTransId == null || _invoice == null) return;

    String lang = 'vi';
    try {
      lang = context.read<LanguageCubit>().state;
    } catch (_) {}
    String translate(String vi, String en) => lang == 'vi' ? vi : en;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Truyền paymentId để backend tự động cập nhật DB nếu đã thanh toán
      final isPaid = await GetIt.I<ZaloPayService>().checkOrderStatus(
        _zaloPayTransId!,
        paymentId: _invoice!.id,
      );
      if (isPaid) {
        final updateStatus = GetIt.I<UpdatePaymentStatusUseCase>();
        final response = await updateStatus(_invoice!.id, 'SUCCESS');

        if (response.success && response.data != null && mounted) {
          try {
            GetIt.I<AppNotificationEventBus>().emit(
              const AppNotificationEvent(
                type: AppNotificationEventType.paymentOnlineSuccess,
              ),
            );
          } catch (e) {
            debugPrint('Error emitting ZaloPay payment event: $e');
          }

          final userId = _invoice?.booking?.userId;
          if (userId != null) {
            try {
              await GetIt.I<CreateNotificationUseCase>().call(
                userId: userId,
                title: translate(
                  'Thanh toán hóa đơn thành công',
                  'Payment successful',
                ),
                body: translate(
                  'Hóa đơn thanh toán qua ZaloPay trị giá ${response.data!.amount ?? 0.0}đ đã được xác nhận thành công.',
                  'Invoice of ${response.data!.amount ?? 0.0} VND paid via ZaloPay has been successfully confirmed.',
                ),
                type: 'PAYMENT',
              );
              GetIt.I<NotificationCubit>().loadNotifications();
            } catch (_) {}
          }

          setState(() {
            _invoice = response.data;
            _isZaloPayWaiting = false;
          });

          _showSnackBar(
            translate(
              'Thanh toán qua ZaloPay thành công!',
              'Payment via ZaloPay successful!',
            ),
            isError: false,
          );

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        } else if (mounted) {
          _showSnackBar(
            translate(
              'Cập nhật trạng thái thất bại: ${response.message}',
              'Status update failed: ${response.message}',
            ),
            isError: true,
          );
        }
      } else {
        if (mounted) {
          _showSnackBar(
            translate(
              'Giao dịch chưa hoàn thành hoặc đang xử lý. Vui lòng hoàn tất thanh toán trên ZaloPay.',
              'Transaction not complete or processing. Please complete payment on ZaloPay.',
            ),
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          translate(
            'Lỗi xác minh ZaloPay: $e',
            'ZaloPay verification error: $e',
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _startZaloPayPayment() async {
    if (_invoice == null) return;

    String lang = 'vi';
    try {
      lang = context.read<LanguageCubit>().state;
    } catch (_) {}
    String translate(String vi, String en) => lang == 'vi' ? vi : en;

    if (_isZaloPayWaiting) return;
    if (_zaloPayTransId != null && _zaloPayOrderUrl != null) {
      setState(() => _isZaloPayWaiting = true);
      _startPollingZaloPayStatus(translate);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final response = await GetIt.I<ZaloPayService>().createOrder(
        paymentId: _invoice!.id,
      );

      if (response != null && response['app_trans_id'] != null) {
        final transId = response['app_trans_id'] as String;
        final String orderUrl = (response['order_url'] as String?) ?? '';
        final qrCode =
            response['qr_code'] as String? ??
            (orderUrl.isNotEmpty
                ? orderUrl
                : response['deeplink_url'] as String?);

        setState(() {
          _isZaloPayWaiting = true;
          _zaloPayTransId = transId;
          _zaloPayQrCode = qrCode?.isNotEmpty == true ? qrCode : null;
          _zaloPayOrderUrl = orderUrl;
        });

        debugPrint('[ZaloPay] order_url: $orderUrl');

        // Mở in-app WebView — hiển thị ZaloPay gateway ngay trong app
        // WebView sẽ intercept zalopay:// deeplink và mở ZaloPay Sandbox
        // Bắt đầu polling tự động (mỗi 3 giây, tối đa 2 phút)
        _startPollingZaloPayStatus(translate);
      } else {
        throw Exception(
          translate(
            'Tạo đơn hàng ZaloPay thất bại. Vui lòng thử lại.',
            'Failed to create ZaloPay order. Please try again.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          '${translate('Lỗi cổng thanh toán: ', 'Payment gateway error: ')}${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Polling tự động kiểm tra trạng thái ZaloPay mỗi 3 giây (tối đa 40 lần = 2 phút)
  /// Ưu tiên query backend DB (webhook sẽ đã cập nhật) thay vì chỉ dựa vào ZaloPay API
  Future<void> _openZaloPayCheckout() async {
    final orderUrl = _zaloPayOrderUrl;
    if (orderUrl == null || orderUrl.isEmpty || !mounted) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ZaloPayWebViewPage(orderUrl: orderUrl),
        fullscreenDialog: true,
      ),
    );

    if (mounted) {
      await _checkZaloPayStatus();
    }
  }

  void _startPollingZaloPayStatus(String Function(String, String) translate) {
    _pollingTimer?.cancel();
    int attempts = 0;
    const maxAttempts = 40;

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _invoice == null) {
        timer.cancel();
        return;
      }
      attempts++;
      if (attempts > maxAttempts) {
        timer.cancel();
        return;
      }

      try {
        // ── Bước 1: Query backend DB trước — webhook đã cập nhật status
        final getPayments = GetIt.I<GetPaymentsUseCase>();
        final response = await getPayments();
        if (response.success && response.data != null) {
          final updated = response.data!
              .where((p) => p.id == _invoice!.id)
              .firstOrNull;
          if (updated != null && updated.status == 'SUCCESS' && mounted) {
            timer.cancel();
            try {
              GetIt.I<AppNotificationEventBus>().emit(
                const AppNotificationEvent(
                  type: AppNotificationEventType.paymentOnlineSuccess,
                ),
              );
            } catch (_) {}
            setState(() {
              _invoice = updated;
              _isZaloPayWaiting = false;
              _paymentSuccess = true;
            });
            debugPrint(
              '[ZaloPay] ✅ Backend DB polling phát hiện SUCCESS (lần thử $attempts)',
            );
            return;
          }
        }

        // ── Bước 2: Fallback query ZaloPay API
        if (_zaloPayTransId != null) {
          final isPaid = await GetIt.I<ZaloPayService>().checkOrderStatus(
            _zaloPayTransId!,
            paymentId: _invoice?.id,
          );
          if (isPaid && mounted) {
            timer.cancel();
            final updateStatus = GetIt.I<UpdatePaymentStatusUseCase>();
            final resp = await updateStatus(_invoice!.id, 'SUCCESS');
            if (resp.success && resp.data != null && mounted) {
              try {
                GetIt.I<AppNotificationEventBus>().emit(
                  const AppNotificationEvent(
                    type: AppNotificationEventType.paymentOnlineSuccess,
                  ),
                );
              } catch (_) {}
              setState(() {
                _invoice = resp.data;
                _isZaloPayWaiting = false;
                _paymentSuccess = true;
              });
              debugPrint(
                '[ZaloPay] ✅ ZaloPay API polling phát hiện SUCCESS (lần thử $attempts)',
              );
            }
          }
        }
      } catch (_) {
        // Bỏ qua lỗi polling, thử lại lần sau
      }
    });
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatPrice(BuildContext context, double? price) {
    if (price == null) return context.tr(vi: '0 đ', en: '0 VND');
    final intPrice = price.toInt();
    final s = intPrice.toString();
    final result = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) result.write('.');
      result.write(s[i]);
    }
    return context.tr(
      vi: '${result.toString()} đ',
      en: '${result.toString()} VND',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    // Màn hình thanh toán thành công – hiển thị sau khi ZaloPay xác nhận
    if (_paymentSuccess && _invoice != null) {
      return _buildPaymentSuccessScreen(context);
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr(vi: 'HÓA ĐƠN', en: 'INVOICE')),
        ),
        body: Center(
          child: Text(
            context.tr(
              vi: 'Không tìm thấy hóa đơn này.',
              en: 'Invoice not found.',
            ),
          ),
        ),
      );
    }

    final effectiveStatus = _invoice!.booking?.status == 'CANCELLED'
        ? 'CANCELLED'
        : _invoice!.status;
    final isPending = effectiveStatus == 'PENDING';
    final statusColor = _statusColor(effectiveStatus);
    final isStaff =
        _currentUser?.role == 'staff' || _currentUser?.role == 'admin';

    final shortBookingId =
        _invoice!.bookingId != null && _invoice!.bookingId!.length > 6
        ? _invoice!.bookingId!.substring(0, 6)
        : _invoice!.bookingId ?? '';

    final timeStr =
        _invoice!.startMinutes != null && _invoice!.endMinutes != null
        ? '${DateDisplayFormatter.fromApiDate(_invoice!.bookingDate)} • ${(_invoice!.startMinutes! ~/ 60).toString().padLeft(2, '0')}:${(_invoice!.startMinutes! % 60).toString().padLeft(2, '0')} - ${(_invoice!.endMinutes! ~/ 60).toString().padLeft(2, '0')}:${(_invoice!.endMinutes! % 60).toString().padLeft(2, '0')}'
        : DateDisplayFormatter.fromApiDate(_invoice!.bookingDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(vi: 'CHI TIẾT HÓA ĐƠN', en: 'INVOICE DETAIL'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: _primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    context.tr(
                      vi: 'Đang xử lý giao dịch...',
                      en: 'Processing transaction...',
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Header Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    color: statusColor.withValues(alpha: 0.04),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _statusIcon(effectiveStatus),
                            size: 44,
                            color: statusColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _statusLabel(effectiveStatus),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${context.tr(vi: 'Hóa đơn ', en: 'Invoice ')}#${widget.invoiceId.substring(0, 6).toUpperCase()}',
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Invoice Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(vi: 'THÔNG TIN CHI TIẾT', en: 'DETAILS'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            context.tr(vi: 'Sân đấu', en: 'Court'),
                            _invoice!.courtName ??
                                context.tr(
                                  vi: 'Sân thi đấu',
                                  en: 'Match Court',
                                ),
                          ),
                          if (_invoice!.sportName != null &&
                              _invoice!.sportName!.isNotEmpty)
                            _buildDetailRow(
                              context.tr(vi: 'Môn thể thao', en: 'Sport'),
                              _invoice!.sportName!,
                            ),
                          _buildDetailRow(
                            context.tr(vi: 'Thời gian', en: 'Time'),
                            timeStr,
                          ),
                          _buildDetailRow(
                            context.tr(vi: 'Mã Booking', en: 'Booking ID'),
                            '#${shortBookingId.toUpperCase()}',
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            context.tr(vi: 'Tổng tiền', en: 'Total Amount'),
                            _formatPrice(context, _invoice!.amount),
                            valueStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBillSplittingCard(theme),
                  if (_matchingSession != null) const SizedBox(height: 16),

                  // Customer details if viewed by staff/admin
                  if (isStaff && _bookingUser != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                vi: 'THÔNG TIN KHÁCH HÀNG',
                                en: 'CUSTOMER INFORMATION',
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              context.tr(vi: 'Họ và tên', en: 'Full Name'),
                              _bookingUser!.name ??
                                  context.tr(vi: 'Khách hàng', en: 'Customer'),
                            ),
                            _buildDetailRow(
                              context.tr(vi: 'Email', en: 'Email'),
                              _bookingUser!.email ?? '',
                            ),
                            _buildDetailRow(
                              context.tr(vi: 'Vai trò', en: 'Role'),
                              context.tr(
                                vi: 'Thành viên App',
                                en: 'App Member',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (isPending) ...[
                    // Payment Method Selector Card
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
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                vi: 'PHƯƠNG THỨC THANH TOÁN',
                                en: 'PAYMENT METHOD',
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: Container(
                                      alignment: Alignment.center,
                                      child: Text(
                                        context.tr(
                                          vi: 'Chuyển khoản',
                                          en: 'Bank Transfer',
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    selected:
                                        _selectedMethod == 'BANK_TRANSFER',
                                    onSelected: (val) {
                                      if (val) {
                                        _pollingTimer?.cancel();
                                        setState(() {
                                          _selectedMethod = 'BANK_TRANSFER';
                                          _isZaloPayWaiting = false;
                                          _zaloPayTransId = null;
                                          _zaloPayQrCode = null;
                                          _zaloPayOrderUrl = null;
                                        });
                                      }
                                    },
                                    selectedColor: _primaryColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    checkmarkColor: _primaryColor,
                                    labelStyle: TextStyle(
                                      color: _selectedMethod == 'BANK_TRANSFER'
                                          ? _primaryColor
                                          : Colors.grey,
                                    ),
                                    backgroundColor: theme.cardColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color:
                                            _selectedMethod == 'BANK_TRANSFER'
                                            ? _primaryColor
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ChoiceChip(
                                    label: Container(
                                      alignment: Alignment.center,
                                      child: Text(
                                        context.tr(
                                          vi: 'Ví ZaloPay',
                                          en: 'ZaloPay Wallet',
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    selected: _selectedMethod == 'ZALOPAY',
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() {
                                          _selectedMethod = 'ZALOPAY';
                                        });
                                        if (!_isZaloPayWaiting) {
                                          _startZaloPayPayment();
                                        }
                                      }
                                    },
                                    selectedColor: const Color(
                                      0xFF0070BA,
                                    ).withValues(alpha: 0.12),
                                    checkmarkColor: const Color(0xFF0070BA),
                                    labelStyle: TextStyle(
                                      color: _selectedMethod == 'ZALOPAY'
                                          ? const Color(0xFF0070BA)
                                          : Colors.grey,
                                    ),
                                    backgroundColor: theme.cardColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: _selectedMethod == 'ZALOPAY'
                                            ? const Color(0xFF0070BA)
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_selectedMethod == 'BANK_TRANSFER') ...[
                      if (isStaff) ...[
                        // Staff: Collect Cash (Offline) button
                        ElevatedButton(
                          onPressed: () => _confirmPayment(isOnline: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            context.tr(
                              vi: 'XÁC NHẬN ĐÃ THU TIỀN MẶT (OFFLINE)',
                              en: 'CONFIRM CASH RECEIVED (OFFLINE)',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Customer or alternative payment mode: QR Transfer Code
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                context.tr(
                                  vi: 'QUÉT MÃ QR ĐỂ THANH TOÁN ONLINE',
                                  en: 'SCAN QR CODE FOR ONLINE PAYMENT',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Simulated QR code
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Opacity(
                                      opacity: 0.1,
                                      child: GridView.builder(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 8,
                                            ),
                                        itemCount: 64,
                                        itemBuilder: (context, idx) =>
                                            Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.qr_code_2,
                                      size: 120,
                                      color: Colors.black87,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: _primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.sports_soccer,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '${context.tr(vi: 'Nội dung chuyển khoản: ', en: 'Transfer message: ')}SP ENERGY HD ${shortBookingId.toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Pay Online button
                      ElevatedButton(
                        onPressed: () => _confirmPayment(isOnline: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          context.tr(
                            vi: 'MÔ PHỎNG THANH TOÁN ONLINE THÀNH CÔNG',
                            en: 'SIMULATE SUCCESSFUL ONLINE PAYMENT',
                          ),
                        ),
                      ),
                    ] else ...[
                      if (_isZaloPayWaiting) ...[
                        // Waiting overlay card
                        Card(
                          color: const Color(0xFFF2F9FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: const Color(0xFFB3D9FF)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                if (_zaloPayQrCode != null) ...[
                                  Text(
                                    context.tr(
                                      vi: 'QUÉT MÃ ĐỂ THANH TOÁN',
                                      en: 'SCAN TO PAY',
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF005999),
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: QrImageView(
                                      data: _zaloPayQrCode!,
                                      size: 180,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF0070BA),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape:
                                            QrDataModuleShape.square,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ] else ...[
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF0070BA),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                Text(
                                  context.tr(
                                    vi: 'ĐANG CHỜ THANH TOÁN QUA ZALOPAY',
                                    en: 'WAITING FOR ZALOPAY PAYMENT',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF005999),
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.tr(
                                    vi: 'Vui lòng hoàn thành giao dịch trên cổng thanh toán ZaloPay được mở, sau đó ấn nút xác minh kết quả bên dưới.',
                                    en: 'Please complete the transaction on the opened ZaloPay gateway page, then tap the verification button below.',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: _openZaloPayCheckout,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0070BA),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(
                                      Icons.open_in_new,
                                      size: 18,
                                    ),
                                    label: Text(
                                      context.tr(
                                        vi: 'THANH TOÁN NGAY',
                                        en: 'PAY NOW',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: _checkZaloPayStatus,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0070BA),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(
                                      Icons.verified_user_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      context.tr(
                                        vi: 'KIỂM TRA KẾT QUẢ GIAO DỊCH',
                                        en: 'VERIFY TRANSACTION RESULT',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    _pollingTimer?.cancel();
                                    setState(() {
                                      _isZaloPayWaiting = false;
                                      _zaloPayTransId = null;
                                      _zaloPayQrCode = null;
                                      _zaloPayOrderUrl = null;
                                    });
                                  },
                                  child: Text(
                                    context.tr(
                                      vi: 'Chọn phương thức thanh toán khác',
                                      en: 'Select other payment method',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // ZaloPay QR display and Open Button
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: const Color(
                                0xFF0070BA,
                              ).withValues(alpha: 0.15),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(
                                  context.tr(
                                    vi: 'QUÉT MÃ QR THANH TOÁN ZALOPAY SANDBOX',
                                    en: 'SCAN QR FOR ZALOPAY SANDBOX',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: const Color(
                                        0xFF0070BA,
                                      ).withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Opacity(
                                        opacity: 0.08,
                                        child: GridView.builder(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 8,
                                              ),
                                          itemCount: 64,
                                          itemBuilder: (context, idx) =>
                                              Container(
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF0070BA,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.qr_code_scanner_rounded,
                                        size: 110,
                                        color: Color(0xFF0070BA),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF0070BA),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.payment,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  context.tr(
                                    vi: 'Cổng thanh toán ZaloPay Sandbox hỗ trợ mô phỏng giao dịch thực tế.',
                                    en: 'ZaloPay Sandbox checkout simulates live transactions for testing.',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _startZaloPayPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0070BA),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(
                              context.tr(
                                vi: 'MỞ THANH TOÁN QUA CỔNG ZALOPAY',
                                en: 'OPEN ZALOPAY PAYMENT PORTAL',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ] else ...[
                    // Receipt / payment details
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                vi: 'THÔNG TIN GIAO DỊCH',
                                en: 'TRANSACTION DETAILS',
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              context.tr(vi: 'Phương thức', en: 'Method'),
                              _invoice!.method ?? 'BANK_TRANSFER',
                            ),
                            _buildDetailRow(
                              context.tr(
                                vi: 'Mã giao dịch',
                                en: 'Transaction ID',
                              ),
                              (_invoice!.id.length > 8
                                      ? _invoice!.id.substring(
                                          _invoice!.id.length - 8,
                                        )
                                      : _invoice!.id)
                                  .toUpperCase(),
                            ),
                            _buildDetailRow(
                              context.tr(vi: 'Trạng thái', en: 'Status'),
                              context.tr(vi: 'Thành công', en: 'Success'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      context.tr(vi: 'Quay lại', en: 'Back'),
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Màn hình hiển thị thanh toán ZaloPay thành công
  Widget _buildPaymentSuccessScreen(BuildContext context) {
    final amount = _invoice?.amount;
    final formattedAmount = _formatPrice(context, amount);
    final bookingId = _invoice?.bookingId ?? _invoice?.id ?? '';
    final shortId = bookingId.length > 6
        ? bookingId.substring(0, 6).toUpperCase()
        : bookingId.toUpperCase();

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00C853), Color(0xFF009624)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon thành công với hiệu ứng nền tròn
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF00C853),
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                context.tr(
                  vi: 'Thanh toán thành công!',
                  en: 'Payment Successful!',
                ),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  vi: 'Giao dịch của bạn đã được xác nhận',
                  en: 'Your transaction has been confirmed',
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 32),
              // Card thông tin giao dịch
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr(vi: 'Số tiền', en: 'Amount'),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              formattedAmount,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00C853),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr(vi: 'Mã hóa đơn', en: 'Invoice ID'),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '#$shortId',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr(vi: 'Phương thức', en: 'Method'),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            const Row(
                              children: [
                                Icon(
                                  Icons.wallet,
                                  size: 16,
                                  color: Color(0xFF0070BA),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'ZaloPay',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF0070BA),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr(vi: 'Trạng thái', en: 'Status'),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF00C853,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                context.tr(vi: 'Thành công', en: 'Success'),
                                style: const TextStyle(
                                  color: Color(0xFF00C853),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF00C853),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      context.tr(vi: 'Về trang chủ', en: 'Back to Home'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style:
                  valueStyle ??
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillSplittingCard(ThemeData theme) {
    if (_matchingSession == null) return const SizedBox.shrink();

    final totalAmount = _invoice!.amount ?? 0.0;
    final approvedMembersCount = _matchingSession!.members
        .where((m) => m.status == 'APPROVED')
        .length;
    final totalPlayers = approvedMembersCount + 1; // Members + Host

    double amountPerPerson = totalAmount / totalPlayers;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                vi: 'CHIA SẺ HÓA ĐƠN (GHÉP TRẬN)',
                en: 'BILL SPLITTING (MATCHMAKING)',
              ),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Container(
                      alignment: Alignment.center,
                      child: Text(
                        context.tr(vi: 'Chủ phòng trả', en: 'Host Pays'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    selected: _splitMode == 'HOST_PAYS',
                    onSelected: (val) {
                      if (val) setState(() => _splitMode = 'HOST_PAYS');
                    },
                    selectedColor: _primaryColor.withValues(alpha: 0.12),
                    checkmarkColor: _primaryColor,
                    labelStyle: TextStyle(
                      color: _splitMode == 'HOST_PAYS'
                          ? _primaryColor
                          : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ChoiceChip(
                    label: Container(
                      alignment: Alignment.center,
                      child: Text(
                        context.tr(vi: 'Chia đều', en: 'Split Equally'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    selected: _splitMode == 'SPLIT_EQUALLY',
                    onSelected: (val) {
                      if (val) setState(() => _splitMode = 'SPLIT_EQUALLY');
                    },
                    selectedColor: _primaryColor.withValues(alpha: 0.12),
                    checkmarkColor: _primaryColor,
                    labelStyle: TextStyle(
                      color: _splitMode == 'SPLIT_EQUALLY'
                          ? _primaryColor
                          : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ChoiceChip(
                    label: Container(
                      alignment: Alignment.center,
                      child: Text(
                        context.tr(vi: 'Chia tại sân', en: 'Pay Offline'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    selected: _splitMode == 'PAY_OFFLINE',
                    onSelected: (val) {
                      if (val) setState(() => _splitMode = 'PAY_OFFLINE');
                    },
                    selectedColor: _primaryColor.withValues(alpha: 0.12),
                    checkmarkColor: _primaryColor,
                    labelStyle: TextStyle(
                      color: _splitMode == 'PAY_OFFLINE'
                          ? _primaryColor
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_splitMode == 'HOST_PAYS') ...[
              Text(
                context.tr(
                  vi: 'Chủ phòng (${_matchingSession!.hostName}) chịu trách nhiệm thanh toán toàn bộ hóa đơn.',
                  en: 'The host (${_matchingSession!.hostName}) is responsible for paying the entire bill.',
                ),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              _buildSplitRow(
                context.tr(vi: 'Chủ phòng cần trả', en: 'Host pays'),
                totalAmount,
                isHighlight: true,
              ),
            ] else if (_splitMode == 'SPLIT_EQUALLY') ...[
              Text(
                context.tr(
                  vi: 'Hóa đơn được chia đều cho tất cả $totalPlayers người chơi (Host + $approvedMembersCount thành viên đã duyệt).',
                  en: 'The bill is split equally among all $totalPlayers players (Host + $approvedMembersCount approved members).',
                ),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              _buildSplitRow(
                context.tr(vi: 'Mỗi người trả', en: 'Per person share'),
                amountPerPerson,
                isHighlight: true,
              ),
              const Divider(height: 20),
              _buildSplitRow(
                context.tr(
                  vi: 'Chủ phòng (${_matchingSession!.hostName})',
                  en: 'Host (${_matchingSession!.hostName})',
                ),
                amountPerPerson,
              ),
              ..._matchingSession!.members
                  .where((m) => m.status == 'APPROVED')
                  .map((m) {
                    return _buildSplitRow(m.name, amountPerPerson);
                  }),
            ] else if (_splitMode == 'PAY_OFFLINE') ...[
              Text(
                context.tr(
                  vi: 'Người chơi tự thanh toán phần của mình trực tiếp tại quầy lễ tân của sân.',
                  en: 'Players will pay their respective shares directly at the court reception desk.',
                ),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              _buildSplitRow(
                context.tr(vi: 'Phần chia mỗi người', en: 'Per person share'),
                amountPerPerson,
                isHighlight: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSplitRow(
    String label,
    double amount, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isHighlight ? 14 : 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            _formatPrice(context, amount),
            style: TextStyle(
              fontSize: isHighlight ? 15 : 13,
              fontWeight: FontWeight.bold,
              color: isHighlight ? _primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }
}
