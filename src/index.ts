import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';
import authRoutes from './routes/auth';
import seasonsRoutes from './routes/seasons';
import path from 'path';
import registrationsRoutes from './routes/registrations';
import fixturesRoutes from './routes/fixtures';

dotenv.config();
const app = express();
const prisma = new PrismaClient();

app.use(cors());
app.use(express.json({ limit: '5mb' }));

// Mount routes
app.use('/api/auth', authRoutes(prisma));
app.use('/api/seasons', seasonsRoutes(prisma));
app.use('/api/seasons/:seasonId/registrations', registrationsRoutes(prisma));
app.use('/api/seasons/:seasonId/fixtures', fixturesRoutes(prisma));

// Serve a tiny admin UI
app.use('/admin', express.static(path.join(__dirname, '..', 'admin')));

const port = process.env.PORT || 4000;
app.listen(port, () => {
  console.log(`Server listening on ${port}`);
});
