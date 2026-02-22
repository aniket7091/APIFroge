const History = require('../models/History');

/**
 * GET /api/history
 * Fetch paginated history for the logged-in user.
 */
const getHistory = async (req, res, next) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;
        const skip = (page - 1) * limit;

        const [history, total] = await Promise.all([
            History.find({ userId: req.user._id })
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(limit),
            History.countDocuments({ userId: req.user._id }),
        ]);

        res.json({
            success: true,
            data: history,
            pagination: { page, limit, total, pages: Math.ceil(total / limit) },
        });
    } catch (error) { next(error); }
};

/**
 * DELETE /api/history
 * Clear all history for the logged-in user.
 */
const clearHistory = async (req, res, next) => {
    try {
        await History.deleteMany({ userId: req.user._id });
        res.json({ success: true, message: 'History cleared' });
    } catch (error) { next(error); }
};

/**
 * DELETE /api/history/:id
 * Delete a single history entry.
 */
const deleteHistoryEntry = async (req, res, next) => {
    try {
        const entry = await History.findOneAndDelete({
            _id: req.params.id, userId: req.user._id,
        });
        if (!entry) return res.status(404).json({ success: false, message: 'History entry not found' });
        res.json({ success: true, message: 'Entry deleted' });
    } catch (error) { next(error); }
};

module.exports = { getHistory, clearHistory, deleteHistoryEntry };
