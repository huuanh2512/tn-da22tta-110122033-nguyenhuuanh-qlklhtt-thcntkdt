import 'package:server_module/server_module.dart';

class GetStaffUsersUseCase {
  final DioClient _dioClient;

  GetStaffUsersUseCase(this._dioClient);

  Future<BaseResponse<List<UserEntity>>> call() async {
    try {
      final response = await _dioClient.dio.get(
        '/user/',
        queryParameters: {'role': 'STAFF'},
      );
      final rawData = response.data as Map<String, dynamic>;
      final itemsList = rawData['items'] as List<dynamic>? ?? [];
      final List<UserEntity> users = [];
      for (final item in itemsList) {
        if (item is Map<String, dynamic>) {
          final profile = item['profile'] as Map<String, dynamic>?;
          users.add(
            UserEntity(
              id: item['_id']?.toString() ?? item['id']?.toString() ?? '',
              email: item['email']?.toString(),
              role: item['role']?.toString(),
              status: item['status']?.toString(),
              name: profile?['fullName']?.toString() ?? item['email']?.toString() ?? 'Staff',
              avatar: profile?['avatar']?.toString(),
            ),
          );
        }
      }
      return BaseResponse<List<UserEntity>>(
        success: true,
        message: 'Lấy danh sách nhân viên thành công',
        data: users,
      );
    } catch (e) {
      return BaseResponse<List<UserEntity>>(
        success: false,
        message: 'Lỗi lấy danh sách nhân viên: $e',
        data: null,
      );
    }
  }
}
