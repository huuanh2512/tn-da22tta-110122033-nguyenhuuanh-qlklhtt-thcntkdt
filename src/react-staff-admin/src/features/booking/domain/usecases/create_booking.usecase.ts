import { BookingRepository } from '../repositories/booking.repository';
import { Booking } from '../entities/booking.entity';

export class CreateBookingUseCase {
  constructor(private repository: BookingRepository) {}

  async execute(
    courtId: string,
    bookingDate: string,
    startMinutes: number,
    endMinutes: number,
    totalPrice: number,
    userId?: string
  ): Promise<Booking> {
    return this.repository.createBooking(courtId, bookingDate, startMinutes, endMinutes, totalPrice, userId);
  }
}
