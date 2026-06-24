import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/payment_detail_entity.dart';
import '../../domain/usecases/get_payments_usecase.dart';
import '../../domain/usecases/create_payment_usecase.dart';
import '../../domain/usecases/update_payment_status_usecase.dart';
import 'package:get_it/get_it.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:notification_module/notification_module.dart';

abstract class PaymentState extends Equatable {
  const PaymentState();

  @override
  List<Object?> get props => [];
}

class PaymentInitial extends PaymentState {}

class PaymentLoading extends PaymentState {}

class PaymentLoaded extends PaymentState {
  final List<PaymentDetailEntity> pendingPayments;
  final List<PaymentDetailEntity> completedPayments;

  const PaymentLoaded({
    required this.pendingPayments,
    required this.completedPayments,
  });

  @override
  List<Object?> get props => [pendingPayments, completedPayments];
}

class PaymentError extends PaymentState {
  final String message;

  const PaymentError(this.message);

  @override
  List<Object?> get props => [message];
}

class PaymentProcessing extends PaymentState {}

class PaymentSuccess extends PaymentState {
  final PaymentDetailEntity payment;

  const PaymentSuccess(this.payment);

  @override
  List<Object?> get props => [payment];
}

class PaymentCubit extends Cubit<PaymentState> {
  final GetPaymentsUseCase _getPaymentsUseCase;
  final CreatePaymentUseCase _createPaymentUseCase;
  final UpdatePaymentStatusUseCase _updatePaymentStatusUseCase;

  PaymentCubit(
    this._getPaymentsUseCase,
    this._createPaymentUseCase,
    this._updatePaymentStatusUseCase,
  ) : super(PaymentInitial());

  Future<void> loadPayments() async {
    emit(PaymentLoading());
    try {
      final response = await _getPaymentsUseCase();
      if (response.success && response.data != null) {
        final visiblePayments = response.data!
            .where(
              (payment) =>
                  payment.status != 'CANCELLED' &&
                  payment.booking?.status != 'CANCELLED',
            )
            .toList();
        final pending = visiblePayments
            .where((p) => p.status == 'PENDING')
            .toList();
        final completed = visiblePayments
            .where((p) => p.status != 'PENDING')
            .toList();
        emit(
          PaymentLoaded(pendingPayments: pending, completedPayments: completed),
        );
      } else {
        emit(
          PaymentError(response.message ?? 'Không thể tải danh sách hóa đơn'),
        );
      }
    } catch (e) {
      emit(PaymentError('Lỗi kết nối: $e'));
    }
  }

  Future<void> payInvoice({
    required String bookingId,
    required double amount,
  }) async {
    emit(PaymentProcessing());
    try {
      // Giả lập transaction ID
      final txId = 'TXN_${DateTime.now().millisecondsSinceEpoch}';

      // 1. Tạo thanh toán mới với phương thức BANK_TRANSFER
      final response = await _createPaymentUseCase(
        bookingId: bookingId,
        amount: amount,
        method: 'BANK_TRANSFER',
        transactionId: txId,
      );

      if (response.success && response.data != null) {
        final payment = response.data!;

        // 2. Giả lập xác nhận thanh toán SUCCESS
        final updateResponse = await _updatePaymentStatusUseCase(
          payment.id,
          'SUCCESS',
        );
        if (updateResponse.success && updateResponse.data != null) {
          try {
            GetIt.I<AppNotificationEventBus>().emit(
              const AppNotificationEvent(
                type: AppNotificationEventType.paymentOnlineSuccess,
              ),
            );
          } catch (e) {
            // ignore
          }

          try {
            final userRes = await GetIt.I<GetLocalUserUseCase>()();
            final user = userRes.fold((_) => null, (u) => u);
            if (user != null && user.userId != null) {
              await GetIt.I<CreateNotificationUseCase>().call(
                userId: user.userId!,
                title: 'Thanh toán thành công',
                body:
                    'Hóa đơn thanh toán trị giá $amount đ của bạn đã được xác nhận thành công.',
                type: 'PAYMENT',
              );
              GetIt.I<NotificationCubit>().loadNotifications();
            }
          } catch (_) {}
          emit(PaymentSuccess(updateResponse.data!));
        } else {
          emit(
            PaymentError(
              updateResponse.message ?? 'Lỗi cập nhật trạng thái thanh toán',
            ),
          );
        }
      } else {
        emit(PaymentError(response.message ?? 'Lỗi tạo hóa đơn thanh toán'));
      }
    } catch (e) {
      emit(PaymentError('Lỗi thanh toán: $e'));
    }
  }
}
