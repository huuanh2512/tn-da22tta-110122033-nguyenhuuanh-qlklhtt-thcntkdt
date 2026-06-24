import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:notification_module/notification_module.dart';
import 'package:server_module/server_module.dart';
import 'package:review_module/review_module.dart';
import '../../domain/entities/booking_detail_entity.dart';
import '../../domain/entities/slot_config_entity.dart';
import '../../domain/usecases/cancel_fixed_schedule_usecase.dart';
import '../../domain/usecases/get_booking_history_usecase.dart';
import '../../domain/usecases/get_slot_config_usecase.dart';
import '../../domain/usecases/update_booking_usecase.dart';
import '../cubit/booking_detail_cubit.dart';
import '../utils/booking_ui_helper.dart';

class BookingDetailPage extends StatefulWidget {
  final String bookingId;

  const BookingDetailPage({super.key, required this.bookingId});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  late BookingDetailCubit _cubit;
  bool _isCancellingFixedSchedule = false;

  static const _primaryColor = Color(0xFFFF5600);

  @override
  void initState() {
    super.initState();
    _cubit = BookingDetailCubit(GetIt.I(), GetIt.I());
    _cubit.loadBookingDetail(widget.bookingId);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  String _formatPrice(BuildContext context, double? price) {
    if (price == null) return context.tr(vi: '0 đ', en: '0 VND');
    final formatted = price.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return context.tr(vi: '$formatted đ', en: '$formatted VND');
  }

  String _formatTimeRange(BookingDetailEntity booking) {
    final start = booking.startMinutes;
    final end = booking.endMinutes;
    if (start == null || end == null) return '--:-- - --:--';

    String asTime(int minutes) {
      return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
    }

    return '${asTime(start)} - ${asTime(end)}';
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'PENDING':
        return _primaryColor;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(vi: 'CHI TIẾT ĐẶT SÂN', en: 'BOOKING DETAIL'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: BlocBuilder<BookingDetailCubit, BookingDetailState>(
        bloc: _cubit,
        builder: (context, state) {
          if (state is BookingDetailLoading) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          if (state is BookingDetailError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(state.message, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _cubit.loadBookingDetail(widget.bookingId),
                    child: Text(context.tr(vi: 'Thử lại', en: 'Retry')),
                  ),
                ],
              ),
            );
          }

          if (state is BookingDetailLoaded) {
            final booking = state.booking;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBanner(booking),
                  if (_hasCancellationInfo(booking)) ...[
                    const SizedBox(height: 12),
                    _buildCancellationInfoCard(booking),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                    context.tr(
                      vi: 'THÔNG TIN ĐẶT SÂN',
                      en: 'BOOKING INFORMATION',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard([
                    _buildInfoRow(
                      context.tr(vi: 'Mã booking', en: 'Booking ID'),
                      '#${(booking.id.length > 8 ? booking.id.substring(booking.id.length - 8) : booking.id).toUpperCase()}',
                    ),
                    _buildInfoRow(
                      context.tr(vi: 'Ngày đặt', en: 'Booking Date'),
                      DateDisplayFormatter.fromApiDate(booking.bookingDate),
                    ),
                    _buildInfoRow(
                      context.tr(vi: 'Thời gian', en: 'Time'),
                      _formatTimeRange(booking),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                    context.tr(
                      vi: 'THÔNG TIN NGƯỜI ĐẶT',
                      en: 'BOOKER INFORMATION',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBookerInfoCard(booking),
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                    context.tr(vi: 'THÔNG TIN SÂN', en: 'COURT INFORMATION'),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard([
                    _buildInfoRow(
                      context.tr(vi: 'Tên sân', en: 'Court Name'),
                      booking.courtName ?? '',
                    ),
                    _buildInfoRow(
                      context.tr(vi: 'Mã sân', en: 'Court Code'),
                      booking.courtCode ?? '',
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                    context.tr(
                      vi: 'CHI TIẾT THANH TOÁN',
                      en: 'PAYMENT DETAILS',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard([
                    _buildInfoRow(
                      context.tr(vi: 'Tổng tiền', en: 'Total price'),
                      _formatPrice(context, booking.totalPrice),
                      isBold: true,
                      valueColor: _primaryColor,
                    ),
                    _buildInfoRow(
                      context.tr(vi: 'Phương thức', en: 'Method'),
                      context.tr(
                        vi: 'Chuyển khoản ngân hàng',
                        en: 'Bank Transfer',
                      ),
                    ),
                  ]),
                  if (booking.status == 'PENDING') ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: state.isCancelling
                            ? null
                            : () async {
                                final success = await context.push<bool>(
                                  '/payments/invoices/${booking.id}',
                                );
                                if (success == true && context.mounted) {
                                  _cubit.loadBookingDetail(widget.bookingId);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          context.tr(vi: 'THANH TOÁN NGAY', en: 'PAY NOW'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (booking.status == 'PENDING' ||
                      booking.status == 'CONFIRMED') ...[
                    const SizedBox(height: 12),
                    if (_canShowRescheduleAction(booking)) ...[
                      _buildRescheduleBookingButton(booking),
                      const SizedBox(height: 12),
                    ],
                    _buildCancelBookingPanel(booking, state.isCancelling),
                  ],
                  if (booking.status == 'COMPLETED') ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (booking.courtId != null) {
                            ReviewBottomSheet.show(
                              context,
                              courtId: booking.courtId!,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          context.tr(vi: 'ĐÁNH GIÁ SÂN', en: 'RATE COURT'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildStatusBanner(BookingDetailEntity booking) {
    final isFixedPending =
        booking.status == 'PENDING' &&
        (booking.isFixedSchedule == true || booking.fixedScheduleId != null);
    final statusColor = isFixedPending
        ? Colors.amber
        : _getStatusColor(booking.status);
    final statusText = isFixedPending
        ? context.tr(
            vi: 'Lịch cố định - Chờ thanh toán',
            en: 'Fixed Schedule - Pending Payment',
          )
        : context.tr(
            vi: BookingUiHelper.statusTextVi(booking),
            en: BookingUiHelper.statusTextEn(booking),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            isFixedPending ? Icons.warning_amber_rounded : Icons.info_outline,
            color: statusColor,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            statusText.toUpperCase(),
            style: TextStyle(
              color: isFixedPending ? Colors.amber.shade900 : statusColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${context.tr(vi: 'Cập nhật lúc: ', en: 'Updated at: ')}${booking.createdAt != null ? BookingUiHelper.formatDateTime(booking.createdAt!) : ''}',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasCancellationInfo(BookingDetailEntity booking) {
    return booking.status == 'CANCELLED' &&
        (BookingUiHelper.cancellationMessageVi(booking) != null ||
            booking.cancelledAt != null);
  }

  String? _textOrNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  Widget _buildBookerInfoCard(BookingDetailEntity booking) {
    final guestName = _textOrNull(booking.guestName);
    final guestPhone = _textOrNull(booking.guestPhone);
    final user = booking.user;
    final registeredName = _textOrNull(user?.name);
    final registeredEmail = _textOrNull(user?.email);
    final registeredPhone = _textOrNull(user?.phone);
    final isGuest = guestName != null || guestPhone != null;

    return _buildInfoCard([
      _buildInfoRow(
        context.tr(vi: 'Người đặt', en: 'Booker'),
        guestName ??
            registeredName ??
            context.tr(vi: 'Chưa có tên', en: 'No name'),
        isBold: true,
      ),
      _buildInfoRow(
        context.tr(vi: 'Số điện thoại', en: 'Phone'),
        guestPhone ??
            registeredPhone ??
            context.tr(vi: 'Chưa có SĐT', en: 'No phone'),
      ),
      if (!isGuest && registeredEmail != null)
        _buildInfoRow(context.tr(vi: 'Email', en: 'Email'), registeredEmail),
    ]);
  }

  Widget _buildCancellationInfoCard(BookingDetailEntity booking) {
    final messageVi = BookingUiHelper.cancellationMessageVi(booking);
    final messageEn = BookingUiHelper.cancellationMessageEn(booking);
    final paymentStatus = booking.paymentStatus;
    final isFixedOccurrence =
        booking.isFixedSchedule == true && booking.fixedScheduleId != null;

    return _buildInfoCard([
      if (messageVi != null && messageEn != null)
        _buildInfoRow(
          context.tr(vi: 'Thông tin hủy', en: 'Cancellation'),
          context.tr(vi: messageVi, en: messageEn),
        ),
      if (booking.cancelledAt != null)
        _buildInfoRow(
          context.tr(vi: 'Thời gian hủy', en: 'Cancelled at'),
          BookingUiHelper.formatDateTime(booking.cancelledAt!),
        ),
      if (paymentStatus == 'CANCELLED')
        _buildInfoRow(
          context.tr(vi: 'Hóa đơn', en: 'Invoice'),
          context.tr(vi: 'Đã hủy', en: 'Cancelled'),
          valueColor: Colors.grey.shade700,
        ),
      if (paymentStatus == 'REFUND_PENDING')
        _buildInfoRow(
          context.tr(vi: 'Hoàn tiền', en: 'Refund'),
          context.tr(vi: 'Đang chờ hoàn tiền', en: 'Refund pending'),
          valueColor: Colors.orange.shade800,
        ),
      if (paymentStatus == 'REFUNDED')
        _buildInfoRow(
          context.tr(vi: 'Hoàn tiền', en: 'Refund'),
          context.tr(vi: 'Đã hoàn tiền', en: 'Refunded'),
          valueColor: Colors.green.shade700,
        ),
      if (isFixedOccurrence)
        _buildInfoRow(
          context.tr(vi: 'Lịch cố định', en: 'Fixed schedule'),
          context.tr(vi: 'Vẫn tiếp tục hoạt động', en: 'Remains active'),
          valueColor: Colors.green.shade700,
        ),
    ]);
  }

  bool _canShowRescheduleAction(BookingDetailEntity booking) {
    final status = booking.status;
    if (status != 'PENDING' && status != 'CONFIRMED') return false;
    if (booking.courtId == null) return false;
    if (booking.isFixedSchedule == true || booking.fixedScheduleId != null) {
      return false;
    }
    if (booking.matchingSessionId != null || booking.isMatching == true) {
      return false;
    }
    if (BookingUiHelper.hasStarted(booking) == true) return false;
    if (status == 'CONFIRMED' &&
        BookingUiHelper.isWithinTwoHoursBeforeStart(booking) == true) {
      return false;
    }
    return true;
  }

  Widget _buildRescheduleBookingButton(BookingDetailEntity booking) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showRescheduleDialog(booking),
        icon: const Icon(Icons.event_repeat_outlined),
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          side: const BorderSide(color: _primaryColor),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        label: Text(
          context.tr(vi: 'Đổi lịch', en: 'Reschedule'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Future<void> _showRescheduleDialog(BookingDetailEntity booking) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _CustomerRescheduleDialog(booking: booking),
    );
    if (changed == true && mounted) {
      await _cubit.loadBookingDetail(booking.id);
    }
  }

  Widget _buildCancelBookingPanel(
    BookingDetailEntity booking,
    bool isCancelling,
  ) {
    final isFixedOccurrence =
        booking.isFixedSchedule == true && booking.fixedScheduleId != null;
    final withinTwoHours = BookingUiHelper.isWithinTwoHoursBeforeStart(booking);
    final hasStarted = BookingUiHelper.hasStarted(booking);
    final isConfirmedStarted =
        booking.status == 'CONFIRMED' && hasStarted == true;
    final isConfirmedTooClose =
        booking.status == 'CONFIRMED' && withinTwoHours == true;
    final isCancelBlocked = isConfirmedStarted || isConfirmedTooClose;
    final helperText = _cancelHelperText(
      booking,
      isConfirmedStarted,
      isConfirmedTooClose,
    );
    final buttonText = isCancelBlocked
        ? context.tr(vi: 'Không thể hủy', en: 'Cannot cancel')
        : isFixedOccurrence
        ? context.tr(vi: 'Hủy buổi này', en: 'Cancel this occurrence')
        : context.tr(vi: 'Hủy đặt sân', en: 'Cancel booking');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isCancelling || isCancelBlocked
                ? null
                : () => _confirmCancelBooking(booking),
            icon: isCancelling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel_outlined),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              disabledForegroundColor: Colors.grey,
              side: BorderSide(
                color: isCancelBlocked ? Colors.grey : Colors.red,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            label: Text(
              isCancelling
                  ? context.tr(vi: 'Đang hủy...', en: 'Cancelling...')
                  : buttonText,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        if (isFixedOccurrence) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: isCancelling || _isCancellingFixedSchedule
                  ? null
                  : () => _confirmCancelEntireFixedSchedule(booking),
              icon: _isCancellingFixedSchedule
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_busy_outlined),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                disabledForegroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              label: Text(
                _isCancellingFixedSchedule
                    ? context.tr(vi: 'Đang hủy...', en: 'Cancelling...')
                    : context.tr(
                        vi: 'Hủy toàn bộ lịch cố định',
                        en: 'Cancel entire fixed schedule',
                      ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        if (helperText != null) ...[
          const SizedBox(height: 8),
          Text(
            helperText,
            style: TextStyle(
              color: isCancelBlocked
                  ? Colors.red
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.65),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  String? _cancelHelperText(
    BookingDetailEntity booking,
    bool isConfirmedStarted,
    bool isConfirmedTooClose,
  ) {
    if (booking.status == 'PENDING') {
      return context.tr(
        vi: 'Bạn có thể hủy khi đơn chưa được duyệt.',
        en: 'You can cancel while the booking is still awaiting approval.',
      );
    }

    if (isConfirmedStarted) {
      return context.tr(
        vi: 'Đơn đã đến giờ bắt đầu nên không thể hủy.',
        en: 'This booking has reached its start time and cannot be cancelled.',
      );
    }

    if (isConfirmedTooClose) {
      return context.tr(
        vi: 'Đơn đã được duyệt và còn dưới 2 tiếng trước giờ bắt đầu nên không thể hủy.',
        en: 'This approved booking starts in less than 2 hours and cannot be cancelled.',
      );
    }

    if (booking.status == 'CONFIRMED') {
      return context.tr(
        vi: 'Đơn đã được duyệt. Bạn chỉ có thể hủy trước giờ bắt đầu tối thiểu 2 tiếng.',
        en: 'This booking is approved. You can only cancel at least 2 hours before start time.',
      );
    }

    return null;
  }

  Future<void> _confirmCancelBooking(BookingDetailEntity booking) async {
    final isConfirmed = booking.status == 'CONFIRMED';
    final isFixedOccurrence =
        booking.isFixedSchedule == true && booking.fixedScheduleId != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isFixedOccurrence
              ? context.tr(
                  vi: 'Xác nhận hủy buổi này',
                  en: 'Cancel this occurrence',
                )
              : context.tr(
                  vi: 'Xác nhận hủy đặt sân',
                  en: 'Confirm cancellation',
                ),
        ),
        content: Text(
          isFixedOccurrence
              ? context.tr(
                  vi: 'Chỉ buổi này sẽ bị hủy. Lịch cố định vẫn tiếp tục hoạt động ở các ngày sau.',
                  en: 'Only this occurrence will be cancelled. The fixed schedule will remain active.',
                )
              : isConfirmed
              ? context.tr(
                  vi: 'Đơn đã được nhân viên duyệt. Bạn chỉ có thể hủy trước giờ bắt đầu tối thiểu 2 tiếng.',
                  en: 'This booking is approved. You can only cancel at least 2 hours before start time.',
                )
              : context.tr(
                  vi: 'Bạn có chắc muốn hủy đơn đặt sân này không?',
                  en: 'Are you sure you want to cancel this booking?',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr(vi: 'Không', en: 'No')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              isFixedOccurrence
                  ? context.tr(vi: 'Hủy buổi này', en: 'Cancel occurrence')
                  : context.tr(vi: 'Hủy đặt sân', en: 'Cancel booking'),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final message = await _cubit.cancelBooking(booking.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ??
              context.tr(
                vi: isFixedOccurrence
                    ? 'Đã hủy buổi này, lịch cố định vẫn tiếp tục.'
                    : 'Đã hủy đặt sân thành công.',
                en: isFixedOccurrence
                    ? 'This occurrence was cancelled. The fixed schedule remains active.'
                    : 'Booking cancelled successfully.',
              ),
        ),
        backgroundColor: message == null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _confirmCancelEntireFixedSchedule(
    BookingDetailEntity booking,
  ) async {
    final fixedScheduleId = booking.fixedScheduleId;
    if (fixedScheduleId == null || _isCancellingFixedSchedule) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr(
            vi: 'Hủy toàn bộ lịch cố định?',
            en: 'Cancel entire fixed schedule?',
          ),
        ),
        content: Text(
          context.tr(
            vi: 'Lịch cố định sẽ ngừng hoạt động và các buổi tương lai liên quan sẽ được xử lý theo chính sách hủy hiện tại.',
            en: 'The fixed schedule will stop and its future occurrences will be handled by the current cancellation policy.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr(vi: 'Không', en: 'No')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              context.tr(vi: 'Hủy toàn bộ lịch', en: 'Cancel entire schedule'),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancellingFixedSchedule = true);
    try {
      final response = await GetIt.I<CancelFixedScheduleUseCase>()(
        fixedScheduleId,
      );
      if (!mounted) return;

      if (response.success) {
        await _cubit.loadBookingDetail(booking.id);
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.success
                ? context.tr(
                    vi: 'Đã hủy toàn bộ lịch cố định.',
                    en: 'The fixed schedule was cancelled.',
                  )
                : response.message ??
                      context.tr(
                        vi: 'Không thể hủy lịch cố định.',
                        en: 'Unable to cancel the fixed schedule.',
                      ),
          ),
          backgroundColor: response.success ? Colors.green : Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCancellingFixedSchedule = false);
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerRescheduleDialog extends StatefulWidget {
  final BookingDetailEntity booking;

  const _CustomerRescheduleDialog({required this.booking});

  @override
  State<_CustomerRescheduleDialog> createState() =>
      _CustomerRescheduleDialogState();
}

class _CustomerRescheduleDialogState extends State<_CustomerRescheduleDialog> {
  DateTime _date = DateTime.now();
  int? _selectedSlotIndex;
  SlotConfigEntity? _slotConfig;
  Set<int> _bookedSlotIndices = {};
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final parsed = DateTime.tryParse(widget.booking.bookingDate ?? '');
    if (parsed != null) {
      _date = DateTime(parsed.year, parsed.month, parsed.day);
    }
    _loadSlots();
  }

  String _apiDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _isSlotTooSoon(SlotEntity slot) {
    final startAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
    ).add(Duration(minutes: slot.startMinutes));
    return !startAt.isAfter(DateTime.now().add(const Duration(minutes: 10)));
  }

  Future<void> _loadSlots() async {
    final courtId = widget.booking.courtId;
    if (courtId == null || !mounted) return;
    setState(() {
      _isLoadingSlots = true;
      _selectedSlotIndex = null;
      _slotConfig = null;
      _bookedSlotIndices.clear();
    });

    try {
      final formattedDate = _apiDate(_date);
      final slotRes = await GetIt.I<GetSlotConfigUseCase>()(
        courtId,
        bookingDate: formattedDate,
      );
      if (!mounted) return;

      if (!slotRes.success || slotRes.data == null) {
        setState(() => _slotConfig = null);
        return;
      }

      final config = slotRes.data!;
      final bookingsRes = await GetIt.I<GetBookingHistoryUseCase>()();
      if (!mounted) return;

      final booked = <int>{};
      if (bookingsRes.success && bookingsRes.data != null) {
        final courtBookings = bookingsRes.data!.where(
          (booking) =>
              booking.id != widget.booking.id &&
              booking.courtId == courtId &&
              booking.bookingDate == formattedDate &&
              booking.status != 'CANCELLED',
        );
        for (final booking in courtBookings) {
          final bookedStart = booking.startMinutes;
          final bookedEnd = booking.endMinutes;
          if (bookedStart == null || bookedEnd == null) continue;
          for (var i = 0; i < config.slots.length; i++) {
            final slot = config.slots[i];
            if (slot.startMinutes < bookedEnd &&
                slot.endMinutes > bookedStart) {
              booked.add(i);
            }
          }
        }
      }

      setState(() {
        _slotConfig = config;
        _bookedSlotIndices = booked;
      });
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _submit() async {
    final courtId = widget.booking.courtId;
    if (courtId == null || _selectedSlotIndex == null || _slotConfig == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final slot = _slotConfig!.slots[_selectedSlotIndex!];
      final response = await GetIt.I<UpdateBookingUseCase>()(
        widget.booking.id,
        courtId: courtId,
        bookingDate: _apiDate(_date),
        startMinutes: slot.startMinutes,
        endMinutes: slot.endMinutes,
      );

      if (!mounted) return;
      if (response.success) {
        try {
          GetIt.I<AppNotificationEventBus>().emit(
            const AppNotificationEvent(
              type: AppNotificationEventType.bookingRescheduled,
            ),
          );
        } catch (error) {
          debugPrint('Error emitting booking rescheduled event: $error');
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                vi: 'Đổi lịch đặt sân thành công.',
                en: 'Booking rescheduled successfully.',
              ),
            ),
            backgroundColor: Colors.green,
          ),
        );
        navigator.pop(true);
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              response.message ??
                  context.tr(
                    vi: 'Không thể đổi lịch đặt sân.',
                    en: 'Unable to reschedule booking.',
                  ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(context.tr(vi: 'Lỗi: $error', en: 'Error: $error')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(context.tr(vi: 'Đổi lịch đặt sân', en: 'Reschedule booking')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${context.tr(vi: 'Sân', en: 'Court')}: ${widget.booking.courtName ?? context.tr(vi: 'Sân đấu', en: 'Court')}',
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(vi: 'Chọn ngày mới', en: 'Select new date'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _isSubmitting
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _date.isBefore(
                              DateTime(now.year, now.month, now.day),
                            )
                            ? now
                            : _date,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: now.add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() {
                          _date = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                          );
                        });
                        _loadSlots();
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateDisplayFormatter.date(_date)),
                    const Icon(Icons.calendar_month, color: Color(0xFFFF5600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr(vi: 'Chọn khung giờ mới', en: 'Select new time slot'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            if (_isLoadingSlots)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF5600)),
              )
            else if (_slotConfig == null || _slotConfig!.slots.isEmpty)
              Text(
                context.tr(
                  vi: 'Không tìm thấy khung giờ hoạt động.',
                  en: 'No active time slots found.',
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_slotConfig!.slots.length, (index) {
                  final slot = _slotConfig!.slots[index];
                  final isBooked = _bookedSlotIndices.contains(index);
                  final isBlocked = !slot.isAvailable;
                  final isTooSoon = _isSlotTooSoon(slot);
                  final isDisabled = isBooked || isBlocked || isTooSoon;
                  final isSelected = _selectedSlotIndex == index;

                  Color color = theme.colorScheme.surfaceContainerHighest;
                  Color textColor = theme.colorScheme.onSurface;
                  Color borderColor = Colors.grey.shade300;
                  if (isDisabled) {
                    color = Colors.grey.shade100;
                    textColor = Colors.grey.shade500;
                  } else if (isSelected) {
                    color = const Color(0xFFFF5600);
                    textColor = Colors.white;
                    borderColor = const Color(0xFFFF5600);
                  }

                  return Tooltip(
                    message: isBooked
                        ? context.tr(vi: 'Đã có lịch đặt', en: 'Booked')
                        : isBlocked
                        ? context.tr(
                            vi: 'Sân không khả dụng',
                            en: 'Unavailable',
                          )
                        : isTooSoon
                        ? context.tr(
                            vi: 'Quá sát giờ bắt đầu',
                            en: 'Too close to start time',
                          )
                        : '',
                    child: GestureDetector(
                      onTap: isDisabled || _isSubmitting
                          ? null
                          : () => setState(() => _selectedSlotIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          '${slot.startLabel}-${slot.endLabel}',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: Text(context.tr(vi: 'Hủy', en: 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _selectedSlotIndex == null || _isSubmitting
              ? null
              : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5600),
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(context.tr(vi: 'Đổi lịch', en: 'Reschedule')),
        ),
      ],
    );
  }
}
