import { apiClient } from '../../../../core/network/api_client';

export interface NotificationDTO {
  _id?: string;
  id?: string;
  userId: string;
  title: string;
  body: string;
  type: 'SYSTEM' | 'PROMOTION' | 'BOOKING' | 'PAYMENT' | 'MATCHING';
  isRead: boolean;
  createdAt: string;
  metadata?: Record<string, any>;
}

export interface NotificationResponse {
  success: boolean;
  notification: NotificationDTO;
}

export interface NotificationListResponse {
  success: boolean;
  items: NotificationDTO[];
  unreadCount: number;
  total: number;
}

export class NotificationRemoteDataSource {
  async getNotifications(): Promise<{ items: NotificationDTO[]; unreadCount: number }> {
    const response = await apiClient.get<NotificationListResponse>('/notification');
    return {
      items: response.data.items || [],
      unreadCount: response.data.unreadCount || 0
    };
  }

  async markAsRead(id: string): Promise<void> {
    await apiClient.put(`/notification/${id}/read`);
  }

  async markAllAsRead(): Promise<void> {
    await apiClient.put('/notification/mark-all-read');
  }

  async createNotification(payload: {
    userId?: string;
    title: string;
    body: string;
    type: string;
    metadata?: Record<string, any>;
  }): Promise<NotificationDTO> {
    const apiPayload = {
      ...payload,
      content: payload.body
    };
    const response = await apiClient.post<NotificationResponse>('/notification', apiPayload);
    return response.data.notification;
  }
}
