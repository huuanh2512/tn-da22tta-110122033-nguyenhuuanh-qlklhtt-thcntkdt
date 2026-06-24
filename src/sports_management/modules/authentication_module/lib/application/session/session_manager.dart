import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../firebase_email_auth_flow.dart';
import '../../data/datasources/local/authentication_local_data_source.dart';
import '../../domain/usecases/clear_local_session_usecase.dart';

/// Callback được gọi khi phiên đăng nhập hết hạn hoàn toàn.
typedef SessionExpiredCallback = void Function();

/// [SessionManager] quản lý toàn bộ vòng đời của session:
/// - Kiểm tra token định kỳ (mỗi 5 phút)
/// - Tự động refresh token khi còn < 60 phút hết hạn
/// - Gọi [onSessionExpired] khi refresh thất bại (token 7 ngày hết hạn)
class SessionManager {
  SessionManager({
    required AuthenticationLocalDataSource localDataSource,
    required ClearLocalSessionUseCase clearLocalSessionUseCase,
    // ignore: prefer_initializing_formals
  }) : _localDataSource = localDataSource,
       // ignore: prefer_initializing_formals
       _clearLocalSessionUseCase = clearLocalSessionUseCase;

  final AuthenticationLocalDataSource _localDataSource;
  final ClearLocalSessionUseCase _clearLocalSessionUseCase;

  Timer? _timer;
  bool _isRefreshing = false;

  /// Callback được gọi khi token hết hạn hoàn toàn, không thể refresh.
  SessionExpiredCallback? onSessionExpired;

  /// Khoảng thời gian còn lại tối thiểu trước khi tự động refresh (60 phút).
  static const Duration _refreshThreshold = Duration(minutes: 60);

  /// Chu kỳ kiểm tra token (mỗi 5 phút).
  static const Duration _checkInterval = Duration(minutes: 5);

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Bắt đầu giám sát phiên đăng nhập. Gọi sau khi đăng nhập thành công.
  void startChecking() {
    stopChecking(); // Dừng timer cũ nếu có
    debugPrint('[SessionManager] ▶ Bắt đầu giám sát phiên đăng nhập.');
    // Kiểm tra ngay lập tức sau 30 giây, sau đó định kỳ mỗi 5 phút
    _timer = Timer.periodic(_checkInterval, (_) => _checkSession());
    // Kiểm tra lần đầu sau 30 giây (cho app ổn định sau login/splash)
    Timer(const Duration(seconds: 30), _checkSession);
  }

  /// Dừng giám sát phiên đăng nhập. Gọi khi người dùng đăng xuất.
  void stopChecking() {
    _timer?.cancel();
    _timer = null;
    _isRefreshing = false;
    debugPrint('[SessionManager] ⏹ Dừng giám sát phiên đăng nhập.');
  }

  /// Kiểm tra ngay lập tức xem session còn hợp lệ không.
  /// Trả về `true` nếu session hợp lệ (đã refresh nếu cần), `false` nếu hết hạn.
  Future<bool> checkSessionNow() async {
    return _checkSession();
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  Future<bool> _checkSession() async {
    if (_isRefreshing) return true;

    try {
      final user = await _localDataSource.getUser();
      if (user == null) {
        debugPrint('[SessionManager] ⚠ Không tìm thấy session trong bộ nhớ.');
        return false;
      }

      final accessToken = user.accessToken;

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('[SessionManager] ⚠ Access token không tồn tại.');
        await _expireSession();
        return false;
      }

      // Xác định thời điểm hết hạn của access token
      final expiryTime = user.expiresAt ?? _parseJwtExpiry(accessToken);
      final now = DateTime.now();

      if (expiryTime == null) {
        // Không thể xác định expiry → bỏ qua lần này
        debugPrint(
          '[SessionManager] ℹ Không thể xác định expiry của access token, bỏ qua.',
        );
        return true;
      }

      final remaining = expiryTime.difference(now);
      debugPrint(
        '[SessionManager] ℹ Thời gian còn lại của token: ${remaining.inMinutes} phút.',
      );

      if (remaining.isNegative) {
        // Access token đã hết hạn → thử refresh bằng refresh token
        debugPrint(
          '[SessionManager] ⚠ Access token đã hết hạn. Thử refresh...',
        );
        return await _doRefresh();
      } else if (remaining < _refreshThreshold) {
        // Token sắp hết hạn trong vòng 60 phút → proactive refresh
        debugPrint(
          '[SessionManager] 🔄 Token sắp hết hạn (còn ${remaining.inMinutes} phút). Tự động refresh...',
        );
        return await _doRefresh();
      }

      // Token vẫn còn hạn sử dụng lâu
      return true;
    } catch (e) {
      debugPrint('[SessionManager] ❌ Lỗi kiểm tra session: $e');
      return true; // Không kick out khi gặp lỗi mạng
    }
  }

  Future<bool> _doRefresh() async {
    _isRefreshing = true;
    try {
      await FirebaseEmailAuthFlow.refreshSession();
      debugPrint('[SessionManager] Firebase session refreshed.');
      return true;
    } catch (e) {
      debugPrint('[SessionManager] ❌ Lỗi khi refresh token: $e');
      await _expireSession();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _expireSession() async {
    debugPrint('[SessionManager] 🚫 Phiên đăng nhập hết hạn. Đăng xuất...');
    stopChecking();
    await FirebaseEmailAuthFlow.signOut();
    await _clearLocalSessionUseCase(); // Either<Failure, void> — bỏ qua lỗi
    onSessionExpired?.call();
  }

  /// Giải mã JWT payload để lấy thời gian hết hạn (trường `exp`).
  /// JWT có dạng: header.payload.signature (Base64Url encoded)
  static DateTime? _parseJwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Base64Url decode → thêm padding nếu cần
      String payload = parts[1];
      final mod = payload.length % 4;
      if (mod != 0) payload += '=' * (4 - mod);
      // Thay ký tự Base64Url về Base64 chuẩn
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');

      final decoded = utf8.decode(base64.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;

      final exp = map['exp'];
      if (exp == null) return null;

      // `exp` là Unix timestamp (giây)
      return DateTime.fromMillisecondsSinceEpoch(
        (exp as int) * 1000,
        isUtc: true,
      ).toLocal();
    } catch (e) {
      debugPrint('[SessionManager] ⚠ Không thể parse JWT expiry: $e');
      return null;
    }
  }

  // ─── Factory / Singleton helper ────────────────────────────────────────────

  static SessionManager get instance => GetIt.I<SessionManager>();
}
