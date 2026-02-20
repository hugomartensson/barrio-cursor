/**
 * Social routes - combines follow, followers, and follow-requests routers
 * All routes are mounted on root path (/)
 */

import { Router } from 'express';
import followRouter from './follow.js';
import followersRouter from './followers.js';
import followRequestsRouter from './follow-requests.js';

const router = Router();

// Mount all social route modules
router.use(followRouter);
router.use(followersRouter);
router.use(followRequestsRouter);

export default router;
