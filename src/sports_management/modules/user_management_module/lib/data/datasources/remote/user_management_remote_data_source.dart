import 'package:server_module/server_module.dart';

abstract class UserManagementRemoteDataSource {
  Future<BaseResponse<dynamic>> getUsers();
  Future<BaseResponse<dynamic>> getUserById(String id);
  Future<BaseResponse<dynamic>> updateUser(
    String id,
    Map<String, dynamic> data,
  );
  Future<BaseResponse<dynamic>> updateUserRole(String id, String role);
  Future<BaseResponse<dynamic>> updateUserStatus(String id, String status);
  Future<BaseResponse<dynamic>> assignFacility(String id, String facilityId);
  Future<BaseResponse<dynamic>> provisionFirebaseUser({
    required String email,
    required String role,
    required Map<String, dynamic> profile,
    String? facilityId,
  });
}

class UserManagementRemoteDataSourceImpl
    implements UserManagementRemoteDataSource {
  final UserService _userService;

  UserManagementRemoteDataSourceImpl(this._userService);

  @override
  Future<BaseResponse<dynamic>> getUsers() {
    return _userService.getUsers();
  }

  @override
  Future<BaseResponse<dynamic>> getUserById(String id) {
    return _userService.getUserById(id);
  }

  @override
  Future<BaseResponse<dynamic>> updateUser(
    String id,
    Map<String, dynamic> data,
  ) {
    return _userService.updateUser(id, data);
  }

  @override
  Future<BaseResponse<dynamic>> updateUserRole(String id, String role) {
    return _userService.updateUserRole(id, role);
  }

  @override
  Future<BaseResponse<dynamic>> updateUserStatus(String id, String status) {
    return _userService.updateUserStatus(id, status);
  }

  @override
  Future<BaseResponse<dynamic>> assignFacility(String id, String facilityId) {
    return _userService.assignFacility(id, facilityId);
  }

  @override
  Future<BaseResponse<dynamic>> provisionFirebaseUser({
    required String email,
    required String role,
    required Map<String, dynamic> profile,
    String? facilityId,
  }) => _userService.provisionFirebaseUser(
    email: email,
    role: role,
    profile: profile,
    facilityId: facilityId,
  );
}
