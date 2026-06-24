import 'package:get_it/get_it.dart';
import 'package:server_module/server_module.dart';
import '../../data/datasources/remote/payment_remote_data_source.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../../data/services/zalopay_service.dart';
import '../../domain/usecases/get_payments_usecase.dart';
import '../../domain/usecases/create_payment_usecase.dart';
import '../../domain/usecases/update_payment_status_usecase.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // ── DataSources ─────────────────────────────────────────────────────────
  if (!sl.isRegistered<ZaloPayService>()) {
    sl.registerLazySingleton<ZaloPayService>(() => ZaloPayService(sl<DioClient>()));
  }

  if (!sl.isRegistered<PaymentRemoteDataSource>()) {
    sl.registerLazySingleton<PaymentRemoteDataSource>(
      () => PaymentRemoteDataSourceImpl(sl<PaymentService>(), sl<DioClient>()),
    );
  }

  // ── Repositories ────────────────────────────────────────────────────────
  if (!sl.isRegistered<PaymentRepository>()) {
    sl.registerLazySingleton<PaymentRepository>(
      () => PaymentRepositoryImpl(sl<PaymentRemoteDataSource>()),
    );
  }

  // ── UseCases ────────────────────────────────────────────────────────────
  if (!sl.isRegistered<GetPaymentsUseCase>()) {
    sl.registerLazySingleton<GetPaymentsUseCase>(
      () => GetPaymentsUseCase(sl<PaymentRepository>()),
    );
  }

  if (!sl.isRegistered<CreatePaymentUseCase>()) {
    sl.registerLazySingleton<CreatePaymentUseCase>(
      () => CreatePaymentUseCase(sl<PaymentRepository>()),
    );
  }

  if (!sl.isRegistered<UpdatePaymentStatusUseCase>()) {
    sl.registerLazySingleton<UpdatePaymentStatusUseCase>(
      () => UpdatePaymentStatusUseCase(sl<PaymentRepository>()),
    );
  }
}
