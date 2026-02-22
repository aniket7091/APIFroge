const Collection = require('../models/Collection');
const Request = require('../models/Request');

/**
 * GET /api/collections
 * Fetch all collections belonging to the logged-in user.
 */
const getCollections = async (req, res, next) => {
    try {
        const collections = await Collection.find({ userId: req.user._id })
            .populate('requests', 'name method url')
            .sort({ updatedAt: -1 });
        res.json({ success: true, data: collections });
    } catch (error) { next(error); }
};

/**
 * POST /api/collections
 * Create a new collection.
 */
const createCollection = async (req, res, next) => {
    try {
        const { name, description, color } = req.body;
        if (!name) return res.status(400).json({ success: false, message: 'Name is required' });

        const collection = await Collection.create({
            name, description, color, userId: req.user._id,
        });
        res.status(201).json({ success: true, data: collection });
    } catch (error) { next(error); }
};

/**
 * PUT /api/collections/:id
 * Update a collection's metadata.
 */
const updateCollection = async (req, res, next) => {
    try {
        const collection = await Collection.findOneAndUpdate(
            { _id: req.params.id, userId: req.user._id },
            { $set: req.body },
            { new: true, runValidators: true }
        );
        if (!collection) return res.status(404).json({ success: false, message: 'Collection not found' });
        res.json({ success: true, data: collection });
    } catch (error) { next(error); }
};

/**
 * DELETE /api/collections/:id
 * Delete a collection and all its requests.
 */
const deleteCollection = async (req, res, next) => {
    try {
        const collection = await Collection.findOneAndDelete({
            _id: req.params.id, userId: req.user._id,
        });
        if (!collection) return res.status(404).json({ success: false, message: 'Collection not found' });

        // Remove all requests that belonged to this collection
        await Request.deleteMany({ collectionId: req.params.id });

        res.json({ success: true, message: 'Collection deleted' });
    } catch (error) { next(error); }
};

module.exports = { getCollections, createCollection, updateCollection, deleteCollection };
