const FixedSchedule = require('../models/fixed-schedule.model');

class FixedScheduleRepository {
  async create(scheduleData, options = {}) {
    const schedule = new FixedSchedule(scheduleData);
    return await schedule.save(options);
  }

  async findById(id, options = {}) {
    return await FixedSchedule.findById(id)
      .session(options.session || null)
      .populate('user_id')
      .populate('sport_id')
      .populate('facility_id')
      .populate({
        path: 'court_id',
        populate: { path: 'facility_id' }
      });
  }

  async findMany(query, skip, limit, options = {}) {
    return await FixedSchedule.find(query)
      .session(options.session || null)
      .skip(skip)
      .limit(limit)
      .populate('user_id')
      .populate('sport_id')
      .populate('facility_id')
      .populate({
        path: 'court_id',
        populate: { path: 'facility_id' }
      })
      .sort({ created_at: -1 });
  }

  async count(query) {
    return await FixedSchedule.countDocuments(query);
  }

  async updateById(id, updateData, options = {}) {
    return await FixedSchedule.findByIdAndUpdate(id, updateData, {
      new: true,
      session: options.session
    })
      .populate('user_id')
      .populate('sport_id')
      .populate('facility_id')
      .populate({
        path: 'court_id',
        populate: { path: 'facility_id' }
      });
  }

  async findOne(query, options = {}) {
    return await FixedSchedule.findOne(query)
      .session(options.session || null)
      .populate('user_id')
      .populate('sport_id')
      .populate('facility_id')
      .populate({
        path: 'court_id',
        populate: { path: 'facility_id' }
      });
  }

  async findActiveSchedules() {
    return await FixedSchedule.find({ status: 'ACTIVE' })
      .populate('user_id')
      .populate('sport_id')
      .populate('facility_id')
      .populate({
        path: 'court_id',
        populate: { path: 'facility_id' }
      });
  }

  async findActiveConflictsForBooking({
    facilityId,
    courtId,
    bookingDate,
    startMinutes,
    endMinutes
  }, options = {}) {
    const query = {
      court_id: courtId,
      status: 'ACTIVE',
      start_date: { $lte: bookingDate },
      start_minutes: { $lt: endMinutes },
      end_minutes: { $gt: startMinutes },
      $or: [
        { end_date: null },
        { end_date: { $gte: bookingDate } }
      ]
    };

    if (facilityId) {
      query.facility_id = facilityId;
    }

    return await FixedSchedule.find(query)
      .session(options.session || null);
  }

  async findActiveForCourtDate({
    facilityId,
    courtId,
    bookingDate
  }, options = {}) {
    const query = {
      court_id: courtId,
      status: 'ACTIVE',
      start_date: { $lte: bookingDate },
      $or: [
        { end_date: null },
        { end_date: { $gte: bookingDate } }
      ]
    };

    if (facilityId) {
      query.facility_id = facilityId;
    }

    return await FixedSchedule.find(query)
      .session(options.session || null)
      .select('start_minutes end_minutes frequency days_of_week');
  }

  async updatePendingApprovalById(id, updateData, options = {}) {
    return await FixedSchedule.findOneAndUpdate(
      { _id: id, status: 'PENDING_APPROVAL' },
      updateData,
      { new: true, session: options.session }
    )
      .populate('user_id')
      .populate('sport_id')
      .populate('facility_id')
      .populate({
        path: 'court_id',
        populate: { path: 'facility_id' }
      });
  }
}

module.exports = new FixedScheduleRepository();
