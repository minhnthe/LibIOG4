const mongoose = require('mongoose');

const gateSchema = new mongoose.Schema(
  {
    gate_name: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    location: {
      type: String,
      default: '',
      trim: true,
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'INACTIVE', 'MAINTENANCE'],
      default: 'ACTIVE',
    },
  },
  {
    collection: 'gates',
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  }
);

// Virtual for camelCase API compatibility
gateSchema.virtual('gateName').get(function () {
  return this.gate_name;
});

module.exports = mongoose.model('Gate', gateSchema);
