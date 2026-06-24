import { AuthUser } from '../../domain/entities/auth_user.entity';

export interface AuthUserDTO {
  _id: string;
  email: string;
  role: 'ADMIN' | 'STAFF' | 'CUSTOMER';
  status: 'ACTIVE' | 'INACTIVE';
  profile?: {
    fullName?: string;
    phone?: string;
    avatar?: string;
  };
  facilityId?: string;
}

export class AuthMapper {
  static toEntity(dto: AuthUserDTO): AuthUser {
    return {
      id: dto._id,
      email: dto.email,
      role: dto.role,
      status: dto.status,
      fullName: dto.profile?.fullName,
      phone: dto.profile?.phone,
      avatar: dto.profile?.avatar,
      facilityId: dto.facilityId
    };
  }
}
