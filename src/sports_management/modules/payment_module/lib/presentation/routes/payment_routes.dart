import 'package:go_router/go_router.dart';
import '../pages/invoice_detail_page.dart';

class PaymentRoutes {
  PaymentRoutes._();

  static List<GoRoute> get routes => [
        GoRoute(
          path: '/payments/invoices/:invoiceId',
          builder: (context, state) {
            final invoiceId = state.pathParameters['invoiceId']!;
            return InvoiceDetailPage(invoiceId: invoiceId);
          },
        ),
        GoRoute(
          path: '/payment/mock',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            final bookingId = extra['bookingId'] as String;
            final invoiceId = extra['invoiceId'] as String? ?? bookingId;
            return InvoiceDetailPage(invoiceId: invoiceId);
          },
        ),
      ];
}
