import 'package:get_it/get_it.dart';
import 'package:server_module/server_module.dart';
import '../../data/datasources/remote/review_remote_data_source.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../domain/usecases/get_court_reviews_usecase.dart';
import '../../domain/usecases/create_review_usecase.dart';
import '../../domain/usecases/get_all_reviews_usecase.dart';
import '../../domain/usecases/delete_review_usecase.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // ── DataSources ─────────────────────────────────────────────────────────
  if (!sl.isRegistered<ReviewRemoteDataSource>()) {
    sl.registerLazySingleton<ReviewRemoteDataSource>(
      () => ReviewRemoteDataSourceImpl(sl<ReviewService>(), sl<DioClient>()),
    );
  }

  // ── Repositories ────────────────────────────────────────────────────────
  if (!sl.isRegistered<ReviewRepository>()) {
    sl.registerLazySingleton<ReviewRepository>(
      () => ReviewRepositoryImpl(sl<ReviewRemoteDataSource>()),
    );
  }

  // ── UseCases ────────────────────────────────────────────────────────────
  if (!sl.isRegistered<GetCourtReviewsUseCase>()) {
    sl.registerLazySingleton<GetCourtReviewsUseCase>(
      () => GetCourtReviewsUseCase(sl<ReviewRepository>()),
    );
  }

  if (!sl.isRegistered<CreateReviewUseCase>()) {
    sl.registerLazySingleton<CreateReviewUseCase>(
      () => CreateReviewUseCase(sl<ReviewRepository>()),
    );
  }

  if (!sl.isRegistered<GetAllReviewsUseCase>()) {
    sl.registerLazySingleton<GetAllReviewsUseCase>(
      () => GetAllReviewsUseCase(sl<ReviewRepository>()),
    );
  }

  if (!sl.isRegistered<DeleteReviewUseCase>()) {
    sl.registerLazySingleton<DeleteReviewUseCase>(
      () => DeleteReviewUseCase(sl<ReviewRepository>()),
    );
  }
}
