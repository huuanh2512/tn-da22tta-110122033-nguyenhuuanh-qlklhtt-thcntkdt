const express = require('express');
const controller = require('../controllers/court-blocks.controller');
const authMiddleware = require('../middlewares/auth.middleware');

const router = express.Router();

router.use(authMiddleware.verifyToken);
router.use(authMiddleware.requireRole(['STAFF', 'ADMIN', 'SUPER_ADMIN']));
router.post('/', controller.createCourtBlock);
router.get('/', controller.queryCourtBlocks);
router.patch('/:id', controller.updateCourtBlock);
router.delete('/:id', controller.cancelCourtBlock);

module.exports = router;
