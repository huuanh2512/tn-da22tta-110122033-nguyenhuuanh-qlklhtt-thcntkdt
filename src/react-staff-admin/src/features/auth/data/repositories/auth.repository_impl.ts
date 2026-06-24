import { AuthRepository } from '../../domain/repositories/auth.repository';
import { AuthUser } from '../../domain/entities/auth_user.entity';
import { AuthRemoteDataSource } from '../datasources/auth.remote_datasource';
import { AuthMapper } from '../models/auth.model';
import { apiClient } from '../../../../core/network/api_client';

export class AuthRepositoryImpl implements AuthRepository {
  constructor(private remoteDataSource: AuthRemoteDataSource) {}

  async login(email: string, password: string): Promise<{
    user: AuthUser;
    accessToken: string;
    refreshToken: string;
  }> {
    const response = await this.remoteDataSource.login(email, password);
    
    // Fetch detailed profile after login
    const userId = response.user._id || (response.user as any).id;
    const profileResponse = await apiClient.get(`/user/${userId}`, {
      headers: {
        Authorization: `Bearer ${response.accessToken}`
      }
    });

    const fullUser = {
      ...response.user,
      _id: userId,
      profile: {
        fullName: profileResponse.data.user?.name || profileResponse.data.user?.profile?.name || profileResponse.data.user?.profile?.fullName,
        phone: profileResponse.data.user?.profile?.phone,
        avatar: profileResponse.data.user?.profile?.avatarUrl || profileResponse.data.user?.profile?.avatar
      },
      facilityId: profileResponse.data.user?.facility?.id || profileResponse.data.user?.facilityId || profileResponse.data.user?.facilityName
    };

    return {
      user: AuthMapper.toEntity(fullUser),
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    };
  }
}
