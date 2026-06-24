const mongoose = require('mongoose');
const CourtBlock = require('../models/court-block.model');
const bookingService = require('./booking.service');

const BLOCK_TYPES = [
  'MAINTENANCE',
  'HOLIDAY',
  'MANUAL_BLOCK',
  'CLOSED',
  'OTHER'
];

class CourtBlockService {
  _businessError(message, statusCode = 400, code = 'COURT_BLOCK_ERROR') {
    const error = new Error(message);
    error.statusCode = statusCode;
    error.code = code;
    return error;
  }

  _objectId(value, name, required = false) {
    if (value === undefined || value === null || value === '') {
      if (required) {
        throw this._businessError(
          `${name} is required`,
          400,
          'MISSING_FIELDS'
        );
      }
      return null;
    }
    if (typeof value !== 'string' || !mongoose.isValidObjectId(value)) {
      throw this._businessError(
        `Invalid ${name}`,
        400,
        'INVALID_FILTER'
      );
    }
    return value;
  }

  _date(value, name, required = false) {
    if (value === undefined || value === null || value === '') {
      if (required) {
        throw this._businessError(
          `${name} is required`,
          400,
          'MISSING_FIELDS'
        );
      }
      return null;
    }
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      throw this._businessError(
        `Invalid ${name}`,
        400,
        'INVALID_TIME_RANGE'
      );
    }
    return date;
  }

  _type(value) {
    if (value === undefined || value === null || value === '') {
      return 'MANUAL_BLOCK';
    }
    if (!BLOCK_TYPES.includes(value)) {
      throw this._businessError(
        'Invalid court block type',
        400,
        'INVALID_BLOCK_TYPE'
      );
    }
    return value;
  }

  _format(block) {
    return {
      id: block._id.toString(),
      facilityId: block.facility_id?._id?.toString()
        || block.facility_id.toString(),
      courtId: block.court_id
        ? block.court_id._id?.toString() || block.court_id.toString()
        : null,
      startTime: new Date(block.start_time).toISOString(),
      endTime: new Date(block.end_time).toISOString(),
      reason: block.reason || '',
      type: block.type,
      status: block.status,
      createdBy: block.created_by?._id?.toString()
        || block.created_by.toString(),
      createdAt: block.created_at
        ? new Date(block.created_at).toISOString()
        : null,
      updatedAt: block.updated_at
        ? new Date(block.updated_at).toISOString()
        : null
    };
  }

  async _assertScope(actor, facilityId, courtId = null) {
    return await bookingService.resolveCourtReportScope(actor, {
      facilityId,
      courtId
    });
  }

  async create(data, actor) {
    const facilityId = this._objectId(
      data.facilityId,
      'facilityId',
      true
    );
    const courtId = this._objectId(data.courtId, 'courtId');
    const startTime = this._date(data.startTime, 'startTime', true);
    const endTime = this._date(data.endTime, 'endTime', true);
    if (startTime >= endTime) {
      throw this._businessError(
        'startTime must be before endTime',
        400,
        'INVALID_TIME_RANGE'
      );
    }

    await this._assertScope(actor, facilityId, courtId);
    const block = await CourtBlock.create({
      facility_id: facilityId,
      court_id: courtId,
      start_time: startTime,
      end_time: endTime,
      reason: typeof data.reason === 'string' ? data.reason.trim() : '',
      type: this._type(data.type),
      status: 'ACTIVE',
      created_by: actor.id
    });
    return this._format(block);
  }

  async query(filters, actor) {
    const facilityId = this._objectId(filters.facilityId, 'facilityId');
    const courtId = this._objectId(filters.courtId, 'courtId');
    const scope = await bookingService.resolveCourtReportScope(actor, {
      facilityId,
      courtId
    });
    const query = {};

    if (facilityId) {
      query.facility_id = facilityId;
    } else if (scope.facilityIds.length > 0) {
      query.facility_id = { $in: scope.facilityIds };
    }
    if (courtId) query.court_id = courtId;
    if (filters.status) {
      if (!['ACTIVE', 'CANCELLED'].includes(filters.status)) {
        throw this._businessError(
          'Invalid status filter',
          400,
          'INVALID_FILTER'
        );
      }
      query.status = filters.status;
    }

    const dateFrom = this._date(filters.dateFrom, 'dateFrom');
    const dateTo = this._date(filters.dateTo, 'dateTo');
    if (dateFrom || dateTo) {
      if (dateFrom) query.end_time = { $gt: dateFrom };
      if (dateTo) query.start_time = { $lt: dateTo };
    }

    const blocks = await CourtBlock.find(query)
      .sort({ start_time: 1, created_at: -1 });
    return blocks.map(block => this._format(block));
  }

  async update(id, data, actor) {
    if (!mongoose.isValidObjectId(id)) {
      throw this._businessError('Invalid court block id', 400, 'INVALID_ID');
    }
    const existing = await CourtBlock.findById(id);
    if (!existing) {
      throw this._businessError(
        'Court block not found',
        404,
        'COURT_BLOCK_NOT_FOUND'
      );
    }

    const facilityId = this._objectId(
      data.facilityId,
      'facilityId'
    ) || existing.facility_id.toString();
    const courtId = Object.prototype.hasOwnProperty.call(data, 'courtId')
      ? this._objectId(data.courtId, 'courtId')
      : existing.court_id?.toString() || null;
    await this._assertScope(actor, facilityId, courtId);
    await this._assertScope(
      actor,
      existing.facility_id.toString(),
      existing.court_id?.toString() || null
    );

    const startTime = this._date(data.startTime, 'startTime')
      || existing.start_time;
    const endTime = this._date(data.endTime, 'endTime')
      || existing.end_time;
    if (startTime >= endTime) {
      throw this._businessError(
        'startTime must be before endTime',
        400,
        'INVALID_TIME_RANGE'
      );
    }

    existing.facility_id = facilityId;
    existing.court_id = courtId;
    existing.start_time = startTime;
    existing.end_time = endTime;
    if (data.reason !== undefined) {
      existing.reason = typeof data.reason === 'string'
        ? data.reason.trim()
        : '';
    }
    if (data.type !== undefined) existing.type = this._type(data.type);
    if (data.status !== undefined) {
      if (!['ACTIVE', 'CANCELLED'].includes(data.status)) {
        throw this._businessError(
          'Invalid court block status',
          400,
          'INVALID_STATUS'
        );
      }
      existing.status = data.status;
    }

    await existing.save();
    return this._format(existing);
  }

  async cancel(id, actor) {
    return await this.update(id, { status: 'CANCELLED' }, actor);
  }
}

module.exports = new CourtBlockService();
