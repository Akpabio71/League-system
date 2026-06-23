import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';
import { genRandomToken, hashToken, signAccessToken } from '../lib/token';
import { sendVerificationEmail, sendPasswordResetEmail } from '../services/email';

const REFRESH_EXPIRES_DAYS = Number(process.env.JWT_REFRESH_EXPIRES_DAYS || 30);
const APP_BASE_URL = process.env.APP_BASE_URL || 'http://localhost:4000';
const LOCKOUT_THRESHOLD = Number(process.env.LOCKOUT_THRESHOLD || 5);
const LOCKOUT_DURATION_MIN = Number(process.env.LOCKOUT_DURATION_MIN || 15);

export default function (prisma: PrismaClient) {
  const router = Router();

  // Register
  router.post('/register', async (req, res) => {
    const { name, email, password } = req.body;
    if (!name || !email || !password) return res.status(400).json({ error: 'Missing fields' });

    try {
      const hashed = await bcrypt.hash(password, 10);
      const user = await prisma.user.create({
        data: { name, email, password: hashed },
      });

      // create email verification token
      const raw = genRandomToken(24);
      const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h
      await prisma.emailVerificationToken.create({
        data: { userId: user.id, token: raw, expiresAt },
      });

      // send verification link (console adapter or SMTP based on env)
      const link = `${APP_BASE_URL}/api/auth/verify-email?token=${raw}`;
      await sendVerificationEmail(user.email, link);

      // respond (do not expose sensitive fields)
      return res.status(201).json({ id: user.id, email: user.email, name: user.name });
    } catch (err: any) {
      if (err?.code === 'P2002') return res.status(409).json({ error: 'Email already exists' });
      console.error(err);
      return res.status(500).json({ error: 'Server error' });
    }
  });

  // Verify Email
  router.get('/verify-email', async (req, res) => {
    const token = String(req.query.token || '');
    if (!token) return res.status(400).json({ error: 'Missing token' });

    const record = await prisma.emailVerificationToken.findUnique({ where: { token } });
    if (!record) return res.status(400).json({ error: 'Invalid token' });
    if (record.used) return res.status(400).json({ error: 'Token already used' });
    if (record.expiresAt < new Date()) return res.status(400).json({ error: 'Token expired' });

    await prisma.user.update({ where: { id: record.userId }, data: { emailVerified: true } });
    await prisma.emailVerificationToken.update({ where: { id: record.id }, data: { used: true } });

    return res.json({ success: true });
  });

  // Login
  router.post('/login', async (req, res) => {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Missing fields' });

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });

    // Lockout check
    if (user.lockedUntil && user.lockedUntil > new Date()) {
      return res.status(423).json({ error: 'Account locked. Try later.' });
    }

    const ok = await bcrypt.compare(password, user.password);
    if (!ok) {
      // increment failed attempts
      const updated = await prisma.user.update({
        where: { id: user.id },
        data: { failedLoginAttempts: { increment: 1 } },
      });

      if (updated.failedLoginAttempts >= LOCKOUT_THRESHOLD) {
        const until = new Date(Date.now() + LOCKOUT_DURATION_MIN * 60 * 1000);
        await prisma.user.update({ where: { id: user.id }, data: { lockedUntil: until } });
      }
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // success: reset counters
    await prisma.user.update({ where: { id: user.id }, data: { failedLoginAttempts: 0, lockedUntil: null } });

    // create access token
    const accessToken = signAccessToken({ sub: user.id, role: user.role });

    // create refresh token (raw token stored hashed)
    const rawRefresh = genRandomToken(32);
    const tokenHash = hashToken(rawRefresh);
    const expiresAt = new Date(Date.now() + REFRESH_EXPIRES_DAYS * 24 * 60 * 60 * 1000);
    await prisma.refreshToken.create({
      data: { userId: user.id, tokenHash, expiresAt },
    });

    return res.json({
      accessToken,
      refreshToken: rawRefresh,
      user: { id: user.id, name: user.name, email: user.email, role: user.role },
    });
  });

  // Refresh token
  router.post('/refresh', async (req, res) => {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(400).json({ error: 'Missing token' });
    const tokenHash = hashToken(refreshToken);

    const record = await prisma.refreshToken.findFirst({ where: { tokenHash } });
    if (!record || record.revoked || record.expiresAt < new Date()) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    // rotate: revoke old token, create new one
    await prisma.refreshToken.update({ where: { id: record.id }, data: { revoked: true } });

    const newRaw = genRandomToken(32);
    const newHash = hashToken(newRaw);
    const newExpires = new Date(Date.now() + REFRESH_EXPIRES_DAYS * 24 * 60 * 60 * 1000);
    await prisma.refreshToken.create({ data: { userId: record.userId, tokenHash: newHash, expiresAt: newExpires, replacedBy: null } });

    // issue access token
    const user = await prisma.user.findUnique({ where: { id: record.userId } });
    if (!user) return res.status(401).json({ error: 'Invalid token owner' });

    const accessToken = signAccessToken({ sub: user.id, role: user.role });
    return res.json({ accessToken, refreshToken: newRaw });
  });

  // Logout (revoke refresh token)
  router.post('/logout', async (req, res) => {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(400).json({ error: 'Missing token' });
    const tokenHash = hashToken(refreshToken);
    await prisma.refreshToken.updateMany({ where: { tokenHash }, data: { revoked: true } });
    return res.status(204).send();
  });

  // Forgot password
  router.post('/forgot-password', async (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Missing email' });

    const user = await prisma.user.findUnique({ where: { email } });
    if (user) {
      const raw = genRandomToken(28);
      const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour
      await prisma.passwordResetToken.create({ data: { userId: user.id, token: raw, expiresAt } });
      const link = `${APP_BASE_URL}/api/auth/reset-password?token=${raw}`;
      await sendPasswordResetEmail(user.email, link);
    }

    // Always respond 200 to avoid user enumeration
    return res.json({ success: true });
  });

  // Reset password
  router.post('/reset-password', async (req, res) => {
    const { token, password } = req.body;
    if (!token || !password) return res.status(400).json({ error: 'Missing fields' });

    const record = await prisma.passwordResetToken.findUnique({ where: { token } });
    if (!record || record.used || record.expiresAt < new Date()) {
      return res.status(400).json({ error: 'Invalid or expired token' });
    }

    const hashed = await bcrypt.hash(password, 10);
    await prisma.user.update({ where: { id: record.userId }, data: { password: hashed } });
    await prisma.passwordResetToken.update({ where: { id: record.id }, data: { used: true } });

    // revoke all refresh tokens for user
    await prisma.refreshToken.updateMany({ where: { userId: record.userId }, data: { revoked: true } });

    return res.json({ success: true });
  });

  return router;
}
