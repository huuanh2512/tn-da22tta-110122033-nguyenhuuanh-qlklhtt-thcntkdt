const ACCESS_TOKEN_KEY = 'sport_energy_access_token';
const REFRESH_TOKEN_KEY = 'sport_energy_refresh_token';
const USER_KEY = 'sport_energy_user';
export const AUTH_USER_UPDATED_EVENT = 'auth:user-updated';

export interface UserSession {
  _id?: string;
  id?: string;
  email: string;
  role: 'ADMIN' | 'SUPER_ADMIN' | 'STAFF' | 'CUSTOMER';
  // Keep this aligned with the user-status enum returned by the API. The
  // admin user list also displays accounts that have not verified email yet.
  status: 'PENDING_OTP' | 'PENDING_EMAIL' | 'ACTIVE' | 'INACTIVE' | 'BANNED';
  profile?: {
    fullName?: string;
    phone?: string;
    avatar?: string;
  };
  facilityId?: string; // Optional: facility assigned to Staff
}

export const authStorage = {
  getAccessToken: (): string | null => localStorage.getItem(ACCESS_TOKEN_KEY),
  setAccessToken: (token: string): void => localStorage.setItem(ACCESS_TOKEN_KEY, token),
  
  getRefreshToken: (): string | null => localStorage.getItem(REFRESH_TOKEN_KEY),
  setRefreshToken: (token: string): void => localStorage.setItem(REFRESH_TOKEN_KEY, token),
  
  getUser: (): UserSession | null => {
    const userStr = localStorage.getItem(USER_KEY);
    if (!userStr) return null;
    try {
      return JSON.parse(userStr);
    } catch {
      return null;
    }
  },
  setUser: (user: UserSession): void => {
    localStorage.setItem(USER_KEY, JSON.stringify(user));
    window.dispatchEvent(new CustomEvent(AUTH_USER_UPDATED_EVENT, { detail: user }));
  },
  
  clear: (): void => {
    localStorage.removeItem(ACCESS_TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
  }
};
