export interface Notification {
  id: string;
  userId: string;
  title: string;
  body: string;
  type: 'SYSTEM' | 'PROMOTION' | 'BOOKING' | 'PAYMENT' | 'MATCHING' | 'REVIEW';
  isRead: boolean;
  createdAt: string;
  metadata?: Record<string, any>;
}
