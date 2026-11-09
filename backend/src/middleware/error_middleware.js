function errorHandler(err, req, res, next) {
  console.error(err.stack);
  const statusCode = res.statusCode !== 200 ? res.statusCode : 500;
  res.status(statusCode).json({
    success: false,
    errorCode: 'INTERNAL_ERROR',
    message: err.message || 'Lỗi server',
    stack: process.env.NODE_ENV === 'production' ? undefined : err.stack,
  });
}

module.exports = { errorHandler };
