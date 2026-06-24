import { BookingRepository } from '../repositories/booking.repository';
import { Booking } from '../entities/booking.entity';

export class UpdateBookingStatusUseCase {
  constructor(private repository: BookingRepository) {}

  async execute(id: string, status: Booking['status']): Promise<void> {
    return this.repository.updateBookingStatus(id, status);
  }
}
