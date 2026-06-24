import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../cubit/review_cubit.dart';
import '../cubit/review_state.dart';
import 'package:notification_module/notification_module.dart';

class ReviewBottomSheet extends StatefulWidget {
  final String courtId;
  final VoidCallback? onSuccess;

  const ReviewBottomSheet({
    super.key,
    required this.courtId,
    this.onSuccess,
  });

  static Future<void> show(BuildContext context, {required String courtId, VoidCallback? onSuccess}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReviewBottomSheet(courtId: courtId, onSuccess: onSuccess),
    );
  }

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  late ReviewCubit _cubit;
  int _selectedRating = 5;
  final TextEditingController _commentController = TextEditingController();
  static const _primaryColor = Color(0xFFFF5600);

  @override
  void initState() {
    super.initState();
    _cubit = ReviewCubit(GetIt.I(), GetIt.I());
  }

  @override
  void dispose() {
    _cubit.close();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: BlocConsumer<ReviewCubit, ReviewState>(
        bloc: _cubit,
        listener: (context, state) {
          if (state is ReviewSubmitSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr(vi: 'Cảm ơn bạn đã đánh giá!', en: 'Thank you for your review!')),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            widget.onSuccess?.call();
            Navigator.pop(context);
          } else if (state is ReviewError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final isSubmitting = state is ReviewSubmitting;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull bar
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.tr(vi: 'ĐÁNH GIÁ SÂN BÃI', en: 'RATE THE COURT'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(vi: 'Chia sẻ trải nghiệm của bạn khi chơi tại sân nhé!', en: 'Share your experience playing at this court!'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Interactive Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final ratingValue = index + 1;
                  final isSelected = ratingValue <= _selectedRating;
                  return GestureDetector(
                    onTap: isSubmitting
                        ? null
                        : () => setState(() => _selectedRating = ratingValue),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: AnimatedScale(
                        scale: isSelected ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          isSelected
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: isSelected ? Colors.amber : Colors.grey.shade300,
                          size: 44,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Comment input
              TextField(
                controller: _commentController,
                enabled: !isSubmitting,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: context.tr(vi: 'Nhập ý kiến đóng góp của bạn về chất lượng sân, ánh sáng, lưới, phục vụ...', en: 'Enter your feedback about court quality, lighting, net, service...'),
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          _cubit.submitReview(
                            courtId: widget.courtId,
                            rating: _selectedRating,
                            comment: _commentController.text.trim(),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          context.tr(vi: 'GỬI ĐÁNH GIÁ', en: 'SUBMIT REVIEW'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
