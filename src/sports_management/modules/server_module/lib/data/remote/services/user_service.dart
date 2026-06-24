import 'package:server_module/core/dio_client.dart';
import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/exceptions/exceptions.dart';

class UserService {
  final DioClient _dioClient;

  UserService(this._dioClient);

  Future<BaseResponse<dynamic>> getUsers() async {
    try {
      final response = await _dioClient.dio.get('/user/');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> getUserById(String id) async {
    try {
      final response = await _dioClient.dio.get('/user/$id');
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> updateUser(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.dio.put('/user/$id', data: data);
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> updateUserRole(String id, String role) async {
    try {
      final response = await _dioClient.dio.put(
        '/user/$id/role',
        data: {'role': role},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> updateUserStatus(
    String id,
    String status,
  ) async {
    try {
      final response = await _dioClient.dio.put(
        '/user/$id/status',
        data: {'status': status},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> assignFacility(
    String id,
    String facilityId,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        '/user/$id/assign-facility',
        data: {'facilityId': facilityId},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  /// Creates a Firebase identity. The app then sends its password-reset email,
  /// so a temporary password is never exposed to an administrator.
  Future<BaseResponse<dynamic>> provisionFirebaseUser({
    required String email,
    required String role,
    required Map<String, dynamic> profile,
    String? facilityId,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/user/provision-firebase',
        data: {
          'email': email.trim().toLowerCase(),
          'role': role,
          'profile': profile,
          if (facilityId?.trim().isNotEmpty == true) 'facilityId': facilityId,
        },
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> registerFCMToken(String token) async {
    try {
      final response = await _dioClient.dio.post(
        '/user/register-fcm',
        data: {'token': token},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }

  Future<BaseResponse<dynamic>> removeFCMToken(String token) async {
    try {
      final response = await _dioClient.dio.post(
        '/user/remove-fcm',
        data: {'token': token},
      );
      return BaseResponse.fromJson(response.data, (json) => json);
    } catch (error) {
      return ExceptionHandler.handle<dynamic>(error);
    }
  }
}
