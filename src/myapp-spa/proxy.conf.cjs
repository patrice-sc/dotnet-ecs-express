module.exports = {
  '/api/**': {
    target: process.env.API_URL || 'http://localhost:5000',
    secure: false,
  },
};
