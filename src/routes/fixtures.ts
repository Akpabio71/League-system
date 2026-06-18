import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authMiddleware, requireRole, AuthRequest } from '../middleware/auth';
import { generateRoundRobin } from '../services/fixtureGenerator';

export default function (prisma: PrismaClient) {
  const router = Router({ mergeParams: true });

  // Preview or generate fixtures for a season
  router.post('/generate', authMiddleware(prisma), requireRole(['ADMIN', 'LEAGUE_ADMIN']), async (req: AuthRequest, res) => {
    const seasonId = Number(req.params.seasonId);
    const { preview, matchDays } = req.body; // matchDays optional: ['Saturday','Sunday']

    const season = await prisma.season.findUnique({ where: { id: seasonId } });
    if (!season) return res.status(404).json({ error: 'Season not found' });

    // Use approved registrations. If none, fall back to teams directly in season
    const regs = await prisma.registration.findMany({ where: { seasonId, status: 'APPROVED' }, include: { team: true } });
    let teams = regs.map(r => r.team);
    if (teams.length === 0) {
      teams = await prisma.team.findMany({ where: { seasonId } });
    }

    if (teams.length < 2) return res.status(400).json({ error: 'Not enough teams to generate fixtures' });

    const teamIds = teams.map(t => t.id);
    const rounds = generateRoundRobin(teamIds);

    // assign dates: simple weekly schedule starting at season.startDate
    const start = new Date(season.startDate);
    const fixtures = [] as any[];
    for (let r = 0; r < rounds.length; r++) {
      const round = rounds[r];
      const matchDate = new Date(start.getTime() + r * 7 * 24 * 60 * 60 * 1000); // + r weeks
      for (const pair of round) {
        fixtures.push({ seasonId, homeTeamId: pair.home, awayTeamId: pair.away, round: r + 1, matchDate });
      }
    }

    if (preview) return res.json({ preview: fixtures });

    // persist fixtures
    const created: any[] = [];
    for (const f of fixtures) {
      const c = await prisma.fixture.create({ data: { seasonId: f.seasonId, homeTeamId: f.homeTeamId, awayTeamId: f.awayTeamId, matchDate: f.matchDate, round: f.round } });
      created.push(c);
    }

    res.json({ created });
  });

  // List fixtures for a season (public)
  router.get('/', async (req, res) => {
    const seasonId = Number(req.params.seasonId);
    const fixtures = await prisma.fixture.findMany({ where: { seasonId }, orderBy: { matchDate: 'asc' } });
    res.json(fixtures);
  });

  return router;
}
