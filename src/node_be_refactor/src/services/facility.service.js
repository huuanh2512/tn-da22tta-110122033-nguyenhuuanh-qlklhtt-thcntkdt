const facilityRepository = require('../repositories/facility.repository');
const User = require('../models/user.model');

class FacilityService {
  _normalizeStaffIds(staffIds) {
    if (staffIds === undefined || staffIds === null) return [];

    const values = Array.isArray(staffIds) ? staffIds : [staffIds];
    return values
      .flatMap((value) => {
        if (value === undefined || value === null) return [];
        if (Array.isArray(value)) return value;
        const text = value.toString().trim();
        if (!text || text === '[]' || text.toLowerCase() === 'null') return [];
        return [text];
      })
      .filter((value) => /^[a-fA-F0-9]{24}$/.test(value.toString().trim()));
  }

  _formatFacilityResponse(facility) {
  return {
    id: facility._id.toString(),
    name: facility.name,
    address: {
      city: facility.address?.city || '',
      full: facility.address?.full || ''
    },
    active: facility.active,
    // Thêm trường này vào để lấy ID nhân viên
    staffIds: facility.staff_ids || [], 
    createdAt: facility.created_at ? new Date(facility.created_at).toISOString() : null
  };
}

  async queryFacilities(filters, skip = 0, limit = 20) {
    const query = {};
    
    if (filters.active !== undefined) {
      query.active = filters.active === 'true' || filters.active === true;
    }
    if (filters.city) {
      query['address.city'] = new RegExp(filters.city, 'i');
    }

    const [facilities, total] = await Promise.all([
      facilityRepository.findMany(query, parseInt(skip), parseInt(limit)),
      facilityRepository.count(query)
    ]);

    return {
      items: facilities.map(f => this._formatFacilityResponse(f)),
      total: total
    };
  }

  async createFacility(data) {
    const facilityData = {
      name: data.name,
      address: {
        city: data.city || '',
        full: data.fullAddress || ''
      },
      active: data.active !== undefined ? data.active : true,
      staff_ids: this._normalizeStaffIds(data.staffIds)
    };

    const newFacility = await facilityRepository.create(facilityData);
    return { facility: this._formatFacilityResponse(newFacility) };
  }

  async getFacilityById(id) {
    const facility = await facilityRepository.findById(id);
    if (!facility) {
      throw new Error('Facility not found');
    }

    return {
      facility: {
        _id: facility._id.toString(),
        name: facility.name,
        city: facility.address?.city || '',
        fullAddress: facility.address?.full || '',
        active: facility.active
      }
    };
  }

  async updateFacility(id, data, actor) {
    const facility = await facilityRepository.findById(id);
    if (!facility) {
      const error = new Error('Facility not found');
      error.statusCode = 404;
      error.code = 'NOT_FOUND';
      throw error;
    }

    if (actor?.role === 'STAFF') {
      const staff = await User.findById(actor.id).select('facility_id');
      const assignedByUser = staff?.facility_id?.toString() === id;
      const assignedByFacility = (facility.staff_ids || []).some(
        (staffId) => staffId.toString() === actor.id
      );

      if (!assignedByUser && !assignedByFacility) {
        const error = new Error('Forbidden: Facility is not assigned to this staff account');
        error.statusCode = 403;
        error.code = 'FORBIDDEN';
        throw error;
      }

      const name = data.name?.trim();
      const fullAddress = data.fullAddress?.trim();
      if (!name || !fullAddress) {
        const error = new Error('Facility name and address are required');
        error.statusCode = 400;
        error.code = 'MISSING_FIELDS';
        throw error;
      }

      data = {
        name,
        fullAddress
      };
    }

    const updateData = {};
    
    if (data.name !== undefined) updateData.name = data.name;
    if (data.active !== undefined) updateData.active = data.active;
    
    if (data.city !== undefined || data.fullAddress !== undefined) {
      updateData.address = {
        city: data.city !== undefined ? data.city : (facility.address?.city || ''),
        full: data.fullAddress !== undefined ? data.fullAddress : (facility.address?.full || '')
      };
    }
    
    if (data.staffIds !== undefined) {
      updateData.staff_ids = this._normalizeStaffIds(data.staffIds);
    }

    const updatedFacility = await facilityRepository.updateById(id, updateData);
    if (!updatedFacility) throw new Error('Facility not found');
    
    return { facility: this._formatFacilityResponse(updatedFacility) };
  }

  async deleteFacility(id) {
    const deleted = await facilityRepository.deleteById(id);
    if (!deleted) throw new Error('Facility not found');
    return true;
  }
}

module.exports = new FacilityService();
