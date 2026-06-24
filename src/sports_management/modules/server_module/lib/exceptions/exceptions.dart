import 'dart:async';
import 'package:dio/dio.dart';
import 'package:server_module/data/models/base_response.dart';

class ExceptionHandler {
  static BaseResponse<T> handle<T>(dynamic error) {
    if (error is TimeoutException) {
      return BaseResponse<T>(success: false, message: 'Request timeout');
    }

    if (error is DioException) {
      if (error.response?.data != null &&
          error.response?.data is Map<String, dynamic>) {
        final data = error.response!.data as Map<String, dynamic>;
        return BaseResponse<T>(
          success: false,
          message: data['message'] ?? 'Network error',
          code: data['code'] ?? data['errorCode'],
        );
      }
      return BaseResponse<T>(
        success: false,
        message: error.message ?? 'Network error',
      );
    }

    return BaseResponse<T>(success: false, message: error.toString());
  }
}
