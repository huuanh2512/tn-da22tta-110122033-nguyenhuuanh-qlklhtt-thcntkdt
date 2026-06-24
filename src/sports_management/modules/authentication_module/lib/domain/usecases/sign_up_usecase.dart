import 'package:app_module/app_module.dart';
import 'package:dartz/dartz.dart';
import 'package:authentication_module/data/models/sign_up_request.dart';
import 'package:authentication_module/data/models/user_result.dart';
import 'package:authentication_module/domain/repositories/user_repository.dart';

class SignUpUseCase {
  const SignUpUseCase(this._repository);

  final UserRepository _repository;

  Future<Either<Failure, UserResult>> call(SignUpRequest request) {
    return _repository.signUp(request);
  }
}