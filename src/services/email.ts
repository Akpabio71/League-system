import { Resend } from 'resend';
import fs from 'fs';
import path from 'path';

const RESEND_API_KEY = process.env.RESEND_API_KEY || '';
const FROM_EMAIL = process.env.EMAIL_FROM || 'noreply@nexgenesport.com';
const APP_BASE_URL = process.env.APP_BASE_URL || 'http://localhost:4000';

if (!RESEND_API_KEY) {
  console.warn('RESEND_API_KEY is not set — email delivery will fail until provided.');
}

let resend: Resend | null = null;
try {
  if (RESEND_API_KEY) resend = new Resend(RESEND_API_KEY);
} catch (err) {
  console.warn('Resend client init failed:', err);
}

export function loadTemplate(name: string): string {
  const file = path.join(__dirname, 'templates', name);
  return fs.readFileSync(file, 'utf8');
}

export function render(template: string, vars: Record<string, string>) {
  let out = template;
  for (const [k, v] of Object.entries(vars)) {
    out = out.replace(new RegExp(`{{\\s*${k}\\s*}}`, 'g'), v);
  }
  return out;
}

export async function sendVerificationEmail(to: string, verificationLink: string) {
  const template = loadTemplate('verification.html');
  const html = render(template, {
    verificationLink,
    appUrl: APP_BASE_URL,
    supportEmail: process.env.SUPPORT_EMAIL || 'support@nexgenesport.com',
  });

  // If no Resend client, fallback to console for dev
  if (!resend) {
    console.log(`[Email][DEV] Verification email for ${to}: ${verificationLink}`);
    return { status: 'console' };
  }

  try {
    const resp = await resend.emails.send({
      from: FROM_EMAIL,
      to,
      subject: 'Verify your NexGen account',
      html,
    });
    console.log('Verification email sent:', resp);
    return resp;
  } catch (err) {
    console.error('Failed to send verification email', err);
    throw err;
  }
}

export async function sendPasswordResetEmail(to: string, resetLink: string) {
  const template = loadTemplate('reset_password.html');
  const html = render(template, {
    resetLink,
    appUrl: APP_BASE_URL,
    supportEmail: process.env.SUPPORT_EMAIL || 'support@nexgenesport.com',
  });

  if (!resend) {
    console.log(`[Email][DEV] Password reset email for ${to}: ${resetLink}`);
    return { status: 'console' };
  }

  try {
    const resp = await resend.emails.send({
      from: FROM_EMAIL,
      to,
      subject: 'Reset your NexGen password',
      html,
    });
    console.log('Password reset email sent:', resp);
    return resp;
  } catch (err) {
    console.error('Failed to send reset email', err);
    throw err;
  }
}
