import 'package:flutter_test/flutter_test.dart';
import 'package:server_module/server_module.dart';
import 'package:user_management_module/data/datasources/remote/user_management_remote_data_source.dart';
import 'package:user_management_module/data/repositories/admin_user_repository_impl.dart';
import 'package:user_management_module/domain/usecases/get_users_usecase.dart';
import 'package:user_management_module/domain/usecases/update_user_role_usecase.dart';
import 'package:user_management_module/domain/usecases/update_user_status_usecase.dart';
import 'package:user_management_module/domain/usecases/assign_facility_usecase.dart';
import 'package:user_management_module/domain/usecases/provision_firebase_user_usecase.dart';
import 'package:user_management_module/presentation/cubit/user_management_cubit.dart';
import 'package:user_management_module/presentation/cubit/user_management_state.dart';

class FakeRemoteDataSource implements UserManagementRemoteDataSource {
  bool shouldSucceed = true;
  String? lastUserId;
  String? lastRole;
  String? lastStatus;
  String? lastFacilityId;
  Map<String, dynamic>? lastUpdateData;

  @override
  Future<BaseResponse<dynamic>> getUsers() async {
    return BaseResponse(
      success: shouldSucceed,
      data: shouldSucceed ? {'items': []} : null,
      message: shouldSucceed ? null : 'Error',
    );
  }

  @override
  Future<BaseResponse<dynamic>> getUserById(String id) async {
    return BaseResponse(
      success: shouldSucceed,
      data: shouldSucceed ? {'_id': id, 'email': 'test@test.com'} : null,
      message: shouldSucceed ? null : 'Error',
    );
  }

  @override
  Future<BaseResponse<dynamic>> updateUser(
    String id,
    Map<String, dynamic> data,
  ) async {
    lastUserId = id;
    lastUpdateData = data;
    return BaseResponse(
      success: shouldSucceed,
      data: shouldSucceed
          ? {'_id': id, 'email': 'test@test.com', 'profile': data['profile']}
          : null,
      message: shouldSucceed ? null : 'Error',
    );
  }

  @override
  Future<BaseResponse<dynamic>> updateUserRole(String id, String role) async {
    lastUserId = id;
    lastRole = role;
    return BaseResponse(
      success: shouldSucceed,
      data: shouldSucceed ? {'_id': id, 'role': role} : null,
      message: shouldSucceed ? null : 'Error',
    );
  }

  @override
  Future<BaseResponse<dynamic>> updateUserStatus(
    String id,
    String status,
  ) async {
    lastUserId = id;
    lastStatus = status;
    return BaseResponse(
      success: shouldSucceed,
      data: shouldSucceed ? {'_id': id, 'status': status} : null,
      message: shouldSucceed ? null : 'Error',
    );
  }

  @override
  Future<BaseResponse<dynamic>> assignFacility(
    String id,
    String facilityId,
  ) async {
    lastUserId = id;
    lastFacilityId = facilityId;
    return BaseResponse(
      success: shouldSucceed,
      data: shouldSucceed ? {'_id': id, 'facilityId': facilityId} : null,
      message: shouldSucceed ? null : 'Error',
    );
  }

  @override
  Future<BaseResponse<dynamic>> provisionFirebaseUser({
    required String email,
    required String role,
    required Map<String, dynamic> profile,
    String? facilityId,
  }) async {
    lastRole = role;
    lastFacilityId = facilityId;
    lastUpdateData = profile;
    return BaseResponse(
      success: shouldSucceed,
      data: shouldSucceed
          ? {
              'user': {'email': email, 'role': role},
            }
          : null,
      message: shouldSucceed ? null : 'Email already exists',
    );
  }
}

void main() {
  group('UserManagementCubit Firebase provisioning tests', () {
    late FakeRemoteDataSource fakeDataSource;
    late AdminUserRepositoryImpl repository;
    late GetUsersUseCase getUsersUseCase;
    late UpdateUserRoleUseCase updateUserRoleUseCase;
    late UpdateUserStatusUseCase updateUserStatusUseCase;
    late AssignFacilityUseCase assignFacilityUseCase;
    late ProvisionFirebaseUserUseCase provisionFirebaseUserUseCase;
    late UserManagementCubit cubit;

    setUp(() {
      fakeDataSource = FakeRemoteDataSource();
      repository = AdminUserRepositoryImpl(fakeDataSource);
      getUsersUseCase = GetUsersUseCase(repository);
      updateUserRoleUseCase = UpdateUserRoleUseCase(repository);
      updateUserStatusUseCase = UpdateUserStatusUseCase(repository);
      assignFacilityUseCase = AssignFacilityUseCase(repository);
      provisionFirebaseUserUseCase = ProvisionFirebaseUserUseCase(repository);

      cubit = UserManagementCubit(
        getUsersUseCase,
        updateUserRoleUseCase,
        updateUserStatusUseCase,
        assignFacilityUseCase,
        provisionFirebaseUserUseCase,
      );
    });

    tearDown(() {
      cubit.close();
    });

    test(
      'should provision a STAFF user through the Firebase endpoint',
      () async {
        // Act
        final provisioned = await cubit.provisionFirebaseUser(
          email: 'new_staff@test.com',
          role: 'STAFF',
          name: 'New Staff Name',
          phone: '0987654321',
          facilityId: 'facility_abc',
        );

        // Assert
        expect(provisioned, isTrue);
        expect(fakeDataSource.lastUpdateData, {
          'name': 'New Staff Name',
          'phone': '0987654321',
        });
        expect(fakeDataSource.lastRole, 'STAFF');
        expect(fakeDataSource.lastFacilityId, 'facility_abc');

        expect(cubit.state, isA<UserManagementLoaded>());
      },
    );

    test('should fail if Firebase provisioning fails', () async {
      // Arrange
      fakeDataSource.shouldSucceed = false;

      // Act
      final provisioned = await cubit.provisionFirebaseUser(
        email: 'staff_fail@test.com',
        role: 'STAFF',
      );

      // Assert
      expect(provisioned, isFalse);
      expect(cubit.state, isA<UserManagementError>());
      expect(
        (cubit.state as UserManagementError).message,
        contains('Email already exists'),
      );
    });
  });
}
