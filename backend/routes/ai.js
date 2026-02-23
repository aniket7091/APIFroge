const express = require('express');
const { executeAiTask } = require('../controllers/aiController');
const { protect } = require('../middleware/auth');

const router = express.Router();

// Apply auth middleware to protect AI routes
router.use(protect);

router.post('/execute', executeAiTask);

module.exports = router;
