import 'package:app_module/app_module.dart';
import 'package:dartz/dartz.dart';
import 'package:authentication_module/data/models/update_profile_request.dart';
import 'package:authentication_module/data/models/user_result.dart';
import 'package:authentication_module/domain/repositories/user_repository.dart';

class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._repository);

  final UserRepository _repository;

  Future<Either<Failure, UserResult>> call(UpdateProfileRequest request) {
    return _repository.updateUserProfile(request);
  }
}