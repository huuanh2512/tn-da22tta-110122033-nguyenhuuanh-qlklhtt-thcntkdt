import { apiClient } from '../../../../core/network/api_client';

export interface BookingDTO {
  _id?: string;
  id?: string;
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
  fixed_schedule_id?: string;
  isFixedSchedule?: boolean;
  is_fixed_schedule?: boolean;
  matchingSessionId?: string;
  matching_session_id?: string;
  [key: string]: any;
}

export interface BookingResponse {
  success: boolean;
  booking: BookingDTO;
}

export interface BookingListResponse {
  success: boolean;
  items: BookingDTO[];
  total: number;
}

export class BookingRemoteDataSource {
  async getBookings(params?: { status?: string; bookingDate?: string; courtId?: string }): Promise<BookingDTO[]> {
    const response = await apiClient.get<BookingListResponse>('/booking', { params });
    return (response.data.items || []).map(dto => ({
      ...dto,
      _id: dto._id || dto.id || '',
    }));
  }

  async getBookingById(id: string): Promise<BookingDTO | null> {
    const response = await apiClient.get<any>(`/booking/${id}`);
    const payload = response.data?.booking || response.data?.data?.booking || response.data?.data || response.data;
    if (!payload || typeof payload !== 'object') return null;
    return { ...payload, _id: payload._id || payload.id || id };
  }

  async createBooking(
    courtId: string,
    bookingDate: string,
    startMinutes: number,
    endMinutes: number,
    totalPrice: number,
    userId?: string
  ): Promise<BookingDTO> {
    const payload: any = { courtId, bookingDate, startMinutes, endMinutes, totalPrice };
    if (userId) payload.userId = userId;
    const response = await apiClient.post<BookingResponse>('/booking', payload);
    const dto = response.data.booking;
    return { ...dto, _id: dto._id || dto.id || '' };
  }

  async updateBookingStatus(id: string, status: string): Promise<void> {
    await apiClient.put(`/booking/${id}/status`, { status });
  }
}
