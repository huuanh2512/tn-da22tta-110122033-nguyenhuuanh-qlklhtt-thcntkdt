import 'package:equatable/equatable.dart';

class PaymentModel extends Equatable {
  final String id;
  final String? bookingId;
  final double? amount;
  final String? method;
  final String? status;

  const PaymentModel({
    required this.id,
    this.bookingId,
    this.amount,
    this.method,
    this.status,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] ?? json['_id'] ?? '',
      bookingId: json['bookingId'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      method: json['method'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'amount': amount,
      'method': method,
      'status': status,
    };
  }

  @override
  List<Object?> get props => [id, bookingId, amount, method, status];
}