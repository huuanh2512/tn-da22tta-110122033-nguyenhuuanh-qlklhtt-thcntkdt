const mongoose = require('mongoose');
const userRepository = require('../repositories/user.repository');
const crypto = require('crypto');
const { getFirebaseAdmin } = require('../config/firebase-admin');

class UserService {
  _businessError(message, statusCode = 400, code = 'USER_ERROR') {
    const error = new Error(message);
    error.statusCode = statusCode;
    error.code = code;
    return error;
  }

  _objectId(value, name, required = false) {
    if (value === undefined || value === null || value === '') {
      if (required) {
        throw this._businessError(`${name} is required`, 400, 'MISSING_FIELDS');
      }
      return null;
    }

    if (typeof value !== 'string') {
      throw this._businessError(`Invalid ${name}`, 400, 'INVALID_ID');
    }

    const normalized = value.trim();
    if (!mongoose.isValidObjectId(normalized)) {
      throw this._businessError(`Invalid ${name}`, 400, 'INVALID_ID');
    }

    return normalized;
  }

  _formatUserResponse(user) {
    return {
      id: user._id.toString(),
      email: user.email,
      role: user.role,
      status: user.status,
      profile: {
        name: user.profile?.name || '',
        phone: user.profile?.phone || '',
        avatarUrl: user.profile?.avatar_url || ''
      },
      facility: user.facility_id ? {
        id: user.facility_id._id?.toString() || user.facility_id.toString(),
        name: user.facility_id.name || ''
      } : null,
      createdAt: user.created_at ? new Date(user.created_at).toISOString() : null
    };
  }

  async queryUsers(filters, skip = 0, limit = 20) {
    const query = {};
    const userId = this._objectId(filters.userId, 'userId');
    const facilityId = this._objectId(filters.facilityId, 'facilityId');

    if (userId) query._id = userId;
    if (filters.email) query.email = new RegExp(filters.email, 'i');
    if (filters.role) query.role = filters.role;
    if (filters.status) query.status = filters.status;
    if (facilityId) query.facility_id = facilityId;

    const [users, total] = await Promise.all([
      userRepository.findMany(query, parseInt(skip), parseInt(limit)),
      userRepository.count(query)
    ]);

    return {
      items: users.map(user => this._formatUserResponse(user)),
      total: total
    };
  }

  async getUserProfile(userId) {
    const user = await userRepository.findById(userId);
    if (!user) throw new Error('User not found');
    return { user: this._formatUserResponse(user) };
  }

  async updateUserProfile(userId, profileData, facilityName) {
    const user = await userRepository.findById(userId);
    if (!user) throw new Error('User not found');

    const currentProfile = user.profile || {};
    const newProfile = {
      name: profileData.name !== undefined ? profileData.name : currentProfile.name,
      phone: profileData.phone !== undefined ? profileData.phone : currentProfile.phone,
      avatar_url: profileData.avatarUrl !== undefined ? profileData.avatarUrl : currentProfile.avatar_url
    };

    const updatedUser = await userRepository.updateById(userId, { profile: newProfile });
    return { user: this._formatUserResponse(updatedUser) };
  }

  async updateUserRole(userId, role) {
    const validRoles = ['CUSTOMER', 'STAFF', 'ADMIN'];
    if (!validRoles.includes(role)) throw new Error('Invalid role');

    const updateData = { role };
    if (role !== 'STAFF') {
      updateData.facility_id = null;
    }

    const user = await userRepository.updateById(userId, updateData);
    if (!user) throw new Error('User not found');
    return true;
  }

  async updateUserStatus(userId, status) {
    const validStatuses = ['PENDING_OTP', 'PENDING_EMAIL', 'ACTIVE', 'INACTIVE', 'BANNED'];
    if (!validStatuses.includes(status)) throw new Error('Invalid status');

    const user = await userRepository.updateStatus(userId, status);
    if (!user) throw new Error('User not found');
    return true;
  }

  async assignUserFacility(userId, facilityId) {
    const normalizedUserId = this._objectId(userId, 'userId', true);
    const normalizedFacilityId = this._objectId(facilityId, 'facilityId', true);
    const user = await userRepository.updateById(normalizedUserId, {
      facility_id: normalizedFacilityId
    });
    if (!user) throw new Error('User not found');
    return true;
  }

  async provisionFirebaseUser({ email, role, profile = {}, facilityId = null }) {
    if (!['STAFF', 'ADMIN'].includes(role)) throw this._businessError('Only STAFF or ADMIN can be provisioned', 400, 'INVALID_ROLE');
    const normalizedEmail = email.trim().toLowerCase();
    const existing = await userRepository.findByEmail(normalizedEmail);
    if (existing?.firebaseUid) throw this._businessError('Email is already provisioned', 409, 'EMAIL_EXISTS');
    if (existing) throw this._businessError('Legacy profile exists; migrate it instead of provisioning a new identity', 409, 'LEGACY_MIGRATION_REQUIRED');
    const auth = getFirebaseAdmin().auth();
    const temporaryPassword = crypto.randomBytes(32).toString('base64url');
    const firebaseUser = await auth.createUser({ email: normalizedEmail, password: temporaryPassword, displayName: profile.name || undefined, emailVerified: false });
    try {
      const user = await userRepository.create({ email: normalizedEmail, firebaseUid: firebaseUser.uid, role, status: 'PENDING_EMAIL', profile: { name: profile.name || '', phone: profile.phone || '' }, facility_id: facilityId || null, authMigrationStatus: 'FIREBASE_PROVISIONED', authMigratedAt: new Date() });
      return this._formatUserResponse(user);
    } catch (error) {
      await auth.deleteUser(firebaseUser.uid).catch(rollbackError => console.error('[Provision] Firebase rollback failed:', rollbackError.message));
      throw error;
    }
  }
}

module.exports = new UserService();
