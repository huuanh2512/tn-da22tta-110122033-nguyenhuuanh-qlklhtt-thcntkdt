import { apiClient } from '../../../../core/network/api_client';
import { signInWithEmailAndPassword, sendEmailVerification } from 'firebase/auth';
import { firebaseAuth } from '../../../../core/firebase/firebase_auth';
import { AuthUserDTO } from '../models/auth.model';

export interface LoginResponse {
  success: boolean;
  accessToken: string;
  refreshToken: string;
  user: AuthUserDTO;
}

export class AuthRemoteDataSource {
  async login(email: string, password: string): Promise<LoginResponse> {
    const credential = await signInWithEmailAndPassword(firebaseAuth, email, password);
    if (!credential.user.emailVerified) {
      await sendEmailVerification(credential.user);
      const error: any = new Error('Email chưa xác thực. Sport Energy đã gửi lại liên kết xác thực.');
      error.response = { data: { code: 'EMAIL_NOT_VERIFIED', message: error.message } };
      throw error;
    }
    const response = await apiClient.post<LoginResponse>('/auth/firebase/login', { firebaseIdToken: await credential.user.getIdToken(true) });
    return response.data;
  }
}
