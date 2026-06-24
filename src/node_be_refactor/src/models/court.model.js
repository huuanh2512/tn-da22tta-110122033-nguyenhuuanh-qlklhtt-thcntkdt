const mongoose = require('mongoose');

const courtSlotSchema = new mongoose.Schema({
  slot_index: { type: Number, required: true },
  start_minutes: { type: Number, required: true },
  end_minutes: { type: Number, required: true },
  is_available: { type: Boolean },
  mode: { type: String, default: 'AVAILABLE' }
}, { _id: false });

const slotConfigSchema = new mongoose.Schema({
  opening_minutes: { type: Number, default: 360 }, // Mặc định 6:00 AM (6 * 60)
  closing_minutes: { type: Number, default: 1320 }, // Mặc định 22:00 PM (22 * 60)
  slot_duration_minutes: { type: Number, default: 60 },
  slots: { type: [courtSlotSchema], default: [] }
}, { _id: false, timestamps: { updatedAt: 'updated_at' } });

const courtSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  facility_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Facility',
    required: true
  },
  sport_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Sport',
    required: true
  },
  code: {
    type: String,
    default: ''
  },
  status: {
    type: String,
    enum: ['ACTIVE', 'INACTIVE', 'MAINTENANCE'],
    default: 'ACTIVE'
  },
  price_per_hour: {
    type: Number,
    default: 0
  },
  slot_config: {
    type: slotConfigSchema,
    default: () => ({})
  }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

const Court = mongoose.model('Court', courtSchema);

module.exports = Court;
