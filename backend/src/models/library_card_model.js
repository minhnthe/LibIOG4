const mongoose = require('mongoose');

const libraryCardSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    qr_code_hash: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    issue_date: {
      type: Date,
      default: Date.now,
      required: true,
    },
    expiry_date: {
      type: Date,
      required: true,
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'EXPIRED', 'LOCKED'],
      default: 'ACTIVE',
    },
  },
  {
    collection: 'library_cards',
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  }
);

// Method kiểm tra hết hạn thẻ
libraryCardSchema.methods.isExpired = function () {
  return new Date() > this.expiry_date;
};

// Virtuals for camelCase API compatibility
libraryCardSchema.virtual('userId').get(function () {
  return this.user_id;
});
libraryCardSchema.virtual('qrCodeHash').get(function () {
  return this.qr_code_hash;
});
libraryCardSchema.virtual('issueDate').get(function () {
  return this.issue_date;
});
libraryCardSchema.virtual('expiryDate').get(function () {
  return this.expiry_date;
});

module.exports = mongoose.model('LibraryCard', libraryCardSchema);
