const Payment = require('../models/payment.model');

const bookingPopulate = {
  path: 'booking_id',
  populate: [
    {
      path: 'court_id',
      populate: [
        { path: 'sport_id' },
        { path: 'facility_id' }
      ]
    },
    { path: 'user_id' }
  ]
};

class PaymentRepository {
  async create(paymentData, options = {}) {
    const payment = new Payment(paymentData);
    return await payment.save(options);
  }

  async findById(id, options = {}) {
    return await Payment.findById(id)
      .session(options.session || null)
      .populate('user_id')
      .populate(bookingPopulate);
  }

  async findMany(query, skip, limit, options = {}) {
    return await Payment.find(query)
      .session(options.session || null)
      .skip(skip)
      .limit(limit)
      .populate('user_id')
      .populate(bookingPopulate)
      .sort({ created_at: -1 });
  }

  async count(query) {
    return await Payment.countDocuments(query);
  }

  async findOne(query, options = {}) {
    return await Payment.findOne(query)
      .session(options.session || null)
      .populate('user_id')
      .populate(bookingPopulate);
  }

  async findRawOne(query, options = {}) {
    return await Payment.findOne(query).session(options.session || null);
  }

  async findManyRaw(query, options = {}) {
    return await Payment.find(query).session(options.session || null);
  }

  async updateStatus(id, updateData, options = {}) {
    return await Payment.findByIdAndUpdate(id, updateData, {
      new: true,
      session: options.session
    })
      .populate('user_id')
      .populate(bookingPopulate);
  }

  async updateOne(query, updateData, options = {}) {
    return await Payment.findOneAndUpdate(query, updateData, {
      new: true,
      session: options.session
    })
      .populate('user_id')
      .populate(bookingPopulate);
  }

  async updateByBookingId(bookingId, updateData, options = {}) {
    return await Payment.findOneAndUpdate(
      { booking_id: bookingId },
      updateData,
      {
        new: true,
        session: options.session
      }
    )
      .populate('user_id')
      .populate(bookingPopulate);
  }

  async updateMany(query, updateData, options = {}) {
    return await Payment.updateMany(query, updateData, {
      session: options.session
    });
  }
}

module.exports = new PaymentRepository();
