const mongoose = require('mongoose');

/**
 * Request Schema
 * A saved API request belonging to a collection.
 */
const requestSchema = new mongoose.Schema(
    {
        name: {
            type: String,
            required: [true, 'Request name is required'],
            trim: true,
        },
        method: {
            type: String,
            required: true,
            enum: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'],
            default: 'GET',
        },
        url: {
            type: String,
            required: [true, 'URL is required'],
            trim: true,
        },
        headers: {
            type: Map,
            of: String,
            default: {},
        },
        params: {
            type: Map,
            of: String,
            default: {},
        },
        body: {
            type: mongoose.Schema.Types.Mixed,
            default: null,
        },
        bodyType: {
            type: String,
            enum: ['none', 'json', 'form-data', 'raw'],
            default: 'none',
        },
        auth: {
            type: {
                type: String,
                enum: ['none', 'bearer', 'basic'],
                default: 'none',
            },
            token: { type: String, default: '' },
            username: { type: String, default: '' },
            password: { type: String, default: '' },
        },
        collectionId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Collection',
            default: null,
        },
        userId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            required: true,
        },
    },
    { timestamps: true }
);

module.exports = mongoose.model('Request', requestSchema);
