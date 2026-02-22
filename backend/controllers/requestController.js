const Request = require('../models/Request');
const Collection = require('../models/Collection');

/**
 * GET /api/requests
 * Fetch all saved requests. Optionally filter by collectionId.
 */
const getRequests = async (req, res, next) => {
    try {
        const filter = { userId: req.user._id };
        if (req.query.collectionId) filter.collectionId = req.query.collectionId;

        const requests = await Request.find(filter).sort({ updatedAt: -1 });
        res.json({ success: true, data: requests });
    } catch (error) { next(error); }
};

/**
 * POST /api/requests
 * Save a new API request.
 */
const createRequest = async (req, res, next) => {
    try {
        const payload = { ...req.body, userId: req.user._id };
        const request = await Request.create(payload);

        // Add to collection if provided
        if (payload.collectionId) {
            await Collection.findByIdAndUpdate(
                payload.collectionId,
                { $addToSet: { requests: request._id } }
            );
        }

        res.status(201).json({ success: true, data: request });
    } catch (error) { next(error); }
};

/**
 * PUT /api/requests/:id
 * Update an existing saved request.
 */
const updateRequest = async (req, res, next) => {
    try {
        const request = await Request.findOneAndUpdate(
            { _id: req.params.id, userId: req.user._id },
            { $set: req.body },
            { new: true, runValidators: true }
        );
        if (!request) return res.status(404).json({ success: false, message: 'Request not found' });
        res.json({ success: true, data: request });
    } catch (error) { next(error); }
};

/**
 * DELETE /api/requests/:id
 * Delete a saved request.
 */
const deleteRequest = async (req, res, next) => {
    try {
        const request = await Request.findOneAndDelete({
            _id: req.params.id, userId: req.user._id,
        });
        if (!request) return res.status(404).json({ success: false, message: 'Request not found' });

        // Remove from collection
        if (request.collectionId) {
            await Collection.findByIdAndUpdate(
                request.collectionId,
                { $pull: { requests: request._id } }
            );
        }

        res.json({ success: true, message: 'Request deleted' });
    } catch (error) { next(error); }
};

module.exports = { getRequests, createRequest, updateRequest, deleteRequest };
