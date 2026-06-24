import { NotificationRepository } from '../../domain/repositories/notification.repository';
import { Notification } from '../../domain/entities/notification.entity';
import { NotificationRemoteDataSource, NotificationDTO } from '../datasources/notification.remote_datasource';

export class NotificationMapper {
  static toEntity(dto: NotificationDTO): Notification {
    return {
      id: dto._id || dto.id || '',
      userId: dto.userId,
      title: dto.title,
      body: dto.body,
      type: dto.type,
      isRead: dto.isRead || false,
      createdAt: dto.createdAt,
      metadata: dto.metadata
    };
  }
}

export class NotificationRepositoryImpl implements NotificationRepository {
  constructor(private remoteDataSource: NotificationRemoteDataSource) {}

  async getNotifications(): Promise<{ items: Notification[]; unreadCount: number }> {
    const { items, unreadCount } = await this.remoteDataSource.getNotifications();
    return {
      items: items.map(NotificationMapper.toEntity),
      unreadCount
    };
  }

  async markAsRead(id: string): Promise<void> {
    return this.remoteDataSource.markAsRead(id);
  }

  async markAllAsRead(): Promise<void> {
    return this.remoteDataSource.markAllAsRead();
  }

  async createNotification(payload: {
    userId?: string;
    title: string;
    body: string;
    type: Notification['type'];
    metadata?: Record<string, any>;
  }): Promise<Notification> {
    const dto = await this.remoteDataSource.createNotification(payload);
    return NotificationMapper.toEntity(dto);
  }
}
