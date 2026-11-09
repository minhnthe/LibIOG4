const mongoose = require('mongoose');

const systemConfigSchema = new mongoose.Schema(
  {
    config_key: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      index: true,
    },
    config_value: {
      type: String,
      required: true,
      trim: true,
    },
    data_type: {
      type: String,
      enum: ['INT', 'STRING', 'TIME', 'BOOLEAN'],
      default: 'STRING',
      required: true,
    },
    description: {
      type: String,
      default: '',
      trim: true,
    },
    updated_at: {
      type: Date,
      default: Date.now,
    },
  },
  {
    collection: 'system_configs',
    timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' },
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Virtuals cho camelCase API & tương thích ngược
systemConfigSchema.virtual('key')
  .get(function () { return this.config_key; })
  .set(function (v) { this.config_key = v; });

systemConfigSchema.virtual('value')
  .get(function () { return this.config_value; })
  .set(function (v) { this.config_value = v; });

systemConfigSchema.virtual('configKey')
  .get(function () { return this.config_key; });

systemConfigSchema.virtual('configValue')
  .get(function () { return this.config_value; });

systemConfigSchema.virtual('dataType')
  .get(function () { return this.data_type; });

// Seed cấu hình mặc định theo đặc tả thiết kế gốc
systemConfigSchema.statics.seedDefaults = async function () {
  const defaults = [
    {
      config_key: 'MAX_CAPACITY',
      config_value: '200',
      data_type: 'INT',
      description: 'Sức chứa tối đa của thư viện',
    },
    {
      config_key: 'OPEN_TIME',
      config_value: '07:30',
      data_type: 'TIME',
      description: 'Giờ mở cửa thư viện',
    },
    {
      config_key: 'CLOSE_TIME',
      config_value: '21:30',
      data_type: 'TIME',
      description: 'Giờ đóng cửa thư viện',
    },
    {
      config_key: 'WARNING_MINUTES_BEFORE_CLOSE',
      config_value: '30',
      data_type: 'INT',
      description: 'Số phút cảnh báo trước khi đóng cửa',
    },
    {
      config_key: 'MAX_SESSION_HOURS',
      config_value: '8',
      data_type: 'INT',
      description: 'Số giờ tối đa cho một phiên truy cập',
    },
    {
      config_key: 'ALLOWED_DAYS',
      config_value: 'Mon,Tue,Wed,Thu,Fri,Sat',
      data_type: 'STRING',
      description: 'Các ngày mở cửa trong tuần',
    },
    {
      config_key: 'MAINTENANCE_MODE',
      config_value: 'false',
      data_type: 'BOOLEAN',
      description: 'Trạng thái bảo trì hệ thống',
    },
    {
      config_key: 'MAINTENANCE_MESSAGE',
      config_value: 'Thư viện đang tạm thời bảo trì, vui lòng quay lại sau.',
      data_type: 'STRING',
      description: 'Nội dung thông báo bảo trì',
    },
    // Giữ thêm alias camelCase để không làm hỏng controller chưa refactor ở Phase 1
    {
      config_key: 'maxCapacity',
      config_value: '200',
      data_type: 'INT',
      description: 'Alias maxCapacity',
    },
    {
      config_key: 'openTime',
      config_value: '07:30',
      data_type: 'TIME',
      description: 'Alias openTime',
    },
    {
      config_key: 'closeTime',
      config_value: '21:30',
      data_type: 'TIME',
      description: 'Alias closeTime',
    },
    {
      config_key: 'warningMinutesBeforeClose',
      config_value: '30',
      data_type: 'INT',
      description: 'Alias warningMinutesBeforeClose',
    },
    {
      config_key: 'maxSessionHours',
      config_value: '8',
      data_type: 'INT',
      description: 'Alias maxSessionHours',
    },
    {
      config_key: 'allowedDays',
      config_value: 'Mon,Tue,Wed,Thu,Fri,Sat',
      data_type: 'STRING',
      description: 'Alias allowedDays',
    },
    {
      config_key: 'maintenanceMode',
      config_value: 'false',
      data_type: 'BOOLEAN',
      description: 'Alias maintenanceMode',
    },
    {
      config_key: 'maintenanceMessage',
      config_value: '',
      data_type: 'STRING',
      description: 'Alias maintenanceMessage',
    },
  ];

  for (const item of defaults) {
    await this.findOneAndUpdate(
      { config_key: item.config_key },
      { ...item, updated_at: new Date() },
      { upsert: true }
    );
  }
};

module.exports = mongoose.model('SystemConfig', systemConfigSchema);
