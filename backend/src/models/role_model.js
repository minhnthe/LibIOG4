const mongoose = require('mongoose');

const roleSchema = new mongoose.Schema(
  {
    role_name: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      enum: ['STUDENT', 'LIBRARIAN', 'ADMIN'],
    },
    description: {
      type: String,
      default: '',
      trim: true,
    },
  },
  {
    collection: 'roles',
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
  }
);

// Virtual for camelCase API compatibility
roleSchema.virtual('roleName').get(function () {
  return this.role_name;
});

module.exports = mongoose.model('Role', roleSchema);
