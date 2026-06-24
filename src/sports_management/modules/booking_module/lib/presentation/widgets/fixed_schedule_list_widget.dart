import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:server_module/server_module.dart';
import 'package:authentication_module/authentication_module.dart';
import '../cubit/fixed_schedule_cubit.dart';
import 'package:notification_module/notification_module.dart';
import '../../domain/usecases/cancel_fixed_matching_occurrence_usecase.dart';
import '../../domain/usecases/cancel_fixed_schedule_usecase.dart';
import '../../domain/usecases/join_fixed_matching_schedule_usecase.dart';
import '../../domain/usecases/leave_fixed_matching_schedule_usecase.dart';
import '../../domain/usecases/pause_fixed_schedule_usecase.dart';
import '../../domain/usecases/resume_fixed_schedule_usecase.dart';

class FixedScheduleListWidget extends StatefulWidget {
  final String? initialStatusFilter;
  final bool prioritizePendingApproval;

  const FixedScheduleListWidget({
    super.key,
    this.initialStatusFilter,
    this.prioritizePendingApproval = false,
  });

  @override
  State<FixedScheduleListWidget> createState() =>
      _FixedScheduleListWidgetState();
}

class _FixedScheduleListWidgetState extends State<FixedScheduleListWidget> {
  late FixedScheduleCubit _cubit;
  String _userRole = 'CUSTOMER';
  String? _currentUserId;
  String? _processingScheduleId;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _cubit = FixedScheduleCubit(GetIt.I(), GetIt.I(), GetIt.I(), GetIt.I());
    _statusFilter = widget.initialStatusFilter;
    _loadUserRole();
    _loadSchedules();
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
      (Match m) => '${m[1]}.',
    );
    return context.tr(vi: '$formatted đ/buổi', en: '$formatted VND/session');
  }

  String _formatTime(int? minutes) {
    if (minutes == null) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _loadSchedules() {
    return _cubit.loadFixedSchedules(status: _statusFilter);
  }

  String _getFrequencyText(BuildContext context, FixedScheduleEntity schedule) {
    if (schedule.frequency == 'DAILY') {
      return context.tr(vi: 'Hàng ngày', en: 'Daily');
    }
    final days = schedule.daysOfWeek ?? [];
    if (days.isEmpty) return context.tr(vi: 'Hàng tuần', en: 'Weekly');

    final dayLabels = days
        .map((d) {
          switch (d) {
            case 0:
              return context.tr(vi: 'Chủ Nhật', en: 'Sunday');
            case 1:
              return context.tr(vi: 'Thứ 2', en: 'Monday');
            case 2:
              return context.tr(vi: 'Thứ 3', en: 'Tuesday');
            case 3:
              return context.tr(vi: 'Thứ 4', en: 'Wednesday');
            case 4:
              return context.tr(vi: 'Thứ 5', en: 'Thursday');
            case 5:
              return context.tr(vi: 'Thứ 6', en: 'Friday');
            case 6:
              return context.tr(vi: 'Thứ 7', en: 'Saturday');
            default:
              return '';
          }
        })
        .join(', ');

    return '${context.tr(vi: 'Hàng tuần vào', en: 'Weekly on')} $dayLabels';
  }

  Future<void> _loadUserRole() async {
    try {
      final result = await GetIt.I<GetLocalUserUseCase>()();
      if (!mounted) return;
      result.fold((_) {}, (user) {
        setState(() {
          _userRole = user.role?.toUpperCase() ?? 'CUSTOMER';
          _currentUserId = user.userId;
        });
      });
    } catch (_) {
      // Keep customer-safe default.
    }
  }

  String _formatApiDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _buildCancellationSummaryText(
    BuildContext context,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null || summary.isEmpty) return '';
    final cancelledBookings =
        (summary['cancelledBookings'] as num?)?.toInt() ?? 0;
    final cancelledSessions =
        (summary['cancelledMatchingSessions'] as num?)?.toInt() ?? 0;
    final cancelledPayments =
        (summary['cancelledPendingPayments'] as num?)?.toInt() ?? 0;
    final successPayments = (summary['successPayments'] as num?)?.toInt() ?? 0;
    return context.tr(
      vi: 'Booking đã hủy: $cancelledBookings\nPhòng ghép đã hủy: $cancelledSessions\nPayment chờ đã hủy: $cancelledPayments\nPayment đã thanh toán cần xử lý thủ công: $successPayments',
      en: 'Cancelled bookings: $cancelledBookings\nCancelled sessions: $cancelledSessions\nCancelled pending payments: $cancelledPayments\nSuccessful payments requiring manual handling: $successPayments',
    );
  }

  void _showOperationResult(
    BaseResponse<FixedScheduleEntity> response, {
    required String successFallback,
    required String failureFallback,
  }) {
    final summaryText = _buildCancellationSummaryText(
      context,
      response.data?.cancellationSummary,
    );
    final message = [
      response.message ??
          (response.success ? successFallback : failureFallback),
      if (summaryText.isNotEmpty) summaryText,
    ].join('\n\n');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: response.success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _showCancelConfirmation(
    BuildContext context,
    FixedScheduleEntity schedule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr(
            vi: 'Hủy đăng ký lịch cố định',
            en: 'Cancel Fixed Schedule',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.tr(
            vi: 'Hủy cả chuỗi sẽ hủy các buổi tương lai còn PENDING. Các hóa đơn đã thanh toán sẽ cần xử lý thủ công.',
            en: 'Cancelling the series will cancel future pending occurrences. Paid invoices will require manual handling.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.tr(vi: 'Quay lại', en: 'Cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.tr(vi: 'Hủy cả chuỗi', en: 'Cancel Series'),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingScheduleId = schedule.id);
    final response = await GetIt.I<CancelFixedScheduleUseCase>()(schedule.id);
    if (!mounted) return;
    setState(() => _processingScheduleId = null);
    _showOperationResult(
      response,
      successFallback: this.context.tr(
        vi: 'Đã hủy lịch cố định',
        en: 'Fixed schedule cancelled',
      ),
      failureFallback: this.context.tr(
        vi: 'Không thể hủy lịch cố định',
        en: 'Unable to cancel fixed schedule',
      ),
    );
    if (response.success) _loadSchedules();
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'PENDING_APPROVAL':
        return Colors.orange;
      case 'ACTIVE':
        return Colors.green;
      case 'PAUSED':
        return Colors.blueGrey;
      case 'REJECTED':
        return Colors.redAccent;
      case 'CANCELLED':
        return Colors.red;
      case 'EXPIRED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(BuildContext context, String? status) {
    switch (status) {
      case 'PENDING_APPROVAL':
        return context.tr(vi: 'Chờ nhân viên duyệt', en: 'Pending approval');
      case 'ACTIVE':
        return context.tr(vi: 'Đang hoạt động', en: 'Active');
      case 'PAUSED':
        return context.tr(vi: 'Đã tạm dừng', en: 'Paused');
      case 'REJECTED':
        return context.tr(vi: 'Đã bị từ chối', en: 'Rejected');
      case 'CANCELLED':
        return context.tr(vi: 'Đã hủy', en: 'Cancelled');
      case 'EXPIRED':
        return context.tr(vi: 'Đã hết hạn', en: 'Expired');
      default:
        return status ?? context.tr(vi: 'Không xác định', en: 'Unknown');
    }
  }

  bool get _canReviewFixedSchedule =>
      _userRole == 'STAFF' || _userRole == 'ADMIN';

  String _getScheduleTypeText(
    BuildContext context,
    FixedScheduleEntity schedule,
  ) {
    if (schedule.type == 'MATCHING') {
      return context.tr(vi: 'Ghép trận cố định', en: 'Fixed matching');
    }
    return context.tr(vi: 'Đặt sân cố định', en: 'Fixed court booking');
  }

  String _getReadinessText(BuildContext context, String? readiness) {
    if (readiness == 'READY') {
      return context.tr(vi: 'Đã đủ đội', en: 'Ready');
    }
    return context.tr(vi: 'Đang tìm người/đội', en: 'Recruiting');
  }

  String _getPaymentPolicyText(BuildContext context, String? policy) {
    switch (policy) {
      case 'HOST_PAY_ALL':
        return context.tr(vi: 'Host trả hết', en: 'Host pays all');
      case 'TEAM_REPRESENTATIVES_SPLIT':
        return context.tr(
          vi: 'Đại diện hai đội chia đôi',
          en: 'Team representatives split',
        );
      case 'SPLIT_EQUALLY':
        return context.tr(
          vi: 'Chia đều theo tài khoản app',
          en: 'Split equally',
        );
      default:
        return policy ?? context.tr(vi: 'Chưa cấu hình', en: 'Not configured');
    }
  }

  String _getExceptionTypeText(BuildContext context, String? type) {
    switch (type) {
      case 'CANCELLED':
        return context.tr(vi: 'Đã hủy buổi này', en: 'Occurrence cancelled');
      case 'TEAM_UNAVAILABLE':
        return context.tr(vi: 'Đội bận', en: 'Team unavailable');
      default:
        return type ?? context.tr(vi: 'Ngoại lệ', en: 'Exception');
    }
  }

  bool _isCurrentUserHost(FixedScheduleEntity schedule) {
    return _currentUserId != null && schedule.user?.id == _currentUserId;
  }

  bool _isCurrentUserApprovedMember(FixedScheduleEntity schedule) {
    final config = schedule.fixedMatchingConfig;
    if (_currentUserId == null || config == null) return false;
    return config.members.any(
      (member) =>
          member.userId == _currentUserId && member.status == 'APPROVED',
    );
  }

  Future<void> _showJoinFixedMatchingDialog(
    FixedScheduleEntity schedule,
  ) async {
    String preferredTeam = 'AUTO';
    int memberCount = 1;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            context.tr(vi: 'Tham gia đội cố định', en: 'Join fixed team'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in ['A', 'B', 'AUTO'])
                    ChoiceChip(
                      label: Text(
                        option == 'AUTO'
                            ? context.tr(vi: 'Tự động', en: 'Auto')
                            : 'Team $option',
                      ),
                      selected: preferredTeam == option,
                      onSelected: (_) {
                        setDialogState(() => preferredTeam = option);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(vi: 'Số người bạn đại diện', en: 'Member count'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: memberCount > 1
                        ? () => setDialogState(() => memberCount--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: Text(
                      '$memberCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setDialogState(() => memberCount++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr(vi: 'Quay lại', en: 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'preferredTeam': preferredTeam,
                'memberCount': memberCount,
              }),
              child: Text(
                context.tr(vi: 'Tham gia đội cố định', en: 'Join fixed team'),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _processingScheduleId = schedule.id);
    final response = await GetIt.I<JoinFixedMatchingScheduleUseCase>()(
      schedule.id,
      preferredTeam: result['preferredTeam'] as String,
      memberCount: result['memberCount'] as int,
    );
    if (!mounted) return;
    setState(() => _processingScheduleId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.message ??
              (response.success
                  ? context.tr(
                      vi: 'Đã tham gia lịch ghép cố định',
                      en: 'Joined fixed matching schedule',
                    )
                  : context.tr(
                      vi: 'Không thể tham gia lịch ghép cố định',
                      en: 'Unable to join fixed matching schedule',
                    )),
        ),
        backgroundColor: response.success ? Colors.green : Colors.red,
      ),
    );
    if (response.success) _loadSchedules();
  }

  Future<void> _confirmLeaveFixedMatching(FixedScheduleEntity schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr(vi: 'Rời lịch ghép cố định', en: 'Leave fixed matching'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.tr(
            vi: 'Bạn chắc chắn muốn rời khỏi lịch ghép cố định này?',
            en: 'Are you sure you want to leave this fixed matching schedule?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr(vi: 'Quay lại', en: 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.tr(vi: 'Rời lịch', en: 'Leave'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingScheduleId = schedule.id);
    final response = await GetIt.I<LeaveFixedMatchingScheduleUseCase>()(
      schedule.id,
    );
    if (!mounted) return;
    setState(() => _processingScheduleId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.message ??
              (response.success
                  ? context.tr(
                      vi: 'Đã rời lịch ghép cố định',
                      en: 'Left fixed matching schedule',
                    )
                  : context.tr(
                      vi: 'Không thể rời lịch ghép cố định',
                      en: 'Unable to leave fixed matching schedule',
                    )),
        ),
        backgroundColor: response.success ? Colors.green : Colors.red,
      ),
    );
    if (response.success) _loadSchedules();
  }

  Widget _buildStatusFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(context.tr(vi: 'Tất cả', en: 'All')),
            selected: _statusFilter == null,
            onSelected: (_) {
              setState(() => _statusFilter = null);
              _loadSchedules();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr(vi: 'Chờ duyệt', en: 'Pending')),
            selected: _statusFilter == 'PENDING_APPROVAL',
            onSelected: (_) {
              setState(() => _statusFilter = 'PENDING_APPROVAL');
              _loadSchedules();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _approveSchedule(FixedScheduleEntity schedule) async {
    setState(() => _processingScheduleId = schedule.id);
    final message = await _cubit.approveFixedSchedule(schedule.id);
    if (!mounted) return;
    setState(() => _processingScheduleId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ??
              context.tr(
                vi: 'Đã duyệt lịch cố định',
                en: 'Fixed schedule approved',
              ),
        ),
        backgroundColor: message == null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _showRejectDialog(FixedScheduleEntity schedule) async {
    final controller = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr(vi: 'Từ chối lịch cố định', en: 'Reject fixed schedule'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: context.tr(
              vi: 'Lý do từ chối (tùy chọn)',
              en: 'Rejection reason (optional)',
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr(vi: 'Quay lại', en: 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(
              context.tr(vi: 'Từ chối', en: 'Reject'),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;

    setState(() => _processingScheduleId = schedule.id);
    final message = await _cubit.rejectFixedSchedule(
      schedule.id,
      reason: reason.trim().isEmpty ? null : reason.trim(),
    );
    if (!mounted) return;
    setState(() => _processingScheduleId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ??
              context.tr(
                vi: 'Đã từ chối lịch cố định',
                en: 'Fixed schedule rejected',
              ),
        ),
        backgroundColor: message == null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _confirmPauseFixedSchedule(FixedScheduleEntity schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr(vi: 'Tạm dừng lịch cố định', en: 'Pause fixed schedule'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.tr(
            vi: 'Lịch sẽ không tự sinh thêm buổi mới trong thời gian tạm dừng. Các buổi đã sinh trước đó không tự bị hủy.',
            en: 'No new occurrences will be generated while paused. Existing generated occurrences are not automatically cancelled.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr(vi: 'Quay lại', en: 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr(vi: 'Tạm dừng', en: 'Pause')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingScheduleId = schedule.id);
    final response = await GetIt.I<PauseFixedScheduleUseCase>()(schedule.id);
    if (!mounted) return;
    setState(() => _processingScheduleId = null);
    _showOperationResult(
      response,
      successFallback: context.tr(
        vi: 'Đã tạm dừng lịch cố định',
        en: 'Fixed schedule paused',
      ),
      failureFallback: context.tr(
        vi: 'Không thể tạm dừng lịch cố định',
        en: 'Unable to pause fixed schedule',
      ),
    );
    if (response.success) _loadSchedules();
  }

  Future<void> _confirmResumeFixedSchedule(FixedScheduleEntity schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr(vi: 'Tiếp tục lịch cố định', en: 'Resume fixed schedule'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.tr(
            vi: 'Hệ thống sẽ tiếp tục sinh các buổi mới nếu lịch đủ điều kiện.',
            en: 'The system will continue generating new occurrences when the schedule is eligible.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr(vi: 'Quay lại', en: 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr(vi: 'Tiếp tục', en: 'Resume')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingScheduleId = schedule.id);
    final response = await GetIt.I<ResumeFixedScheduleUseCase>()(schedule.id);
    if (!mounted) return;
    setState(() => _processingScheduleId = null);
    _showOperationResult(
      response,
      successFallback: context.tr(
        vi: 'Đã tiếp tục lịch cố định',
        en: 'Fixed schedule resumed',
      ),
      failureFallback: context.tr(
        vi: 'Không thể tiếp tục lịch cố định',
        en: 'Unable to resume fixed schedule',
      ),
    );
    if (response.success) _loadSchedules();
  }

  Future<void> _showCancelOccurrenceDialog(FixedScheduleEntity schedule) async {
    DateTime selectedDate = DateTime.now();
    final reasonController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            context.tr(vi: 'Hủy một buổi', en: 'Cancel one occurrence'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _formatApiDate(selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: context.tr(
                    vi: 'Lý do hủy (tùy chọn)',
                    en: 'Reason (optional)',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr(vi: 'Quay lại', en: 'Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'date': _formatApiDate(selectedDate),
                'reason': reasonController.text.trim(),
              }),
              child: Text(
                context.tr(vi: 'Hủy buổi này', en: 'Cancel occurrence'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
    if (result == null || !mounted) return;

    setState(() => _processingScheduleId = schedule.id);
    final response = await GetIt.I<CancelFixedMatchingOccurrenceUseCase>()(
      schedule.id,
      date: result['date']!,
      reason: result['reason']?.isEmpty == true ? null : result['reason'],
    );
    if (!mounted) return;
    setState(() => _processingScheduleId = null);
    _showOperationResult(
      response,
      successFallback: context.tr(
        vi: 'Đã hủy buổi ghép cố định',
        en: 'Fixed matching occurrence cancelled',
      ),
      failureFallback: context.tr(
        vi: 'Không thể hủy buổi ghép cố định',
        en: 'Unable to cancel occurrence',
      ),
    );
    if (response.success) _loadSchedules();
  }

  Widget _buildFixedMatchingDetail(
    BuildContext context,
    FixedScheduleEntity schedule,
  ) {
    final config = schedule.fixedMatchingConfig!;
    final isHost = _isCurrentUserHost(schedule);
    final isApprovedMember = _isCurrentUserApprovedMember(schedule);
    final canJoin =
        schedule.status == 'ACTIVE' &&
        config.readiness != 'READY' &&
        !isHost &&
        !isApprovedMember;
    final canLeave = schedule.status == 'ACTIVE' && isApprovedMember;
    final isProcessing = _processingScheduleId == schedule.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                config.readiness == 'READY'
                    ? Icons.check_circle_outline
                    : Icons.groups_2_outlined,
                size: 18,
                color: config.readiness == 'READY'
                    ? Colors.green
                    : const Color(0xFFFF5600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getReadinessText(context, config.readiness),
                  style: TextStyle(
                    color: config.readiness == 'READY'
                        ? Colors.green
                        : const Color(0xFFFF5600),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${context.tr(vi: 'Thanh toán: ', en: 'Payment: ')}${_getPaymentPolicyText(context, config.paymentPolicy)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTeamColumn(
                  context,
                  title: 'Team A',
                  occupancy: config.teamAOccupancy,
                  maxPlayers: config.teamSize,
                  members: config.members
                      .where(
                        (member) =>
                            member.teamCode == 'A' &&
                            member.status == 'APPROVED',
                      )
                      .toList(),
                  hostLabel: config.hostTeamCode == 'A'
                      ? context.tr(vi: 'Host', en: 'Host')
                      : null,
                  hostRepresentedCount: config.hostTeamCode == 'A'
                      ? config.hostRepresentedCount
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTeamColumn(
                  context,
                  title: 'Team B',
                  occupancy: config.teamBOccupancy,
                  maxPlayers: config.teamSize,
                  members: config.members
                      .where(
                        (member) =>
                            member.teamCode == 'B' &&
                            member.status == 'APPROVED',
                      )
                      .toList(),
                  hostLabel: config.hostTeamCode == 'B'
                      ? context.tr(vi: 'Host', en: 'Host')
                      : null,
                  hostRepresentedCount: config.hostTeamCode == 'B'
                      ? config.hostRepresentedCount
                      : null,
                ),
              ),
            ],
          ),
          if (isHost) ...[
            const SizedBox(height: 10),
            Text(
              context.tr(
                vi: 'Chủ lịch không thể rời, hãy hủy hoặc tạm dừng lịch.',
                en: 'The host cannot leave. Cancel or pause the schedule instead.',
              ),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          if (canJoin || canLeave) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: canJoin
                  ? ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => _showJoinFixedMatchingDialog(schedule),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5600),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      icon: isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.group_add_outlined, size: 18),
                      label: Text(
                        context.tr(
                          vi: 'Tham gia đội cố định',
                          en: 'Join fixed team',
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => _confirmLeaveFixedMatching(schedule),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: Text(
                        context.tr(
                          vi: 'Rời lịch ghép cố định',
                          en: 'Leave fixed matching',
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExceptionDates(
    BuildContext context,
    FixedScheduleEntity schedule,
  ) {
    final exceptions = schedule.exceptionDates ?? const [];
    if (exceptions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_busy_outlined,
                size: 16,
                color: Colors.amber.shade800,
              ),
              const SizedBox(width: 6),
              Text(
                context.tr(vi: 'Ngày ngoại lệ', en: 'Exception dates'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...exceptions.map((exception) {
            final date = exception['date']?.toString() ?? '';
            final type = exception['type']?.toString();
            final reason = exception['reason']?.toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                [
                  DateDisplayFormatter.fromApiDate(date),
                  _getExceptionTypeText(context, type),
                  if (reason != null && reason.trim().isNotEmpty) reason,
                ].join(' - '),
                style: const TextStyle(fontSize: 12),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color foregroundColor,
    required Color backgroundColor,
    required bool isProcessing,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: isProcessing ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: isProcessing
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foregroundColor,
              ),
            )
          : Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTeamColumn(
    BuildContext context, {
    required String title,
    required int occupancy,
    required int maxPlayers,
    required List<FixedMatchingMemberEntity> members,
    String? hostLabel,
    int? hostRepresentedCount,
  }) {
    final rows = <Widget>[];
    if (hostLabel != null) {
      rows.add(
        Text(
          hostRepresentedCount != null && hostRepresentedCount > 1
              ? '$hostLabel ($hostRepresentedCount)'
              : hostLabel,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
    rows.addAll(
      members.map((member) {
        final displayName = member.name?.trim().isNotEmpty == true
            ? member.name!
            : member.email?.trim().isNotEmpty == true
            ? member.email!
            : member.userId;
        return Text(
          member.representedCount > 1
              ? '$displayName (${member.representedCount})'
              : displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        );
      }),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title: $occupancy/$maxPlayers',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (rows.isEmpty)
          Text(
            context.tr(vi: 'Chưa có thành viên', en: 'No members yet'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          )
        else
          ...rows,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FixedScheduleCubit, FixedScheduleState>(
      bloc: _cubit,
      builder: (context, state) {
        if (state is FixedScheduleLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF5600)),
          );
        }

        if (state is FixedScheduleError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.message),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadSchedules,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5600),
                  ),
                  child: Text(context.tr(vi: 'Thử lại', en: 'Retry')),
                ),
              ],
            ),
          );
        }

        if (state is FixedScheduleLoaded) {
          final items = List<FixedScheduleEntity>.of(state.schedules);
          if (widget.prioritizePendingApproval) {
            items.sort((a, b) {
              final aPriority = a.status == 'PENDING_APPROVAL' ? 0 : 1;
              final bPriority = b.status == 'PENDING_APPROVAL' ? 0 : 1;
              return aPriority.compareTo(bPriority);
            });
          }
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_canReviewFixedSchedule) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildStatusFilters(context),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr(
                      vi: 'Chưa có lịch cố định nào',
                      en: 'No fixed schedules registered',
                    ),
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadSchedules,
            color: const Color(0xFFFF5600),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + (_canReviewFixedSchedule ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (_canReviewFixedSchedule && index == 0) {
                  return _buildStatusFilters(context);
                }

                final scheduleIndex = index - (_canReviewFixedSchedule ? 1 : 0);
                final schedule = items[scheduleIndex];
                final statusColor = _getStatusColor(schedule.status);
                final statusText = _getStatusText(context, schedule.status);
                final isHost = _isCurrentUserHost(schedule);
                final canManageSchedule = _canReviewFixedSchedule || isHost;
                final canCancel =
                    canManageSchedule &&
                    (schedule.status == 'PENDING_APPROVAL' ||
                        schedule.status == 'ACTIVE' ||
                        schedule.status == 'PAUSED');
                final canPause =
                    canManageSchedule && schedule.status == 'ACTIVE';
                final canResume =
                    canManageSchedule && schedule.status == 'PAUSED';
                final canCancelOccurrence =
                    canManageSchedule &&
                    schedule.type == 'MATCHING' &&
                    schedule.status == 'ACTIVE';
                final isPendingApproval = schedule.status == 'PENDING_APPROVAL';
                final isProcessing = _processingScheduleId == schedule.id;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
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
                                '${schedule.sport?.name ?? ""} - ${schedule.court?.name ?? context.tr(vi: 'Sân đấu', en: 'Court')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF5600,
                            ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getScheduleTypeText(context, schedule),
                            style: const TextStyle(
                              color: Color(0xFFFF5600),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (schedule.facility != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${schedule.facility!.name} - ${schedule.facility!.address ?? ''}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${context.tr(vi: 'Giờ chơi: ', en: 'Play time: ')}${_formatTime(schedule.startMinutes)} - ${_formatTime(schedule.endMinutes)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.repeat,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${context.tr(vi: 'Tần suất: ', en: 'Frequency: ')}${_getFrequencyText(context, schedule)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.date_range,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${context.tr(vi: 'Ngày hiệu lực: ', en: 'Validity date: ')}${DateDisplayFormatter.fromApiDate(schedule.startDate)} ${context.tr(vi: 'đến', en: 'to')} ${schedule.endDate != null ? DateDisplayFormatter.fromApiDate(schedule.endDate) : context.tr(vi: 'Vô hạn', en: 'Infinite')}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (schedule.type == 'MATCHING' &&
                            schedule.fixedMatchingConfig != null) ...[
                          const SizedBox(height: 14),
                          _buildFixedMatchingDetail(context, schedule),
                        ],
                        if ((schedule.exceptionDates ?? const [])
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildExceptionDates(context, schedule),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          _formatPrice(
                            context,
                            schedule.pricePerHour?.toDouble() ?? 0.0,
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF5600),
                          ),
                        ),
                        if (canPause ||
                            canResume ||
                            canCancel ||
                            canCancelOccurrence) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (canPause)
                                _buildActionButton(
                                  label: context.tr(
                                    vi: 'Tạm dừng',
                                    en: 'Pause',
                                  ),
                                  icon: Icons.pause_circle_outline,
                                  foregroundColor: Colors.blueGrey,
                                  backgroundColor: Colors.blueGrey.shade50,
                                  isProcessing: isProcessing,
                                  onPressed: () =>
                                      _confirmPauseFixedSchedule(schedule),
                                ),
                              if (canResume)
                                _buildActionButton(
                                  label: context.tr(
                                    vi: 'Tiếp tục',
                                    en: 'Resume',
                                  ),
                                  icon: Icons.play_circle_outline,
                                  foregroundColor: Colors.green,
                                  backgroundColor: Colors.green.shade50,
                                  isProcessing: isProcessing,
                                  onPressed: () =>
                                      _confirmResumeFixedSchedule(schedule),
                                ),
                              if (canCancelOccurrence)
                                _buildActionButton(
                                  label: context.tr(
                                    vi: 'Hủy một buổi',
                                    en: 'Cancel occurrence',
                                  ),
                                  icon: Icons.event_busy_outlined,
                                  foregroundColor: Colors.deepOrange,
                                  backgroundColor: Colors.orange.shade50,
                                  isProcessing: isProcessing,
                                  onPressed: () =>
                                      _showCancelOccurrenceDialog(schedule),
                                ),
                              if (canCancel)
                                _buildActionButton(
                                  label: context.tr(
                                    vi: 'Hủy cả chuỗi',
                                    en: 'Cancel series',
                                  ),
                                  icon: Icons.cancel_outlined,
                                  foregroundColor: Colors.red,
                                  backgroundColor: Colors.red.shade50,
                                  isProcessing: isProcessing,
                                  onPressed: () => _showCancelConfirmation(
                                    context,
                                    schedule,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (_canReviewFixedSchedule && isPendingApproval) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isProcessing
                                      ? null
                                      : () => _showRejectDialog(schedule),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: BorderSide(
                                      color: Colors.red.shade200,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: isProcessing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.close, size: 16),
                                  label: Text(
                                    context.tr(vi: 'Từ chối', en: 'Reject'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isProcessing
                                      ? null
                                      : () => _approveSchedule(schedule),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: isProcessing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check, size: 16),
                                  label: Text(
                                    context.tr(vi: 'Duyệt', en: 'Approve'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
