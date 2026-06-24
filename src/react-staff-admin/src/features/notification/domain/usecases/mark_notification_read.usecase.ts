import { NotificationRepository } from '../repositories/notification.repository';

export class MarkNotificationReadUseCase {
  constructor(private repository: NotificationRepository) {}

  async execute(id: string): Promise<void> {
    return this.repository.markAsRead(id);
  }
}
