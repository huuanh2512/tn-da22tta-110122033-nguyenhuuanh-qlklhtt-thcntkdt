export interface Booking {
  id: string;
  courtId: string;
  userId: string;
  bookingDate: string; // yyyy-MM-dd
  startMinutes: number;
  endMinutes: number;
  totalPrice: number;
  status: 'PENDING' | 'CONFIRMED' | 'COMPLETED' | 'CANCELLED';
  createdAt: string;
  updatedAt?: string;
  paymentStatus?: string;
  paymentMethod?: string;
  note?: string;
  fixedScheduleId?: string;
  isFixedSchedule?: boolean;
  matchingSessionId?: string;
  [key: string]: any;
}
