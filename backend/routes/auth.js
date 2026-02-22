const express = require('express');
const router = express.Router();
const { signup, login, getMe, signupValidation, loginValidation } = require('../controllers/authController');
const { protect } = require('../middleware/auth');

// @route   POST /api/auth/signup
// @desc    Register a new user
// @access  Public
router.post('/signup', signupValidation, signup);

// @route   POST /api/auth/login
// @desc    Login and get token
// @access  Public
router.post('/login', loginValidation, login);

// @route   GET /api/auth/me
// @desc    Get current user
// @access  Private
router.get('/me', protect, getMe);

module.exports = router;
