const express = require('express');
const router = express.Router();
const { sendRequest, runPerformanceTest } = require('../controllers/proxyController');
const { generateCurl, generateJsFetch } = require('../services/snippetGenerator');
const { protect } = require('../middleware/auth');

router.use(protect);

// @route   POST /api/proxy/send
// @desc    Forward a dynamic HTTP request and return the response
router.post('/send', sendRequest);

// @route   POST /api/proxy/performance
// @desc    Run the same request multiple times and return stats
router.post('/performance', runPerformanceTest);

// @route   POST /api/proxy/snippet
// @desc    Generate curl / JS fetch code snippets
router.post('/snippet', (req, res) => {
    const { type = 'curl', ...config } = req.body;
    try {
        const snippet = type === 'fetch' ? generateJsFetch(config) : generateCurl(config);
        res.json({ success: true, snippet });
    } catch (e) {
        res.status(400).json({ success: false, message: e.message });
    }
});

module.exports = router;
