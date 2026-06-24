import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:review_module/review_module.dart';
import 'package:server_module/server_module.dart';

class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key});

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage> {
  int? _selectedRating; // null for ALL
  List<ReviewDetailEntity> _reviews = [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _ratingFilters = [
    {'label': 'Tất cả', 'value': null},
    {'label': '5 ★', 'value': 5},
    {'label': '4 ★', 'value': 4},
    {'label': '3 ★', 'value': 3},
    {'label': '2 ★', 'value': 2},
    {'label': '1 ★', 'value': 1},
  ];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      final useCase = GetIt.I<GetAllReviewsUseCase>();
      final response = await useCase(ratingFilter: _selectedRating);
      if (response.success && response.data != null) {
        setState(() {
          _reviews = response.data!;
        });
      } else {
        setState(() {
          _reviews = [];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.message ?? 'Không thể tải danh sách đánh giá',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Xóa đánh giá'),
          ],
        ),
        content: const Text(
          'Bạn có chắc muốn xóa đánh giá này khỏi hệ thống? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final useCase = GetIt.I<DeleteReviewUseCase>();
        final response = await useCase(reviewId);
        if (response.success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã xóa đánh giá thành công'),
                backgroundColor: Colors.green,
              ),
            );
          }
          _loadReviews();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.message ?? 'Không thể xóa đánh giá'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kiểm duyệt Nội dung',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _ratingFilters.length,
              itemBuilder: (context, index) {
                final filter = _ratingFilters[index];
                final isSelected = _selectedRating == filter['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(
                      filter['label'],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedRating = filter['value'];
                        });
                        _loadReviews();
                      }
                    },
                    selectedColor: const Color(0xFFFF5600),
                    checkmarkColor: Colors.white,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFFF5600)
                            : theme.dividerColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Reviews List
          Expanded(
            child: _isLoading && _reviews.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF5600)),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReviews,
                    color: const Color(0xFFFF5600),
                    child: _reviews.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.25,
                              ),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.rate_review_outlined,
                                      size: 72,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Không tìm thấy đánh giá nào',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Kéo xuống để tải lại',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _reviews.length,
                            itemBuilder: (context, index) {
                              final review = _reviews[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // User name & Date
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              review.userName ?? 'Ẩn danh',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (review.createdAt != null)
                                            Text(
                                              DateDisplayFormatter.date(
                                                review.createdAt!,
                                              ),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),

                                      // Rating Stars
                                      Row(
                                        children: List.generate(5, (starIdx) {
                                          final isFilled =
                                              starIdx < (review.rating ?? 0);
                                          return Icon(
                                            isFilled
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 16,
                                            color: isFilled
                                                ? Colors.amber
                                                : Colors.grey.shade300,
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 12),

                                      // Review comment
                                      Text(
                                        review.comment ?? 'Không có nhận xét.',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Meta: Court/Facility info if available
                                      if (review.courtId != null)
                                        Text(
                                          'Sân: #${review.courtId!.substring(review.courtId!.length - 6).toUpperCase()}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),

                                      const Divider(height: 24),

                                      // Delete Button
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () =>
                                              _deleteReview(review.id),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                            color: Colors.red,
                                          ),
                                          label: const Text(
                                            'Xóa đánh giá',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
