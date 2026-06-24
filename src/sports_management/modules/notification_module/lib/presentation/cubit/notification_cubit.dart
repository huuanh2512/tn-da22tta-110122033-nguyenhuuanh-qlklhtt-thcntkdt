// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_notifications_usecase.dart';
import '../../domain/usecases/mark_notification_read_usecase.dart';
import '../../domain/usecases/mark_all_notifications_read_usecase.dart';
import 'package:server_module/server_module.dart';

class NotificationState {
  final List<NotificationEntity> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? errorMessage;

  const NotificationState({
    required this.notifications,
    required this.unreadCount,
    required this.isLoading,
    this.errorMessage,
  });

  factory NotificationState.initial() {
    return const NotificationState(
      notifications: [],
      unreadCount: 0,
      isLoading: false,
    );
  }

  NotificationState copyWith({
    List<NotificationEntity>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? errorMessage,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class NotificationCubit extends Cubit<NotificationState> {
  final GetNotificationsUseCase _getNotifications;
  final MarkNotificationReadUseCase _markRead;
  final MarkAllNotificationsReadUseCase _markAllRead;
  StreamSubscription? _eventBusSubscription;

  NotificationCubit({
    required GetNotificationsUseCase getNotifications,
    required MarkNotificationReadUseCase markRead,
    required MarkAllNotificationsReadUseCase markAllRead,
    Stream<dynamic>? eventStream,
  })  : _getNotifications = getNotifications,
        _markRead = markRead,
        _markAllRead = markAllRead,
        super(NotificationState.initial()) {
    if (eventStream != null) {
      _eventBusSubscription = eventStream.listen((event) {
        loadNotifications();
      });
    }
  }

  void setEventStream(Stream<dynamic> stream) {
    _eventBusSubscription?.cancel();
    _eventBusSubscription = stream.listen((event) {
      loadNotifications();
    });
  }

  Future<void> loadNotifications() async {
    emit(state.copyWith(isLoading: true));
    try {
      final list = await _getNotifications();
      final unread = list.where((n) => n.isRead == false).length;
      emit(state.copyWith(
        notifications: list,
        unreadCount: unread,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> markAsRead(String id) async {
    final updatedNotifications = state.notifications.map((n) {
      if (n.id == id) {
        return NotificationEntity(
          id: n.id,
          userId: n.userId,
          title: n.title,
          content: n.content,
          type: n.type,
          metadata: n.metadata,
          isRead: true,
          createdAt: n.createdAt,
        );
      }
      return n;
    }).toList();
    final unread = updatedNotifications.where((n) => n.isRead == false).length;
    emit(state.copyWith(
      notifications: updatedNotifications,
      unreadCount: unread,
    ));

    final result = await _markRead(id);
    if (!result.success) {
      loadNotifications();
    }
  }

  Future<void> markAllAsRead() async {
    final updatedNotifications = state.notifications.map((n) {
      return NotificationEntity(
        id: n.id,
        userId: n.userId,
        title: n.title,
        content: n.content,
        type: n.type,
        metadata: n.metadata,
        isRead: true,
        createdAt: n.createdAt,
      );
    }).toList();
    emit(state.copyWith(
      notifications: updatedNotifications,
      unreadCount: 0,
    ));

    final result = await _markAllRead();
    if (!result.success) {
      loadNotifications();
    }
  }

  @override
  Future<void> close() {
    _eventBusSubscription?.cancel();
    return super.close();
  }
}
