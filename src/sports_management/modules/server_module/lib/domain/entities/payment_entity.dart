import 'package:equatable/equatable.dart';

class PaymentEntity extends Equatable {
  final String id;
  final String? bookingId;
  final double? amount;
  final String? method;
  final String? status;

  const PaymentEntity({
    required this.id,
    this.bookingId,
    this.amount,
    this.method,
    this.status,
  });

  @override
  List<Object?> get props => [id, bookingId, amount, method, status];
}