const jwt = require('jsonwebtoken');
const { body } = require('express-validator');
const User = require('../models/User');
const validate = require('../middleware/validate');

/**
 * Generate a signed JWT for the given user ID.
 */
const generateToken = (id) =>
    jwt.sign({ id }, process.env.JWT_SECRET, {
        expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    });

// Validation rules
const signupValidation = [
    body('name').trim().isLength({ min: 2 }).withMessage('Name must be at least 2 characters'),
    body('email').isEmail().withMessage('Provide a valid email'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
    validate,
];

const loginValidation = [
    body('email').isEmail().withMessage('Provide a valid email'),
    body('password').notEmpty().withMessage('Password is required'),
    validate,
];

/**
 * POST /api/auth/signup
 * Register a new user.
 */
const signup = async (req, res, next) => {
    try {
        const { name, email, password } = req.body;

        // Check duplicate
        const existing = await User.findOne({ email });
        if (existing) {
            return res.status(409).json({ success: false, message: 'Email already registered' });
        }

        const user = await User.create({ name, email, password });
        const token = generateToken(user._id);

        res.status(201).json({
            success: true,
            message: 'Account created successfully',
            token,
            user: { id: user._id, name: user.name, email: user.email },
        });
    } catch (error) {
        next(error);
    }
};

/**
 * POST /api/auth/login
 * Authenticate user and return JWT.
 */
const login = async (req, res, next) => {
    try {
        const { email, password } = req.body;

        const user = await User.findOne({ email }).select('+password');
        if (!user || !(await user.comparePassword(password))) {
            return res.status(401).json({ success: false, message: 'Invalid email or password' });
        }

        const token = generateToken(user._id);

        res.json({
            success: true,
            message: 'Login successful',
            token,
            user: { id: user._id, name: user.name, email: user.email },
        });
    } catch (error) {
        next(error);
    }
};

/**
 * GET /api/auth/me
 * Return the current authenticated user.
 */
const getMe = async (req, res) => {
    res.json({
        success: true,
        user: { id: req.user._id, name: req.user.name, email: req.user.email },
    });
};

module.exports = { signup, login, getMe, signupValidation, loginValidation };
