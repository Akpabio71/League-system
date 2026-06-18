import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';

const JWT_SECRET = process.env.JWT_SECRET || 'changeme';

export interface AuthRequest extends Request {
  user?: { id: number; email: string; role: string };
}

export function authMiddleware(prisma: PrismaClient) {
  return async (req: AuthRequest, res: Response, next: NextFunction) => {
    const auth = req.headers.authorization;
    if (!auth?.startsWith('Bearer ')) return res.status(401).json({ error: 'Missing token' });

    const token = auth.slice(7);
    try {
      const payload = jwt.verify(token, JWT_SECRET) as any;
      // optionally load user from DB
      const user = await prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user) return res.status(401).json({ error: 'User not found' });

      req.user = { id: user.id, email: user.email, role: user.role };
      next();
    } catch (err) {
      return res.status(401).json({ error: 'Invalid token' });
    }
  };
}

export function requireRole(roles: string[]) {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
    if (!roles.includes(req.user.role)) return res.status(403).json({ error: 'Forbidden' });
    next();
  };
}
