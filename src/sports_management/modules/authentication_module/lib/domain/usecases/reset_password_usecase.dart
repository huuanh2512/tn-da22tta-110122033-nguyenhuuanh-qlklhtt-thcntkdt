import 'package:app_module/app_module.dart';
import 'package:dartz/dartz.dart';
import 'package:authentication_module/data/models/reset_password_request.dart';
import 'package:authentication_module/data/models/user_result.dart';
import 'package:authentication_module/domain/repositories/user_repository.dart';

class ResetPasswordUseCase {
  const ResetPasswordUseCase(this._repository);

  final UserRepository _repository;

  Future<Either<Failure, UserResult>> call(ResetPasswordRequest request) {
    return _repository.resetPassword(request);
  }
}