import 'package:server_module/server_module.dart';
import '../../domain/entities/user_catalog_entity.dart';
import '../datasources/remote/user_management_remote_data_source.dart';

class AdminUserRepositoryImpl implements UserRepository {
  final UserManagementRemoteDataSource _remoteDataSource;

  AdminUserRepositoryImpl(this._remoteDataSource);

  @override
  Future<BaseResponse<List<UserEntity>>> getUsers() async {
    final response = await _remoteDataSource.getUsers();
    if (!response.success || response.data == null) {
      return BaseResponse<List<UserEntity>>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final itemsList = rawData['items'] as List<dynamic>?;
      final users = <UserEntity>[];

      if (itemsList != null) {
        for (final item in itemsList) {
          if (item is Map<String, dynamic>) {
            final profile = item['profile'] as Map<String, dynamic>?;
            final createdStr = item['createdAt']?.toString();
            users.add(
              UserCatalogEntity(
                id: item['_id']?.toString() ?? item['id']?.toString() ?? '',
                email: item['email']?.toString() ?? '',
                role: item['role']?.toString() ?? 'CUSTOMER',
                status: item['status']?.toString() ?? 'ACTIVE',
                name: profile != null
                    ? (profile['name']?.toString() ??
                          profile['fullName']?.toString())
                    : null,
                avatar: profile != null
                    ? (profile['avatarUrl']?.toString() ??
                          profile['avatar']?.toString())
                    : null,
                facilityName: _parseFacilityName(item),
                facilityId: _parseFacilityId(item),
                phone: profile != null ? profile['phone']?.toString() : null,
                createdAt: createdStr != null
                    ? DateTime.tryParse(createdStr)
                    : null,
              ),
            );
          }
        }
      }

      return BaseResponse<List<UserEntity>>(
        success: true,
        message: response.message,
        data: users,
      );
    } catch (e) {
      return BaseResponse<List<UserEntity>>(
        success: false,
        message: 'Lỗi parse danh sách UserEntity: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<UserEntity>> getUserById(String id) async {
    final response = await _remoteDataSource.getUserById(id);
    return _mapToUserResponse(response);
  }

  @override
  Future<BaseResponse<UserEntity>> updateUser(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _remoteDataSource.updateUser(id, data);
    return _mapToUserResponse(response);
  }

  @override
  Future<BaseResponse<UserEntity>> updateUserRole(
    String id,
    String role,
  ) async {
    final response = await _remoteDataSource.updateUserRole(id, role);
    return _mapToUserResponse(response);
  }

  @override
  Future<BaseResponse<UserEntity>> updateUserStatus(
    String id,
    String status,
  ) async {
    final response = await _remoteDataSource.updateUserStatus(id, status);
    return _mapToUserResponse(response);
  }

  @override
  Future<BaseResponse<UserEntity>> assignFacility(
    String id,
    String facilityId,
  ) async {
    final response = await _remoteDataSource.assignFacility(id, facilityId);
    return _mapToUserResponse(response);
  }

  Future<BaseResponse<dynamic>> provisionFirebaseUser({
    required String email,
    required String role,
    required String name,
    required String phone,
    String? facilityId,
  }) => _remoteDataSource.provisionFirebaseUser(
    email: email,
    role: role,
    profile: {'name': name, 'phone': phone},
    facilityId: facilityId,
  );

  BaseResponse<UserEntity> _mapToUserResponse(BaseResponse<dynamic> response) {
    if (!response.success || response.data == null) {
      return BaseResponse<UserEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final userMap = (rawData['user'] as Map<String, dynamic>?) ?? rawData;
      final profile = userMap['profile'] as Map<String, dynamic>?;
      final createdStr = userMap['createdAt']?.toString();
      final user = UserCatalogEntity(
        id: userMap['_id']?.toString() ?? userMap['id']?.toString() ?? '',
        email: userMap['email']?.toString() ?? '',
        role: userMap['role']?.toString() ?? 'CUSTOMER',
        status: userMap['status']?.toString() ?? 'ACTIVE',
        name: profile != null
            ? (profile['name']?.toString() ?? profile['fullName']?.toString())
            : null,
        avatar: profile != null
            ? (profile['avatarUrl']?.toString() ??
                  profile['avatar']?.toString())
            : null,
        facilityName: _parseFacilityName(userMap),
        facilityId: _parseFacilityId(userMap),
        phone: profile != null ? profile['phone']?.toString() : null,
        createdAt: createdStr != null ? DateTime.tryParse(createdStr) : null,
      );
      return BaseResponse<UserEntity>(
        success: true,
        message: response.message,
        data: user,
      );
    } catch (e) {
      return BaseResponse<UserEntity>(
        success: false,
        message: 'Lỗi parse UserEntity: $e',
        data: null,
      );
    }
  }

  String? _parseFacilityName(Map<String, dynamic> item) {
    if (item['facilityName'] != null) {
      return item['facilityName'].toString();
    }
    final facility = item['facility'];
    if (facility is Map) {
      return facility['name']?.toString() ??
          facility['facilityName']?.toString();
    }
    return null;
  }

  String? _parseFacilityId(Map<String, dynamic> item) {
    if (item['facilityId'] != null) {
      return _extractHexId(item['facilityId']);
    }
    final facility = item['facility'];
    if (facility != null) {
      return _extractHexId(facility);
    }
    return null;
  }

  String? _extractHexId(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final id = value['_id'] ?? value['id'];
      return id != null ? _extractHexId(id) : null;
    }
    if (value is List) {
      return value.isNotEmpty ? _extractHexId(value.first) : null;
    }
    final str = value.toString().trim();
    if (str == '[]' || str == 'null') return null;
    final regExp = RegExp(r'[a-fA-F0-9]{24}');
    final match = regExp.firstMatch(str);
    if (match != null) {
      return match.group(0);
    }
    if (RegExp(r'^\d+$').hasMatch(str)) {
      return str;
    }
    return str.isNotEmpty ? str : null;
  }
}
