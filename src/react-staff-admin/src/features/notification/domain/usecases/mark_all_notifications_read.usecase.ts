import { NotificationRepository } from '../repositories/notification.repository';

export class MarkAllNotificationsReadUseCase {
  constructor(private repository: NotificationRepository) {}

  async execute(): Promise<void> {
    return this.repository.markAllAsRead();
  }
}
