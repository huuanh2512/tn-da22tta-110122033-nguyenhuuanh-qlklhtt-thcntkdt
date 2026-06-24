import 'dart:async';

enum AppNotificationEventType {
  fcmReceived,
  fcmOpened,
  bookingCreated,
  bookingConfirmed,
  bookingCancelled,
  bookingRescheduled,
  paymentOnlineSuccess,
  paymentOnlineFailed,
  paymentOfflineConfirmed,
  fcmTokenRegisterRequested,
  fcmTokenRemoveRequested,
}

class AppNotificationEvent {
  const AppNotificationEvent({
    required this.type,
    this.data = const {},
  });

  final AppNotificationEventType type;
  final Map<String, dynamic> data;
}

class AppNotificationEventBus {
  AppNotificationEventBus()
      : _controller = StreamController<AppNotificationEvent>.broadcast();

  final StreamController<AppNotificationEvent> _controller;

  Stream<AppNotificationEvent> get stream => _controller.stream;

  void emit(AppNotificationEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() {
    _controller.close();
  }
}
