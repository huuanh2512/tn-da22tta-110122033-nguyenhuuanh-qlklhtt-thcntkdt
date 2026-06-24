import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../cubit/review_cubit.dart';
import '../cubit/review_state.dart';
import 'package:notification_module/notification_module.dart';
import 'package:server_module/server_module.dart';

class ReviewsListWidget extends StatefulWidget {
  final String courtId;

  const ReviewsListWidget({super.key, required this.courtId});

  @override
  State<ReviewsListWidget> createState() => _ReviewsListWidgetState();
}

class _ReviewsListWidgetState extends State<ReviewsListWidget> {
  late ReviewCubit _cubit;
  static const _primaryColor = Color(0xFFFF5600);

  @override
  void initState() {
    super.initState();
    _cubit = ReviewCubit(GetIt.I(), GetIt.I());
    _cubit.loadCourtReviews(widget.courtId);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateDisplayFormatter.date(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<ReviewCubit, ReviewState>(
      bloc: _cubit,
      builder: (context, state) {
        if (state is ReviewLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: CircularProgressIndicator(color: _primaryColor),
            ),
          );
        }

        if (state is ReviewError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Center(
              child: Text(
                state.message,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (state is ReviewsLoaded) {
          final reviews = state.reviews;
          final averageRating = state.averageRating;

          if (reviews.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      color: Colors.grey.shade300,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr(
                        vi: 'Chưa có đánh giá nào cho sân này.',
                        en: 'No reviews yet for this court.',
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Average summary rating card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: _primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '/5',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < averageRating.round()
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: Colors.amber,
                                  size: 16,
                                );
                              }),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${reviews.length} ${context.tr(vi: 'đánh giá', en: 'reviews')}',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Container(
                            height: 60,
                            padding: const EdgeInsets.only(left: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: theme.dividerColor.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr(
                                    vi: 'Đánh giá chất lượng',
                                    en: 'Quality rating',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  averageRating >= 4.0
                                      ? context.tr(
                                          vi: 'Tuyệt vời - Rất đáng trải nghiệm!',
                                          en: 'Excellent - Highly recommended!',
                                        )
                                      : averageRating >= 3.0
                                      ? context.tr(
                                          vi: 'Tốt - Sân bãi ổn định',
                                          en: 'Good - Stable courts',
                                        )
                                      : context.tr(
                                          vi: 'Bình thường',
                                          en: 'Average',
                                        ),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Reviews List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reviews.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                review.userName != null &&
                                        review.userName!.isNotEmpty
                                    ? review.userName![0].toUpperCase()
                                    : 'K',
                                style: const TextStyle(
                                  color: _primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    review.userName ??
                                        context.tr(
                                          vi: 'Khách hàng',
                                          en: 'Customer',
                                        ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Row(
                                        children: List.generate(5, (starIdx) {
                                          return Icon(
                                            starIdx < (review.rating ?? 0)
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            color: Colors.amber,
                                            size: 12,
                                          );
                                        }),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(review.createdAt),
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (review.comment != null &&
                            review.comment!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 46.0),
                            child: Text(
                              review.comment!,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
