const mongoose = require('mongoose');

const checkInLogSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    card_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'LibraryCard',
      default: null,
      index: true,
    },
    gate_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gate',
      default: null,
      index: true,
    },
    check_in_time: {
      type: Date,
      required: true,
      index: true,
    },
    check_out_time: {
      type: Date,
      default: null,
    },
    total_minutes: {
      type: Number,
      default: null,
    },
    action_type: {
      type: String,
      enum: ['CHECK_IN', 'CHECK_OUT'],
      default: 'CHECK_IN',
    },
    status: {
      type: String,
      enum: ['INSIDE', 'COMPLETED'],
      default: 'INSIDE',
      index: true,
    },
    sync_status: {
      type: String,
      enum: ['SYNCED', 'PENDING'],
      default: 'SYNCED',
      index: true,
    },
    local_id: {
      type: String,
      default: '',
      index: true,
    },
  },
  {
    collection: 'check_in_logs',
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Compound Index cho truy vấn hiệu năng cao
checkInLogSchema.index({ user_id: 1, check_in_time: -1 });
checkInLogSchema.index({ check_in_time: -1, status: 1 });

// Tự động tính total_minutes khi cập nhật check_out_time
checkInLogSchema.pre('save', function (next) {
  if (this.check_out_time && this.check_in_time) {
    this.total_minutes = Math.round((this.check_out_time - this.check_in_time) / 60000);
    this.status = 'COMPLETED';
    this.action_type = 'CHECK_OUT';
  }
  next();
});

// Virtual aliases để tương thích ngược với code cũ trong quá trình refactor
checkInLogSchema.virtual('userId')
  .get(function () { return this.user_id; })
  .set(function (v) { this.user_id = v; });

checkInLogSchema.virtual('cardId')
  .get(function () { return this.card_id; })
  .set(function (v) { this.card_id = v; });

checkInLogSchema.virtual('gateId')
  .get(function () { return this.gate_id; })
  .set(function (v) { this.gate_id = v; });

checkInLogSchema.virtual('checkInTime')
  .get(function () { return this.check_in_time; })
  .set(function (v) { this.check_in_time = v; });

checkInLogSchema.virtual('checkOutTime')
  .get(function () { return this.check_out_time; })
  .set(function (v) { this.check_out_time = v; });

checkInLogSchema.virtual('durationMinutes')
  .get(function () { return this.total_minutes; })
  .set(function (v) { this.total_minutes = v; });

checkInLogSchema.virtual('totalMinutes')
  .get(function () { return this.total_minutes; });

checkInLogSchema.virtual('actionType')
  .get(function () { return this.action_type; })
  .set(function (v) { this.action_type = v; });

checkInLogSchema.virtual('syncStatus')
  .get(function () { return this.sync_status; })
  .set(function (v) { this.sync_status = v; });

checkInLogSchema.virtual('localId')
  .get(function () { return this.local_id; })
  .set(function (v) { this.local_id = v; });

module.exports = mongoose.model('CheckInLog', checkInLogSchema);
