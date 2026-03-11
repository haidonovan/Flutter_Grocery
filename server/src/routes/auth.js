import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { Router } from 'express';

import db from '../db.js';

const router = Router();

router.post('/register', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required.' });
  }

  const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
  if (existing) {
    return res.status(409).json({ error: 'Email already exists.' });
  }

  const hash = bcrypt.hashSync(password, 10);
  const createdAt = new Date().toISOString();
  const result = db
    .prepare(
      'INSERT INTO users (email, password_hash, role, created_at) VALUES (?, ?, ?, ?)'
    )
    .run(email, hash, 'client', createdAt);

  const payload = { id: result.lastInsertRowid, email, role: 'client' };
  const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '7d' });

  return res.status(201).json({ token, user: payload });
});

router.post('/login', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required.' });
  }

  const user = db
    .prepare('SELECT id, email, password_hash, role FROM users WHERE email = ?')
    .get(email);

  if (!user) {
    return res.status(401).json({ error: 'Invalid credentials.' });
  }

  const valid = bcrypt.compareSync(password, user.password_hash);
  if (!valid) {
    return res.status(401).json({ error: 'Invalid credentials.' });
  }

  const payload = { id: user.id, email: user.email, role: user.role };
  const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '7d' });

  return res.json({ token, user: payload });
});

export default router;
