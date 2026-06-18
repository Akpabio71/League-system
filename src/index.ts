import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';
import authRoutes from './routes/auth';
import seasonsRoutes from './routes/seasons';
import path from 'path';

dotenv.config();
const app = express();
const prisma = new PrismaClient();

app.use(cors());
app.use(express.json());

// Mount routes
app.use('/api/auth', authRoutes(prisma));
app.use('/api/seasons', seasonsRoutes(prisma));

// Serve a tiny admin UI
app.use('/admin', express.static(path.join(__dirname, '..', 'admin')));

const port = process.env.PORT || 4000;
app.listen(port, () => {
  console.log(`Server listening on ${port}`);
});
