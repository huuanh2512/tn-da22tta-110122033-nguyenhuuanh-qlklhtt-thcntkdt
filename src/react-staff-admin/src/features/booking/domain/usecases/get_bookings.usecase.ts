import { BookingRepository } from '../repositories/booking.repository';
import { Booking } from '../entities/booking.entity';

export class GetBookingsUseCase {
  constructor(private repository: BookingRepository) {}

  async execute(): Promise<Booking[]> {
    return this.repository.getBookings();
  }
}
