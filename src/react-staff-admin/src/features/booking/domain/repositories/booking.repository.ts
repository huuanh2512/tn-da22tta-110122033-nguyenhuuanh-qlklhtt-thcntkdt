import { Booking } from '../entities/booking.entity';

export interface BookingRepository {
  getBookings(): Promise<Booking[]>;
  getBookingById(id: string): Promise<Booking | null>;
  createBooking(
    courtId: string,
    bookingDate: string,
    startMinutes: number,
    endMinutes: number,
    totalPrice: number,
    userId?: string
  ): Promise<Booking>;
  updateBookingStatus(id: string, status: Booking['status']): Promise<void>;
}
