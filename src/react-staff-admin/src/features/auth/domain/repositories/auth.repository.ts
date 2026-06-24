import { AuthUser } from '../entities/auth_user.entity';

export interface AuthRepository {
  login(email: string, password: string): Promise<{
    user: AuthUser;
    accessToken: string;
    refreshToken: string;
  }>;
}
