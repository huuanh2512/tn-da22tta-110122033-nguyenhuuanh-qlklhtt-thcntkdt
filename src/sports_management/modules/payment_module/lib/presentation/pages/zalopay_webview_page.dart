import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app WebView hiển thị ZaloPay QC gateway.
/// Khi user bấm "Mở ứng dụng Zalopay", WebView intercept deeplink
/// zalopay:// và mở thẳng ZaloPay Sandbox bằng explicit Android Intent.
class ZaloPayWebViewPage extends StatefulWidget {
  /// URL order_url từ backend: https://qcgateway.zalopay.vn/openinapp?order=...
  final String orderUrl;

  const ZaloPayWebViewPage({super.key, required this.orderUrl});

  @override
  State<ZaloPayWebViewPage> createState() => _ZaloPayWebViewPageState();
}

class _ZaloPayWebViewPageState extends State<ZaloPayWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  // Package names ZaloPay theo thứ tự ưu tiên (đã xác nhận sb1 trên thiết bị)
  static const _zalopayPackages = <String>[
    'vn.com.vng.zalopay.sb1',  // ✅ ZaloPay Sandbox SB1 — đã xác nhận
    'vn.com.vng.zalopay.sb',
    'vn.com.vng.zalopay.dev',
    'vn.com.vng.zalopay',
    'com.vnpay.zalopay',
  ];

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Lỗi tải trang: ${error.description}';
            });
          },
          // ─── Intercept zalopay:// deeplink để mở ZaloPay Sandbox ───
          onNavigationRequest: (request) async {
            final url = request.url;
            debugPrint('[ZaloPayWebView] Navigation: $url');

            // Intercept zalopay:// scheme deeplink
            if (url.startsWith('zalopay://')) {
              debugPrint('[ZaloPayWebView] Intercepted deeplink: $url');
              await _openZaloPaySandbox(url);
              // Báo cho WebView NOT navigate (chúng ta đã xử lý rồi)
              return NavigationDecision.prevent;
            }

            // Cho phép các URL khác trong ZaloPay gateway
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.orderUrl));
  }

  /// Mở ZaloPay Sandbox bằng explicit Android Intent với deeplink zalopay://
  Future<void> _openZaloPaySandbox(String deeplink) async {
    if (Platform.isAndroid) {
      for (final pkg in _zalopayPackages) {
        try {
          final intent = AndroidIntent(
            action: 'action_view',
            data: deeplink,
            package: pkg,
            flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
          );
          await intent.launch();
          debugPrint('[ZaloPayWebView] ✅ Opened ZaloPay with package: $pkg');
          // Đóng WebView sau khi mở ZaloPay Sandbox
          if (mounted) Navigator.of(context).pop(true);
          return;
        } catch (e) {
          debugPrint('[ZaloPayWebView] ❌ Package $pkg failed: $e');
        }
      }
    }

    // Fallback: mở deeplink bình thường
    try {
      await launchUrl(Uri.parse(deeplink), mode: LaunchMode.externalApplication);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[ZaloPayWebView] ❌ Fallback deeplink failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Row(
          children: [
            Image.network(
              'https://res.cloudinary.com/dzlgh2xbd/image/upload/v1/sports_management/zalopay_logo',
              height: 24,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            const Text(
              'Thanh toán ZaloPay',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ─── WebView chính ───
          if (_errorMessage == null)
            WebViewWidget(controller: _controller)
          else
            _buildErrorView(),

          // ─── Loading indicator ───
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0068FF)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Đang tải cổng thanh toán...',
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // ─── Hướng dẫn nhỏ ở trên ───
          if (!_isLoading && _errorMessage == null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xFFFFF3E0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFFE65100)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chọn "Mở ứng dụng Zalopay" để thanh toán',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Không thể tải trang',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _errorMessage = null);
                _controller.loadRequest(Uri.parse(widget.orderUrl));
              },
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
