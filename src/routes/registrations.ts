import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authMiddleware, requireRole, AuthRequest } from '../middleware/auth';

export default function (prisma: PrismaClient) {
  const router = Router({ mergeParams: true });

  // Public: submit a registration for a season
  router.post('/', async (req, res) => {
    const seasonId = Number(req.params.seasonId);
    const { teamName, club, notes } = req.body;
    if (!teamName) return res.status(400).json({ error: 'teamName required' });
    try {
      const team = await prisma.team.create({ data: { name: teamName, club: club || null, seasonId } });
      const reg = await prisma.registration.create({ data: { seasonId, teamId: team.id, notes: notes || null } });
      res.json({ registration: reg, team });
    } catch (err) {
      res.status(500).json({ error: 'Server error' });
    }
  });

  // Admin: list registrations for a season
  router.get('/', authMiddleware(prisma), requireRole(['ADMIN', 'LEAGUE_ADMIN']), async (req: AuthRequest, res) => {
    const seasonId = Number(req.params.seasonId);
    const regs = await prisma.registration.findMany({ where: { seasonId }, include: { team: true } });
    res.json(regs);
  });

  // Admin: import registrations (expects { rows: [ { teamName, club } ] })
  router.post('/import', authMiddleware(prisma), requireRole(['ADMIN', 'LEAGUE_ADMIN']), async (req: AuthRequest, res) => {
    const seasonId = Number(req.params.seasonId);
    const { rows } = req.body;
    if (!Array.isArray(rows)) return res.status(400).json({ error: 'rows array required' });

    const results: any[] = [];
    const tx = await prisma.$transaction(async (prismaTx) => {
      for (const row of rows) {
        try {
          if (!row.teamName) {
            results.push({ row, ok: false, error: 'Missing teamName' });
            continue;
          }
          const team = await prismaTx.team.create({ data: { name: String(row.teamName), club: row.club || null, seasonId } });
          const reg = await prismaTx.registration.create({ data: { seasonId, teamId: team.id } });
          results.push({ row, ok: true, teamId: team.id, registrationId: reg.id });
        } catch (err: any) {
          results.push({ row, ok: false, error: err.message || 'error' });
        }
      }
      return results;
    });

    res.json({ results: tx });
  });

  return router;
}
