const mongoose = require('mongoose');

/**
 * History Schema
 * Logs every API request sent through the proxy endpoint.
 */
const historySchema = new mongoose.Schema(
    {
        userId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            required: true,
        },
        method: {
            type: String,
            required: true,
            enum: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'],
        },
        url: { type: String, required: true },
        requestHeaders: { type: mongoose.Schema.Types.Mixed, default: {} },
        requestBody: { type: mongoose.Schema.Types.Mixed, default: null },
        statusCode: { type: Number, default: null },
        responseHeaders: { type: mongoose.Schema.Types.Mixed, default: {} },
        responseBody: { type: mongoose.Schema.Types.Mixed, default: null },
        responseTime: { type: Number, default: 0 }, // milliseconds
        isError: { type: Boolean, default: false },
        errorMessage: { type: String, default: '' },
    },
    { timestamps: true }
);

// Auto-delete history older than 30 days
historySchema.index({ createdAt: 1 }, { expireAfterSeconds: 2592000 });

module.exports = mongoose.model('History', historySchema);
