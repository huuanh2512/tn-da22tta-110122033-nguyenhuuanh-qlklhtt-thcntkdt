import { AuthRepository } from '../repositories/auth.repository';
import { AuthUser } from '../entities/auth_user.entity';

export class LoginUseCase {
  constructor(private authRepository: AuthRepository) {}

  async execute(email: string, password: string): Promise<{
    user: AuthUser;
    accessToken: string;
    refreshToken: string;
  }> {
    if (!email || !password) {
      throw new Error('Email và mật khẩu không được để trống');
    }
    return this.authRepository.login(email, password);
  }
}
