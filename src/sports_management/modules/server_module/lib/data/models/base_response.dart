import 'package:equatable/equatable.dart';

class BaseResponse<T> extends Equatable {
  final bool success;
  final String? message;
  final String? code;
  final T? data;

  const BaseResponse({
    required this.success,
    this.message,
    this.code,
    this.data,
  });

  factory BaseResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    final result = json['result'] as Map<String, dynamic>? ?? json;

    return BaseResponse<T>(
      success: result['success'] as bool? ?? false,
      message: result['message'] as String?,
      code: result['code'] as String? ?? result['errorCode'] as String?,
      data: fromJsonT != null ? fromJsonT(json) : null,
    );
  }

  @override
  List<Object?> get props => [success, message, code, data];
}
