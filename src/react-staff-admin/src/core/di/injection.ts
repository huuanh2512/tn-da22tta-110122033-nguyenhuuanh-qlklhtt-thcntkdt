import { AuthRemoteDataSource } from '../../features/auth/data/datasources/auth.remote_datasource';
import { AuthRepositoryImpl } from '../../features/auth/data/repositories/auth.repository_impl';
import { LoginUseCase } from '../../features/auth/domain/usecases/login.usecase';

import { BookingRemoteDataSource } from '../../features/booking/data/datasources/booking.remote_datasource';
import { BookingRepositoryImpl } from '../../features/booking/data/repositories/booking.repository_impl';
import { GetBookingsUseCase } from '../../features/booking/domain/usecases/get_bookings.usecase';
import { GetBookingDetailUseCase } from '../../features/booking/domain/usecases/get_booking_detail.usecase';
import { CreateBookingUseCase } from '../../features/booking/domain/usecases/create_booking.usecase';
import { UpdateBookingStatusUseCase } from '../../features/booking/domain/usecases/update_booking_status.usecase';

import { NotificationRemoteDataSource } from '../../features/notification/data/datasources/notification.remote_datasource';
import { NotificationRepositoryImpl } from '../../features/notification/data/repositories/notification.repository_impl';
import { GetNotificationsUseCase } from '../../features/notification/domain/usecases/get_notifications.usecase';
import { MarkNotificationReadUseCase } from '../../features/notification/domain/usecases/mark_notification_read.usecase';
import { MarkAllNotificationsReadUseCase } from '../../features/notification/domain/usecases/mark_all_notifications_read.usecase';
import { CreateNotificationUseCase } from '../../features/notification/domain/usecases/create_notification.usecase';

// 1. Data Sources
const authRemoteDataSource = new AuthRemoteDataSource();
const bookingRemoteDataSource = new BookingRemoteDataSource();
const notificationRemoteDataSource = new NotificationRemoteDataSource();

// 2. Repositories
const authRepository = new AuthRepositoryImpl(authRemoteDataSource);
const bookingRepository = new BookingRepositoryImpl(bookingRemoteDataSource);
const notificationRepository = new NotificationRepositoryImpl(notificationRemoteDataSource);

// 3. Use Cases
export const loginUseCase = new LoginUseCase(authRepository);
export const getBookingsUseCase = new GetBookingsUseCase(bookingRepository);
export const getBookingDetailUseCase = new GetBookingDetailUseCase(bookingRepository);
export const createBookingUseCase = new CreateBookingUseCase(bookingRepository);
export const updateBookingStatusUseCase = new UpdateBookingStatusUseCase(bookingRepository);

export const getNotificationsUseCase = new GetNotificationsUseCase(notificationRepository);
export const markNotificationReadUseCase = new MarkNotificationReadUseCase(notificationRepository);
export const markAllNotificationsReadUseCase = new MarkAllNotificationsReadUseCase(notificationRepository);
export const createNotificationUseCase = new CreateNotificationUseCase(notificationRepository);

