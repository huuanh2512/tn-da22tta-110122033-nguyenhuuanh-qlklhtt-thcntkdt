import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:notification_module/notification_module.dart';
import 'package:server_module/server_module.dart';

class NotificationHistoryPanel extends StatelessWidget {
  const NotificationHistoryPanel({super.key});

  String _displayTitle(String? title, BuildContext context) {
    final value = title?.trim();
    if (value == null || value.isEmpty) {
      return context.tr(vi: 'Thông báo hệ thống', en: 'System Notification');
    }

    if (value.toLowerCase().replaceAll('!', '') == 'keo dau da san sang') {
      return context.tr(vi: 'Kèo đấu đã sẵn sàng', en: 'The match is ready');
    }
    return value;
  }

  String _displayContent(String? content) {
    final value = content?.trim() ?? '';
    final legacyReadyMatch = RegExp(
      r'^Tran dau cua ban tai (.+?) vao ngay (.+?) da du nguoi\.?$',
      caseSensitive: false,
    ).firstMatch(value);

    if (legacyReadyMatch != null) {
      final facilityName = legacyReadyMatch.group(1);
      final date = legacyReadyMatch.group(2);
      return 'Trận đấu của bạn tại $facilityName vào ngày $date đã đủ người.';
    }
    return value;
  }

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationHistoryPanel(),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr(vi: 'Thông báo', en: 'Notifications'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                BlocBuilder<NotificationCubit, NotificationState>(
                  builder: (context, state) {
                    final hasUnread = state.notifications.any(
                      (n) => n.isRead == false,
                    );
                    return TextButton(
                      onPressed: hasUnread
                          ? () {
                              context.read<NotificationCubit>().markAllAsRead();
                            }
                          : null,
                      child: Text(
                        context.tr(vi: 'Đọc tất cả', en: 'Mark all as read'),
                        style: TextStyle(
                          color: hasUnread
                              ? theme.colorScheme.secondary
                              : theme.disabledColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(),

          // Notifications List
          Expanded(
            child: BlocBuilder<NotificationCubit, NotificationState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 64,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr(
                            vi: 'Chưa có thông báo nào',
                            en: 'No notifications yet',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: state.notifications.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = state.notifications[index];
                    final isRead = item.isRead ?? false;

                    return InkWell(
                      onTap: () {
                        if (!isRead) {
                          context.read<NotificationCubit>().markAsRead(item.id);
                        }
                        final bookingId = item.metadata?['bookingId']
                            ?.toString();
                        if (item.type == 'BOOKING' &&
                            bookingId != null &&
                            bookingId.isNotEmpty) {
                          final router = GoRouter.of(context);
                          Navigator.of(context).pop();
                          router.push('/booking/$bookingId');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        color: isRead
                            ? Colors.transparent
                            : theme.colorScheme.secondary.withValues(
                                alpha: 0.04,
                              ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon wrapper
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isRead
                                    ? theme.colorScheme.surface
                                    : theme.colorScheme.secondary.withValues(
                                        alpha: 0.12,
                                      ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.type == 'BOOKING'
                                    ? Icons.event_available_outlined
                                    : Icons.notifications_active_outlined,
                                size: 20,
                                color: isRead
                                    ? theme.textTheme.bodyMedium?.color
                                          ?.withValues(alpha: 0.6)
                                    : theme.colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _displayTitle(item.title, context),
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                fontWeight: isRead
                                                    ? FontWeight.normal
                                                    : FontWeight.bold,
                                                color: theme
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.color,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(context, item.createdAt),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 11,
                                              color: theme
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withValues(alpha: 0.6),
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _displayContent(item.content),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isRead
                                          ? theme.textTheme.bodyMedium?.color
                                                ?.withValues(alpha: 0.7)
                                          : theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Unread indicator dot
                            if (!isRead) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dt);
    if (difference.inMinutes < 1) {
      return context.tr(vi: 'Vừa xong', en: 'Just now');
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} ${context.tr(vi: 'p', en: 'm')}';
    } else if (difference.inDays < 1 && now.day == dt.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return DateDisplayFormatter.date(dt);
    }
  }
}
