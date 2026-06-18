import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authMiddleware, requireRole, AuthRequest } from '../middleware/auth';

export default function (prisma: PrismaClient) {
  const router = Router();

  // Public read
  router.get('/', async (req, res) => {
    const seasons = await prisma.season.findMany({ orderBy: { startDate: 'desc' } });
    res.json(seasons);
  });

  // Protected below
  router.use(authMiddleware(prisma));

  // Create season (ADMIN or LEAGUE_ADMIN)
  router.post('/', requireRole(['ADMIN', 'LEAGUE_ADMIN']), async (req: AuthRequest, res) => {
    const { name, startDate, endDate, registrationOpen, registrationClose, settings } = req.body;
    if (!name || !startDate || !endDate) return res.status(400).json({ error: 'Missing fields' });
    const season = await prisma.season.create({
      data: {
        name,
        startDate: new Date(startDate),
        endDate: new Date(endDate),
        registrationOpen: registrationOpen ? new Date(registrationOpen) : null,
        registrationClose: registrationClose ? new Date(registrationClose) : null,
        settings: settings || {},
        createdById: req.user!.id,
      },
    });
    res.json(season);
  });

  // Update season
  router.patch('/:id', requireRole(['ADMIN', 'LEAGUE_ADMIN']), async (req: AuthRequest, res) => {
    const id = Number(req.params.id);
    const data: any = {};
    const fields = ['name', 'startDate', 'endDate', 'registrationOpen', 'registrationClose', 'status', 'settings'];
    fields.forEach((f) => {
      if (req.body[f] !== undefined) data[f] = f.includes('Date') && req.body[f] ? new Date(req.body[f]) : req.body[f];
    });
    try {
      const season = await prisma.season.update({ where: { id }, data });
      res.json(season);
    } catch (err) {
      res.status(404).json({ error: 'Season not found' });
    }
  });

  // Delete season
  router.delete('/:id', requireRole(['ADMIN']), async (req: AuthRequest, res) => {
    const id = Number(req.params.id);
    try {
      await prisma.season.delete({ where: { id } });
      res.json({ success: true });
    } catch {
      res.status(404).json({ error: 'Not found' });
    }
  });

  return router;
}
