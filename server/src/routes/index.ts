import { Router } from 'express';
import healthRouter from './health.js';
import authRouter from './auth.js';
import usersRouter from './users.js';
import eventsRouter from './events.js';
import interactionsRouter from './interactions.js';
import uploadRouter from './upload.js';

const router = Router();

// Health check endpoint
router.use('/health', healthRouter);

// Auth routes (public)
router.use('/auth', authRouter);

// User routes (protected)
router.use('/users', usersRouter);

// Events routes (protected)
router.use('/events', eventsRouter);

// Interactions routes (like/going) - mounted on /events/:id/*
router.use('/events', interactionsRouter);

// Upload routes (protected)
router.use('/upload', uploadRouter);

export default router;
