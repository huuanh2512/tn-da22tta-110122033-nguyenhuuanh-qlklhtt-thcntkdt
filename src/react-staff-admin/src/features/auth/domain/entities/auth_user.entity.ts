export interface AuthUser {
  id: string;
  email: string;
  role: 'ADMIN' | 'STAFF' | 'CUSTOMER';
  status: 'ACTIVE' | 'INACTIVE';
  fullName?: string;
  phone?: string;
  avatar?: string;
  facilityId?: string;
}
