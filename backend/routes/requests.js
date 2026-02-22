const express = require('express');
const router = express.Router();
const {
    getRequests, createRequest, updateRequest, deleteRequest,
} = require('../controllers/requestController');
const { protect } = require('../middleware/auth');

router.use(protect);

router.route('/')
    .get(getRequests)
    .post(createRequest);

router.route('/:id')
    .put(updateRequest)
    .delete(deleteRequest);

module.exports = router;
