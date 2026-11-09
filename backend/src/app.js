const express = require('express');
const cors    = require('cors');

const authRoutes    = require('./routes/auth_routes');
const userRoutes    = require('./routes/user_routes');
const checkinRoutes = require('./routes/checkin_routes');
const historyRoutes = require('./routes/history_routes');
const configRoutes  = require('./routes/config_routes');
const adminRoutes   = require('./routes/admin_routes');
const { errorHandler } = require('./middleware/error_middleware');

const app = express();

app.use(cors());
app.use(express.json());

// ── Health check ──
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', service: 'library-access-backend', timestamp: new Date().toISOString() });
});

// ── Routes ──
app.use('/api/auth',    authRoutes);
app.use('/api/users',   userRoutes);
app.use('/api/checkin', checkinRoutes);
app.use('/api/history', historyRoutes);
app.use('/api/config',  configRoutes);
app.use('/api/admin',   adminRoutes);

// ── Error handler (luôn để cuối) ──
app.use(errorHandler);

module.exports = app;
