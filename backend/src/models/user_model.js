const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    student_id: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      index: true,
    },
    full_name: {
      type: String,
      required: true,
      trim: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
      index: true,
    },
    password_hash: {
      type: String,
      required: true,
    },
    phone: {
      type: String,
      trim: true,
      default: '',
    },
    role_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Role',
      required: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'BLOCKED'],
      default: 'ACTIVE',
      index: true,
    },
    is_inside: {
      type: Boolean,
      default: false,
      index: true,
    },
    last_check_in: {
      type: Date,
      default: null,
    },
    deleted_at: {
      type: Date,
      default: null,
      index: true,
    },
    avatar_url: {
      type: String,
      default: '',
    },
    device_token: {
      type: String,
      default: '',
    },
    refresh_token: {
      type: String,
      default: '',
    },
  },
  {
    collection: 'users',
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Virtual aliases để tương thích mã nguồn hiện tại trong quá trình refactor
userSchema.virtual('studentId')
  .get(function () { return this.student_id; })
  .set(function (v) { this.student_id = v; });

userSchema.virtual('name')
  .get(function () { return this.full_name; })
  .set(function (v) { this.full_name = v; });

userSchema.virtual('password')
  .get(function () { return this.password_hash; })
  .set(function (v) { this.password_hash = v; });

userSchema.virtual('passwordHash')
  .get(function () { return this.password_hash; });

userSchema.virtual('isInsideLibrary')
  .get(function () { return this.is_inside; })
  .set(function (v) { this.is_inside = v; });

userSchema.virtual('avatarUrl')
  .get(function () { return this.avatar_url; })
  .set(function (v) { this.avatar_url = v; });

userSchema.virtual('deviceToken')
  .get(function () { return this.device_token; })
  .set(function (v) { this.device_token = v; });

userSchema.virtual('refreshToken')
  .get(function () { return this.refresh_token; })
  .set(function (v) { this.refresh_token = v; });

userSchema.virtual('deletedAt')
  .get(function () { return this.deleted_at; })
  .set(function (v) { this.deleted_at = v; });

userSchema.virtual('roleId')
  .get(function () { return this.role_id; });

userSchema.virtual('role')
  .get(function () {
    if (this.role_id && typeof this.role_id === 'object' && this.role_id.role_name) {
      return this.role_id.role_name.toLowerCase();
    }
    return 'student';
  });

// Ẩn thông tin nhạy cảm và format camelCase chuẩn cho Flutter client
userSchema.methods.toSafeObject = function () {
  const obj = this.toObject();
  delete obj.password_hash;
  delete obj.password;
  delete obj.refresh_token;
  delete obj.refreshToken;

  return {
    _id: obj._id,
    id: obj._id,
    studentId: obj.student_id,
    name: obj.full_name,
    fullName: obj.full_name,
    email: obj.email,
    phone: obj.phone,
    role: obj.role_id && obj.role_id.role_name ? obj.role_id.role_name.toLowerCase() : 'student',
    roleName: obj.role_id && obj.role_id.role_name ? obj.role_id.role_name : 'STUDENT',
    status: obj.status,
    isInsideLibrary: obj.is_inside,
    isInside: obj.is_inside,
    avatarUrl: obj.avatar_url,
    lastCheckIn: obj.last_check_in,
    deletedAt: obj.deleted_at,
    createdAt: obj.created_at,
    updatedAt: obj.updated_at,
  };
};

module.exports = mongoose.model('User', userSchema);
