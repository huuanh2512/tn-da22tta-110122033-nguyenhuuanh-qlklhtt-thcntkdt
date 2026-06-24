import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/assign_facility_usecase.dart';
import '../../domain/usecases/get_users_usecase.dart';
import '../../domain/usecases/provision_firebase_user_usecase.dart';
import '../../domain/usecases/update_user_role_usecase.dart';
import '../../domain/usecases/update_user_status_usecase.dart';
import 'user_management_state.dart';

class UserManagementCubit extends Cubit<UserManagementState> {
  UserManagementCubit(
    this._getUsersUseCase,
    this._updateUserRoleUseCase,
    this._updateUserStatusUseCase,
    this._assignFacilityUseCase,
    this._provisionFirebaseUserUseCase,
  ) : super(UserManagementInitial());

  final GetUsersUseCase _getUsersUseCase;
  final UpdateUserRoleUseCase _updateUserRoleUseCase;
  final UpdateUserStatusUseCase _updateUserStatusUseCase;
  final AssignFacilityUseCase _assignFacilityUseCase;
  final ProvisionFirebaseUserUseCase _provisionFirebaseUserUseCase;

  Future<void> loadUsers() async {
    emit(UserManagementLoading());
    try {
      final response = await _getUsersUseCase();
      if (response.success && response.data != null) {
        emit(UserManagementLoaded(response.data!));
      } else {
        emit(
          UserManagementError(
            response.message ?? 'Không thể tải danh sách người dùng.',
          ),
        );
      }
    } catch (error) {
      emit(UserManagementError('Lỗi kết nối: $error'));
    }
  }

  Future<void> updateUserRole(String id, String role) async {
    emit(UserManagementLoading());
    try {
      final response = await _updateUserRoleUseCase(id, role);
      if (response.success) {
        emit(
          const UserManagementSuccess(
            'Cập nhật vai trò người dùng thành công!',
          ),
        );
        await loadUsers();
      } else {
        emit(
          UserManagementError(response.message ?? 'Cập nhật vai trò thất bại.'),
        );
      }
    } catch (error) {
      emit(UserManagementError('Lỗi: $error'));
    }
  }

  Future<void> updateUserStatus(String id, String status) async {
    emit(UserManagementLoading());
    try {
      final response = await _updateUserStatusUseCase(id, status);
      if (response.success) {
        emit(const UserManagementSuccess('Cập nhật trạng thái thành công!'));
        await loadUsers();
      } else {
        emit(
          UserManagementError(
            response.message ?? 'Cập nhật trạng thái thất bại.',
          ),
        );
      }
    } catch (error) {
      emit(UserManagementError('Lỗi: $error'));
    }
  }

  Future<void> assignFacility(String id, String facilityId) async {
    emit(UserManagementLoading());
    try {
      final response = await _assignFacilityUseCase(id, facilityId);
      if (response.success) {
        emit(const UserManagementSuccess('Gán cơ sở thành công!'));
        await loadUsers();
      } else {
        emit(UserManagementError(response.message ?? 'Gán cơ sở thất bại.'));
      }
    } catch (error) {
      emit(UserManagementError('Lỗi: $error'));
    }
  }

  /// Returns true only after the backend has atomically provisioned Firebase
  /// and the local user record. The UI can then request Firebase's reset email.
  Future<bool> provisionFirebaseUser({
    required String email,
    required String role,
    String? name,
    String? phone,
    String? facilityId,
  }) async {
    emit(UserManagementLoading());
    try {
      final response = await _provisionFirebaseUserUseCase(
        email: email.trim().toLowerCase(),
        role: role,
        name: name?.trim() ?? '',
        phone: phone?.trim() ?? '',
        facilityId: facilityId,
      );
      if (!response.success) {
        emit(
          UserManagementError(
            response.message ?? 'Không thể tạo tài khoản.',
          ),
        );
        return false;
      }
      emit(const UserManagementSuccess('Đã tạo tài khoản.'));
      await loadUsers();
      return true;
    } catch (error) {
      emit(UserManagementError('Không thể tạo tài khoản: $error'));
      return false;
    }
  }
}
