const express = require('express');
const router = express.Router();
const {
    getHistory, clearHistory, deleteHistoryEntry,
} = require('../controllers/historyController');
const { protect } = require('../middleware/auth');

router.use(protect);

router.route('/')
    .get(getHistory)
    .delete(clearHistory);

router.route('/:id')
    .delete(deleteHistoryEntry);

module.exports = router;
