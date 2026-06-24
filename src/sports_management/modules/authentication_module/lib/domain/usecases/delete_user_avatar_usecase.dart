import 'package:app_module/app_module.dart';
import 'package:dartz/dartz.dart';
import 'package:authentication_module/data/models/user_result.dart';
import 'package:authentication_module/domain/repositories/user_repository.dart';

class DeleteUserAvatarUseCase {
  const DeleteUserAvatarUseCase(this._repository);

  final UserRepository _repository;

  Future<Either<Failure, UserResult>> call(String userId) {
    return _repository.deleteUserAvatar(userId);
  }
}
