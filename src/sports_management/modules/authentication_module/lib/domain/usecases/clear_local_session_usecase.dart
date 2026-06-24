import 'package:app_module/app_module.dart';
import 'package:dartz/dartz.dart';
import 'package:authentication_module/domain/repositories/user_repository.dart';

class ClearLocalSessionUseCase {
  const ClearLocalSessionUseCase(this._repository);

  final UserRepository _repository;

  Future<Either<Failure, void>> call() {
    return _repository.clearLocalSession();
  }
}
