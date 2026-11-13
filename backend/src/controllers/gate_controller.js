const Gate = require('../models/gate_model');

const VALID_STATUSES = ['ACTIVE', 'INACTIVE', 'MAINTENANCE'];

function formatGate(gate) {
  return {
    id: gate._id,
    gateName: gate.gate_name,
    location: gate.location,
    status: gate.status,
    createdAt: gate.created_at,
    updatedAt: gate.updated_at,
  };
}

// GET /api/admin/gates
async function listGates(req, res, next) {
  try {
    const gates = await Gate.find().sort({ gate_name: 1 });
    res.json({ success: true, data: gates.map(formatGate) });
  } catch (err) {
    next(err);
  }
}

// POST /api/admin/gates
async function createGate(req, res, next) {
  try {
    const gateName = (req.body.gateName || req.body.gate_name || '').trim();
    const location = (req.body.location || '').trim();
    const status = (req.body.status || 'ACTIVE').toUpperCase();

    if (!gateName) {
      return res.status(400).json({
        success: false,
        errorCode: 'INVALID_INPUT',
        message: 'Tên cổng bắt buộc',
      });
    }
    if (!VALID_STATUSES.includes(status)) {
      return res.status(400).json({
        success: false,
        errorCode: 'INVALID_STATUS',
        message: 'Trạng thái cổng không hợp lệ',
      });
    }

    const existing = await Gate.findOne({ gate_name: gateName });
    if (existing) {
      return res.status(409).json({
        success: false,
        errorCode: 'DUPLICATE_GATE',
        message: 'Tên cổng đã tồn tại',
      });
    }

    const gate = await Gate.create({ gate_name: gateName, location, status });
    res.status(201).json({ success: true, data: formatGate(gate) });
  } catch (err) {
    next(err);
  }
}

// PATCH /api/admin/gates/:id
async function updateGate(req, res, next) {
  try {
    const update = {};
    if (req.body.gateName !== undefined || req.body.gate_name !== undefined) {
      const gateName = (req.body.gateName || req.body.gate_name || '').trim();
      if (!gateName) {
        return res.status(400).json({
          success: false,
          errorCode: 'INVALID_INPUT',
          message: 'Tên cổng bắt buộc',
        });
      }
      update.gate_name = gateName;
    }
    if (req.body.location !== undefined) update.location = String(req.body.location).trim();
    if (req.body.status !== undefined) {
      const status = String(req.body.status).toUpperCase();
      if (!VALID_STATUSES.includes(status)) {
        return res.status(400).json({
          success: false,
          errorCode: 'INVALID_STATUS',
          message: 'Trạng thái cổng không hợp lệ',
        });
      }
      update.status = status;
    }

    const gate = await Gate.findByIdAndUpdate(
      req.params.id,
      { $set: update },
      { new: true, runValidators: true }
    );
    if (!gate) {
      return res.status(404).json({
        success: false,
        errorCode: 'GATE_NOT_FOUND',
        message: 'Không tìm thấy cổng',
      });
    }

    res.json({ success: true, data: formatGate(gate) });
  } catch (err) {
    if (err.code === 11000) {
      return res.status(409).json({
        success: false,
        errorCode: 'DUPLICATE_GATE',
        message: 'Tên cổng đã tồn tại',
      });
    }
    next(err);
  }
}

module.exports = { listGates, createGate, updateGate };
