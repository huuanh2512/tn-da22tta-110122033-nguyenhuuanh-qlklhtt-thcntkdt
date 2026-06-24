import { NotificationRepository } from '../repositories/notification.repository';
import { Notification } from '../entities/notification.entity';

export class GetNotificationsUseCase {
  constructor(private repository: NotificationRepository) {}

  async execute(): Promise<{ items: Notification[]; unreadCount: number }> {
    return this.repository.getNotifications();
  }
}
