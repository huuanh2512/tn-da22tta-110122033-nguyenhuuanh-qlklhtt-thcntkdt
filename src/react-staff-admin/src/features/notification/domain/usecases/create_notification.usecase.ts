import { NotificationRepository } from '../repositories/notification.repository';
import { Notification } from '../entities/notification.entity';

export class CreateNotificationUseCase {
  constructor(private repository: NotificationRepository) {}

  async execute(payload: {
    userId?: string;
    title: string;
    body: string;
    type: Notification['type'];
    metadata?: Record<string, any>;
  }): Promise<Notification> {
    return this.repository.createNotification(payload);
  }
}
