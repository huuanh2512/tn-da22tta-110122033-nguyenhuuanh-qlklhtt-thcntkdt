import 'package:server_module/data/models/base_response.dart';
import 'package:server_module/domain/entities/user_entity.dart';

abstract class UserRepository {
  Future<BaseResponse<List<UserEntity>>> getUsers();
  
  Future<BaseResponse<UserEntity>> getUserById(String id);
  
  Future<BaseResponse<UserEntity>> updateUser(String id, Map<String, dynamic> data);
  
  Future<BaseResponse<UserEntity>> updateUserRole(String id, String role);
  
  Future<BaseResponse<UserEntity>> updateUserStatus(String id, String status);
  
  Future<BaseResponse<UserEntity>> assignFacility(String id, String facilityId);
}