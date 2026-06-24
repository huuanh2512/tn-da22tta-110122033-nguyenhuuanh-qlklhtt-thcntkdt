import 'package:app_module/app_module.dart';
import 'package:dartz/dartz.dart';
import 'package:authentication_module/data/models/sign_out_request.dart';
import 'package:authentication_module/data/models/user_result.dart';
import 'package:authentication_module/domain/repositories/user_repository.dart';

class SignOutUseCase {
  const SignOutUseCase(this._repository);

  final UserRepository _repository;

  Future<Either<Failure, UserResult>> call(SignOutRequest request) {
    return _repository.signOut(request);
  }
}