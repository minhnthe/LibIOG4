require('dotenv').config();
const app = require('./src/app');
const connectDB = require('./src/config/db');
const SystemConfig = require('./src/models/system_config_model');
const { bootstrapDemoAccounts } = require('./src/utils/bootstrap_accounts');

const PORT = process.env.PORT || 5000;

async function startServer() {
  await connectDB();

  await SystemConfig.seedDefaults();
  console.log('System configs seeded.');

  // Tự động đảm bảo tài khoản demo (ADMIN01, LIB01, HE190001) luôn sẵn sàng
  await bootstrapDemoAccounts();

  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
    console.log(`ENV: ${process.env.NODE_ENV || 'development'}`);
  });
}

startServer().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
