import { Router } from 'express';
import healthRouter from './health.js';
import authRouter from './auth.js';
import usersRouter from './users.js';
import eventsRouter from './events.js';
import spotsRouter from './spots.js';
import interactionsRouter from './interactions.js';
import uploadRouter from './upload.js';
import socialRouter from './social/index.js';
import collectionsRouter from './collections.js';
import plansRouter from './plans.js';
// DORMANT 2026-04: Telegram/Mastra disabled during Fly migration. To revive, uncomment and restore env vars.
// import ingestRouter from './ingest.js';
import searchRouter from './search.js';

const router = Router();

router.use('/health', healthRouter);
router.use('/auth', authRouter);
router.use('/users', usersRouter);
router.use('/events', eventsRouter);
router.use('/spots', spotsRouter);
router.use('/events', interactionsRouter);
router.use('/', socialRouter);
router.use('/collections', collectionsRouter);
router.use('/plans', plansRouter);
router.use('/upload', uploadRouter);
// DORMANT 2026-04: Telegram/Mastra disabled during Fly migration. To revive, uncomment and restore env vars.
// router.use('/ingest', ingestRouter);
router.use('/search', searchRouter);

export default router;
