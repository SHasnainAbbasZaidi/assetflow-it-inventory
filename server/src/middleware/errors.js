export function notFound(req, res) {
  res.status(404).json({ error: { code: 'NOT_FOUND', message: `No route for ${req.method} ${req.path}` } });
}

export function errorHandler(error, req, res, next) { // eslint-disable-line no-unused-vars
  const status = error.status || (error.code === 'P2002' ? 409 : error.code === 'P2025' ? 404 : 500);
  if (status >= 500) console.error(error);
  res.status(status).json({
    error: {
      code: error.code || (status === 500 ? 'INTERNAL_ERROR' : 'REQUEST_ERROR'),
      message: status === 500 ? 'An unexpected server error occurred.' : error.message,
      details: error.details,
    },
  });
}

export function httpError(status, message, code = 'REQUEST_ERROR', details) {
  const error = new Error(message);
  Object.assign(error, { status, code, details });
  return error;
}
