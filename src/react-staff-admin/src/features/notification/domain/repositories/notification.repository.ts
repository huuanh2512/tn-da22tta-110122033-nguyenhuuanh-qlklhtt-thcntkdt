import { Notification } from '../entities/notification.entity';

export interface NotificationRepository {
  getNotifications(): Promise<{ items: Notification[]; unreadCount: number }>;
  markAsRead(id: string): Promise<void>;
  markAllAsRead(): Promise<void>;
  createNotification(payload: {
    userId?: string;
    title: string;
    body: string;
    type: Notification['type'];
    metadata?: Record<string, any>;
  }): Promise<Notification>;
}
