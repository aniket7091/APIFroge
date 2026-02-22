const { validationResult } = require('express-validator');

/**
 * Validation Middleware
 * Reads express-validator results and returns 400 with error messages.
 */
const validate = (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({
            success: false,
            message: 'Validation failed',
            errors: errors.array().map((e) => ({ field: e.path, message: e.msg })),
        });
    }
    next();
};

module.exports = validate;
