const mongoose = require('mongoose');

/**
 * Collection Schema
 * Groups multiple saved requests for organisation.
 */
const collectionSchema = new mongoose.Schema(
    {
        name: {
            type: String,
            required: [true, 'Collection name is required'],
            trim: true,
        },
        description: {
            type: String,
            trim: true,
            default: '',
        },
        // Owner reference
        userId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            required: true,
        },
        // Embedded request references (populated via Request model)
        requests: [
            {
                type: mongoose.Schema.Types.ObjectId,
                ref: 'Request',
            },
        ],
        color: {
            type: String,
            default: '#6C63FF', // accent purple
        },
    },
    { timestamps: true }
);

module.exports = mongoose.model('Collection', collectionSchema);
