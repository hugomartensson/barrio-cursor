import { Router } from 'express';
import healthRouter from './health.js';
import authRouter from './auth.js';
import usersRouter from './users.js';
import eventsRouter from './events.js';
import interactionsRouter from './interactions.js';
import uploadRouter from './upload.js';
import socialRouter from './social.js';
import plansRouter from './plans.js';
import importRouter from './import.js';

const router = Router();

// Health check endpoint
router.use('/health', healthRouter);

// Auth routes (public)
router.use('/auth', authRouter);

// User routes (protected)
router.use('/users', usersRouter);

// Events routes (protected)
router.use('/events', eventsRouter);

// Interactions routes (interested) - mounted on /events/:id/*
router.use('/events', interactionsRouter);

// Social routes (following, follow requests) - mounted on root
router.use('/', socialRouter);

// Plans routes (protected)
router.use('/plans', plansRouter);

// Upload routes (protected)
router.use('/upload', uploadRouter);

// Import routes (protected - event curation tool)
router.use('/import', importRouter);

export default router;
