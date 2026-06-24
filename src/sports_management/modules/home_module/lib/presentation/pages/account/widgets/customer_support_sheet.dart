import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:server_module/server_module.dart';
import 'package:notification_module/notification_module.dart';

class CustomerSupportSheet extends StatefulWidget {
  const CustomerSupportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CustomerSupportSheet(),
    );
  }

  @override
  State<CustomerSupportSheet> createState() => _CustomerSupportSheetState();
}

class _CustomerSupportSheetState extends State<CustomerSupportSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedCategoryId = 'booking';
  
  List<HelpdeskModel> _faqs = [];
  bool _isLoadingFaqs = true;
  bool _isSending = false;

  final List<Map<String, String>> _categoriesList = [
    {'id': 'booking', 'vi': 'Đặt sân & Hủy sân', 'en': 'Booking & Cancellation'},
    {'id': 'payment', 'vi': 'Thanh toán & Hóa đơn', 'en': 'Payment & Invoice'},
    {'id': 'technical', 'vi': 'Lỗi kỹ thuật app', 'en': 'App Technical Bug'},
    {'id': 'feedback', 'vi': 'Ý kiến đóng góp', 'en': 'Feedback & Suggestions'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFAQs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadFAQs() async {
    try {
      final response = await GetIt.I<ContentService>().getHelpdesks();
      if (response.success && response.data != null) {
        final list = response.data as List;
        setState(() {
          _faqs = list
              .map((json) => HelpdeskModel.fromJson(json as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading FAQs: $e');
    } finally {
      setState(() {
        _isLoadingFaqs = false;
      });
    }
  }

  Future<void> _sendTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
    });

    // Simulate API call to send support request
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isSending = false;
      });
      _showSnackBar(context.tr(vi: 'Yêu cầu hỗ trợ đã được gửi thành công!', en: 'Support request sent successfully!'), isError: false);
      _titleController.clear();
      _messageController.clear();
      _tabController.animateTo(0); // Switch back to FAQ
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr(vi: 'Hỗ trợ khách hàng', en: 'Customer support'),
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.secondary,
            unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            indicatorColor: theme.colorScheme.secondary,
            tabs: [
              Tab(text: context.tr(vi: 'Câu hỏi thường gặp', en: 'FAQ')),
              Tab(text: context.tr(vi: 'Liên hệ hỗ trợ', en: 'Contact support')),
            ],
          ),
          const Divider(height: 1),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // FAQ Tab
                _isLoadingFaqs
                    ? const Center(child: CircularProgressIndicator())
                    : _faqs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.help_outline, size: 64, color: theme.disabledColor),
                                const SizedBox(height: 16),
                                Text(context.tr(vi: 'Không có câu hỏi thường gặp nào.', en: 'No FAQs available.')),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _faqs.length,
                            padding: const EdgeInsets.all(16),
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final faq = _faqs[index];
                              return Card(
                                child: ExpansionTile(
                                  shape: Border.all(color: Colors.transparent),
                                  collapsedShape: Border.all(color: Colors.transparent),
                                  title: Text(
                                    faq.title ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      child: Text(
                                        faq.content ?? '',
                                        style: TextStyle(
                                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                // Contact support tab
                Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        context.tr(vi: 'Danh mục hỗ trợ', en: 'Support category'),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        items: _categoriesList.map((cat) {
                          return DropdownMenuItem(
                            value: cat['id'],
                            child: Text(context.tr(vi: cat['vi']!, en: cat['en']!)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategoryId = val;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        context.tr(vi: 'Tiêu đề', en: 'Title'),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: context.tr(vi: 'Nhập tiêu đề yêu cầu', en: 'Enter request title'),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr(vi: 'Vui lòng nhập tiêu đề', en: 'Please enter a title');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Text(
                        context.tr(vi: 'Nội dung chi tiết', en: 'Detailed content'),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _messageController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: context.tr(vi: 'Mô tả chi tiết vấn đề bạn đang gặp phải...', en: 'Describe the issue you are facing in detail...'),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr(vi: 'Vui lòng nhập nội dung chi tiết', en: 'Please enter detailed content');
                          }
                          if (value.trim().length < 10) {
                            return context.tr(vi: 'Nội dung phải dài hơn 10 ký tự', en: 'Content must be longer than 10 characters');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSending ? null : _sendTicket,
                          child: _isSending
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(context.tr(vi: 'Gửi yêu cầu', en: 'Send request')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
