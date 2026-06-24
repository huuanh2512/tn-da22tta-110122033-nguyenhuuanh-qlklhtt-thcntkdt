import { BookingRepository } from '../repositories/booking.repository';
import { Booking } from '../entities/booking.entity';

export class GetBookingDetailUseCase {
  constructor(private repository: BookingRepository) {}

  async execute(id: string): Promise<Booking | null> {
    return this.repository.getBookingById(id);
  }
}
