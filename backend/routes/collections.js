const express = require('express');
const router = express.Router();
const {
    getCollections, createCollection, updateCollection, deleteCollection,
} = require('../controllers/collectionController');
const { protect } = require('../middleware/auth');

// All routes protected
router.use(protect);

router.route('/')
    .get(getCollections)
    .post(createCollection);

router.route('/:id')
    .put(updateCollection)
    .delete(deleteCollection);

module.exports = router;
