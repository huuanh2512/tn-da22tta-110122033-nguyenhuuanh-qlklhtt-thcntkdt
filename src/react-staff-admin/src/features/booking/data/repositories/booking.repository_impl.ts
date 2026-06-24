import { BookingRepository } from '../../domain/repositories/booking.repository';
import { Booking } from '../../domain/entities/booking.entity';
import { BookingRemoteDataSource, BookingDTO } from '../datasources/booking.remote_datasource';

export class BookingMapper {
  static toEntity(dto: BookingDTO): Booking {
    return {
      ...dto,
      id: dto._id || dto.id || '', // Handle both _id and id from real API
      courtId: dto.courtId,
      userId: dto.userId,
      bookingDate: dto.bookingDate,
      startMinutes: dto.startMinutes,
      endMinutes: dto.endMinutes,
      totalPrice: dto.totalPrice,
      status: dto.status,
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
      paymentStatus: dto.paymentStatus || dto.payment_status,
      paymentMethod: dto.paymentMethod || dto.payment_method,
      note: dto.note || dto.notes,
      fixedScheduleId: dto.fixedScheduleId || dto.fixed_schedule_id,
      isFixedSchedule: dto.isFixedSchedule || dto.is_fixed_schedule,
      matchingSessionId: dto.matchingSessionId || dto.matching_session_id
    };
  }
}

export class BookingRepositoryImpl implements BookingRepository {
  constructor(private remoteDataSource: BookingRemoteDataSource) {}

  async getBookings(): Promise<Booking[]> {
    const dtos = await this.remoteDataSource.getBookings();
    return dtos.map(BookingMapper.toEntity);
  }

  async getBookingById(id: string): Promise<Booking | null> {
    const dto = await this.remoteDataSource.getBookingById(id);
    return dto ? BookingMapper.toEntity(dto) : null;
  }

  async createBooking(
    courtId: string,
    bookingDate: string,
    startMinutes: number,
    endMinutes: number,
    totalPrice: number,
    userId?: string
  ): Promise<Booking> {
    const dto = await this.remoteDataSource.createBooking(courtId, bookingDate, startMinutes, endMinutes, totalPrice, userId);
    return BookingMapper.toEntity(dto);
  }

  async updateBookingStatus(id: string, status: Booking['status']): Promise<void> {
    return this.remoteDataSource.updateBookingStatus(id, status);
  }
}
