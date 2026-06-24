const mongoose = require('mongoose');

const facilitySchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  address: {
    city: {
      type: String,
      default: ''
    },
    full: {
      type: String,
      default: ''
    }
  },
  active: {
    type: Boolean,
    default: true
  },
  staff_ids: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: []
  }]
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

const Facility = mongoose.model('Facility', facilitySchema);

module.exports = Facility;