const Booking = require('../models/booking.model');

const courtPopulate = {
  path: 'court_id',
  populate: [
    { path: 'facility_id' },
    { path: 'sport_id' }
  ]
};

class BookingRepository {
  async create(bookingData) {
    const booking = new Booking(bookingData);
    return await booking.save();
  }

  async findById(id) {
    return await Booking.findById(id)
      .populate('user_id')
      .populate(courtPopulate);
  }

  async findMany(query, skip, limit) {
    return await Booking.find(query)
      .skip(skip)
      .limit(limit)
      .populate('user_id')
      .populate(courtPopulate)
      .sort({ created_at: -1 });
  }

  async count(query) {
    return await Booking.countDocuments(query);
  }

  async findBlockingBookingsForCourtDate(courtId, bookingDate) {
    return await Booking.find({
      court_id: courtId,
      booking_date: bookingDate,
      status: { $in: ['PENDING', 'CONFIRMED'] }
    }).select('start_minutes end_minutes fixed_schedule_id is_fixed_schedule status');
  }

  async findFutureBlockingBookingSummary(
    courtId,
    bookingDate,
    currentMinutes,
    affectedIdLimit = 50
  ) {
    const query = {
      court_id: courtId,
      status: { $in: ['PENDING', 'CONFIRMED'] },
      $or: [
        { booking_date: { $gt: bookingDate } },
        {
          booking_date: bookingDate,
          end_minutes: { $gt: currentMinutes }
        }
      ]
    };
    const [futureBookingCount, affectedBookings] = await Promise.all([
      Booking.countDocuments(query),
      Booking.find(query)
        .select('_id')
        .sort({ booking_date: 1, start_minutes: 1 })
        .limit(affectedIdLimit)
        .lean()
    ]);
    return {
      futureBookingCount,
      affectedBookingIds: affectedBookings.map(booking =>
        booking._id.toString()
      )
    };
  }

  async updateStatus(id, status) {
    return await Booking.findByIdAndUpdate(id, { status }, { new: true })
      .populate('user_id')
      .populate(courtPopulate);
  }

  async updateById(id, updates) {
    return await Booking.findByIdAndUpdate(id, updates, { new: true })
      .populate('user_id')
      .populate(courtPopulate);
  }

  async cancelByCustomerIfAllowed(id, userId, expectedStatus, updates) {
    return await Booking.findOneAndUpdate(
      {
        _id: id,
        user_id: userId,
        status: expectedStatus
      },
      updates,
      { new: true }
    )
      .populate('user_id')
      .populate(courtPopulate);
  }

  async cancelIfStatusMatches(id, expectedStatus, updates, userId = null) {
    const query = {
      _id: id,
      status: expectedStatus
    };
    if (userId) {
      query.user_id = userId;
    }

    return await Booking.findOneAndUpdate(query, updates, { new: true })
      .populate('user_id')
      .populate(courtPopulate);
  }
}

module.exports = new BookingRepository();
