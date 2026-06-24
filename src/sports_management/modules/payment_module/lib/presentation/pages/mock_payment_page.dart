import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../cubit/payment_cubit.dart';
import 'package:notification_module/notification_module.dart';

class MockPaymentPage extends StatefulWidget {
  final String bookingId;
  final double amount;

  const MockPaymentPage({
    super.key,
    required this.bookingId,
    required this.amount,
  });

  @override
  State<MockPaymentPage> createState() => _MockPaymentPageState();
}

class _MockPaymentPageState extends State<MockPaymentPage> {
  late PaymentCubit _cubit;
  static const _primaryColor = Color(0xFFFF5600);

  @override
  void initState() {
    super.initState();
    _cubit = PaymentCubit(GetIt.I(), GetIt.I(), GetIt.I());
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  String _formatPrice(BuildContext context, double price) {
    final intPrice = price.toInt();
    final s = intPrice.toString();
    final result = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) result.write('.');
      result.write(s[i]);
    }
    return context.tr(vi: '${result.toString()} đ', en: '${result.toString()} VND');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedAmount = _formatPrice(context, widget.amount);
    final shortId = widget.bookingId.length > 6 ? widget.bookingId.substring(0, 6) : widget.bookingId;
    final bankContent = 'SP ENERGY HD ${shortId.toUpperCase()}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(vi: 'THANH TOÁN CHUYỂN KHOẢN', en: 'BANK TRANSFER PAYMENT'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: BlocConsumer<PaymentCubit, PaymentState>(
        bloc: _cubit,
        listener: (context, state) {
          if (state is PaymentSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr(vi: 'Thanh toán thành công!', en: 'Payment successful!')),
                backgroundColor: Colors.green,
              ),
            );
            final navigator = Navigator.of(context);
            Future.delayed(const Duration(seconds: 2), () {
              if (navigator.mounted) {
                navigator.pop(true);
              }
            });
          }
          if (state is PaymentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is PaymentProcessing) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: _primaryColor),
                  const SizedBox(height: 16),
                  Text(context.tr(vi: 'Đang xác minh giao dịch...', en: 'Verifying transaction...')),
                ],
              ),
            );
          }

          if (state is PaymentSuccess) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.tr(vi: 'THANH TOÁN THÀNH CÔNG', en: 'PAYMENT SUCCESSFUL'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(vi: 'Hóa đơn #${widget.bookingId} đã được thanh toán.', en: 'Invoice #${widget.bookingId} has been paid.'),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Instructions card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          context.tr(vi: 'Quét mã QR để thanh toán', en: 'Scan QR code to pay'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Mock QR Code representation
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200, width: 2),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Grid background
                              Opacity(
                                opacity: 0.1,
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 10,
                                  ),
                                  itemCount: 100,
                                  itemBuilder: (context, index) => Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black),
                                    ),
                                  ),
                                ),
                              ),
                              // QR Symbol representation
                              Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 140,
                                color: Colors.grey.shade800,
                              ),
                              // Logo in center
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: _primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.sports_soccer,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.tr(vi: 'Số tiền cần thanh toán', en: 'Amount to pay'),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedAmount,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Bank Transfer Information card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(vi: 'THÔNG TIN GIAO DỊCH CHUYỂN KHOẢN', en: 'TRANSFER DETAILS'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBankInfoRow(context.tr(vi: 'Ngân hàng', en: 'Bank'), 'Vietcombank (VCB)'),
                        _buildBankInfoRow(context.tr(vi: 'Số tài khoản', en: 'Account Number'), '1029384756'),
                        _buildBankInfoRow(context.tr(vi: 'Chủ tài khoản', en: 'Account Holder'), 'SPORT ENERGY CO. LTD'),
                        _buildBankInfoRow(context.tr(vi: 'Nội dung CK', en: 'Transfer Content'), bankContent, isCopyable: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Bottom Action buttons
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      _cubit.payInvoice(
                        bookingId: widget.bookingId,
                        amount: widget.amount,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      context.tr(vi: 'XÁC NHẬN ĐÃ CHUYỂN KHOẢN', en: 'CONFIRM TRANSFERRED'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    context.tr(vi: 'Quay lại', en: 'Back'),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBankInfoRow(String label, String value, {bool isCopyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (isCopyable) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    // Giả lập copy clipboard
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr(vi: 'Đã sao chép nội dung chuyển khoản!', en: 'Transfer message copied!')),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: _primaryColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
