import 'package:dio/dio.dart';
import 'package:server_module/server_module.dart';

/// ZaloPayService – giao tiếp qua backend thay vì gọi trực tiếp tới ZaloPay.
///
/// Lợi ích:
/// - key1/key2 được bảo vệ trên server, không lộ trong APK
/// - HMAC-SHA256 được ký server-side
/// - JWT tự động được thêm qua DioClient
class ZaloPayService {
  final DioClient _dioClient;

  ZaloPayService(this._dioClient);

  /// Tạo đơn hàng ZaloPay qua backend.
  ///
  /// [paymentId]   MongoDB Payment._id
  ///
  /// Trả về Map chứa:
  ///   - 'order_url'    → URL để mở ZaloPay app/web
  ///   - 'app_trans_id' → ID giao dịch để polling sau này
  ///   - 'qr_code'      → QR string (có thể null)
  ///
  /// Trả về null nếu tạo đơn thất bại.
  Future<Map<String, dynamic>?> createOrder({
    required String paymentId,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/zalopay/create-order',
        data: {'paymentId': paymentId},
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;

      if (data['success'] == true) {
        return {
          'order_url':      data['order_url'],
          'deeplink_url':   data['deeplink_url'],     // deeplink zalopay:// cho app
          'zp_trans_token': data['zp_trans_token'],   // token mở ZaloPay app
          'app_trans_id':   data['app_trans_id'],
          'qr_code':        data['qr_code'],
        };
      }

      // ignore: avoid_print
      print('[ZaloPayService] createOrder failed: ${data['message']}');
      return null;
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ZaloPayService] createOrder DioError: ${e.response?.data ?? e.message}');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[ZaloPayService] createOrder error: $e');
      return null;
    }
  }

  /// Truy vấn trạng thái đơn hàng ZaloPay qua backend (polling).
  ///
  /// [appTransId]  app_trans_id nhận được từ createOrder
  /// [paymentId]   MongoDB Payment._id (tuỳ chọn) — nếu truyền vào,
  ///               backend sẽ tự động cập nhật payment thành SUCCESS khi đã thanh toán.
  ///
  /// Trả về true nếu giao dịch đã thanh toán thành công.
  Future<bool> checkOrderStatus(
    String appTransId, {
    String? paymentId,
  }) async {
    try {
      final body = <String, dynamic>{'app_trans_id': appTransId};
      if (paymentId != null) body['payment_id'] = paymentId;

      final response = await _dioClient.dio.post(
        '/zalopay/query',
        data: body,
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) return false;

      // ignore: avoid_print
      print('[ZaloPayService] queryOrder: is_paid=${data['is_paid']}, return_code=${data['return_code']}');
      return data['is_paid'] == true;
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[ZaloPayService] checkOrderStatus DioError: ${e.response?.data ?? e.message}');
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('[ZaloPayService] checkOrderStatus error: $e');
      return false;
    }
  }
}
