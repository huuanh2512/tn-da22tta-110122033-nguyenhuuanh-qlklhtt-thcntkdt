import 'package:authentication_module/data/models/user_result.dart';
import 'package:authentication_module/data/models/update_profile_request.dart';
import 'package:authentication_module/data/datasources/local/authentication_local_data_source.dart';
import 'package:server_module/server_module.dart';

abstract class UserRemoteDataSource {
  Future<UserResult> getUserData();
  Future<UserResult> updateUserProfile(UpdateProfileRequest request);
  Future<UserResult> deleteUserAvatar(String userId);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  UserRemoteDataSourceImpl({
    required this._userRepository,
    required this._authenticationLocalDataSource,
  });

  final UserRepository _userRepository;
  final AuthenticationLocalDataSource _authenticationLocalDataSource;

  @override
  Future<UserResult> getUserData() async {
    final String? userId = await _authenticationLocalDataSource.getUserId();
    if (userId == null || userId.trim().isEmpty) {
      return const UserResult(
        isSuccess: false,
        error: 'Không tìm thấy userId trong local storage.',
      );
    }

    final result = await _userRepository.getUserById(userId);
    return _mapEntityToUserResult(result.success, result.message, result.data);
  }

  @override
  Future<UserResult> updateUserProfile(UpdateProfileRequest request) async {
    final Map<String, dynamic> profile = {
      if (request.name != null) 'name': request.name,
      if (request.name != null) 'fullName': request.name,
      if (request.phone != null) 'phone': request.phone,
      if (request.avatar != null) 'avatar': request.avatar,
      if (request.avatar != null) 'avatarUrl': request.avatar,
    };

    final Map<String, dynamic> data = {
      'profile': profile,
      if (request.facilityName != null) 'facilityName': request.facilityName,
    };

    final result = await _userRepository.updateUser(request.userId, data);
    return _mapEntityToUserResult(result.success, result.message, result.data);
  }

  @override
  Future<UserResult> deleteUserAvatar(String userId) async {
    final result = await _userRepository.updateUser(
      userId,
      {
        'profile': {
          'avatar': null,
          'avatarUrl': null,
        }
      },
    );
    return _mapEntityToUserResult(result.success, result.message, result.data);
  }

  UserResult _mapEntityToUserResult(
    bool success,
    String? message,
    UserEntity? entity,
  ) {
    return UserResult(
      isSuccess: success,
      error: success ? null : message,
      userId: entity?.id,
      email: entity?.email,
      name: entity?.name,
      avatarUrl: entity?.avatar,
      role: entity?.role,
      status: entity?.status,
    );
  }
}