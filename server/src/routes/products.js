import { Router } from 'express';

import db from '../db.js';
import { requireAuth, requireRole } from '../middleware/auth.js';

const router = Router();

router.get('/', (req, res) => {
  const { active } = req.query;
  let rows;

  if (active === 'false') {
    rows = db.prepare('SELECT * FROM products').all();
  } else {
    rows = db.prepare('SELECT * FROM products WHERE is_active = 1').all();
  }

  return res.json(rows.map(mapProduct));
});

router.get('/:id', (req, res) => {
  const row = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
  if (!row) {
    return res.status(404).json({ error: 'Product not found.' });
  }
  return res.json(mapProduct(row));
});

router.post('/', requireAuth, requireRole('admin'), (req, res) => {
  const { name, category, description, price, imageUrl, stock } = req.body || {};
  if (!name || !category || !description || price == null || stock == null || !imageUrl) {
    return res.status(400).json({ error: 'Missing required fields.' });
  }

  const id = `p${Date.now()}`;
  const now = new Date().toISOString();
  db.prepare(
    `INSERT INTO products (id, name, category, description, price, image_url, stock, is_active, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)`
  ).run(id, name, category, description, Number(price), imageUrl, Number(stock), now, now);

  const row = db.prepare('SELECT * FROM products WHERE id = ?').get(id);
  return res.status(201).json(mapProduct(row));
});

router.put('/:id', requireAuth, requireRole('admin'), (req, res) => {
  const { name, category, description, price, imageUrl, stock, isActive } = req.body || {};
  const existing = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
  if (!existing) {
    return res.status(404).json({ error: 'Product not found.' });
  }

  const updated = {
    name: name ?? existing.name,
    category: category ?? existing.category,
    description: description ?? existing.description,
    price: price ?? existing.price,
    image_url: imageUrl ?? existing.image_url,
    stock: stock ?? existing.stock,
    is_active: isActive == null ? existing.is_active : isActive ? 1 : 0,
  };

  db.prepare(
    `UPDATE products SET name = ?, category = ?, description = ?, price = ?, image_url = ?, stock = ?, is_active = ?, updated_at = ? WHERE id = ?`
  ).run(
    updated.name,
    updated.category,
    updated.description,
    Number(updated.price),
    updated.image_url,
    Number(updated.stock),
    updated.is_active,
    new Date().toISOString(),
    req.params.id
  );

  const row = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
  return res.json(mapProduct(row));
});

router.delete('/:id', requireAuth, requireRole('admin'), (req, res) => {
  const existing = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
  if (!existing) {
    return res.status(404).json({ error: 'Product not found.' });
  }

  db.prepare('DELETE FROM products WHERE id = ?').run(req.params.id);
  return res.status(204).send();
});

router.post('/:id/restock', requireAuth, requireRole('admin'), (req, res) => {
  const { quantity } = req.body || {};
  const qty = Number(quantity);
  if (!qty || qty <= 0) {
    return res.status(400).json({ error: 'Quantity must be greater than 0.' });
  }

  const existing = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
  if (!existing) {
    return res.status(404).json({ error: 'Product not found.' });
  }

  const nextStock = existing.stock + qty;
  db.prepare('UPDATE products SET stock = ?, updated_at = ? WHERE id = ?').run(
    nextStock,
    new Date().toISOString(),
    req.params.id
  );

  db.prepare(
    'INSERT INTO restocks (product_id, quantity_added, created_at) VALUES (?, ?, ?)'
  ).run(req.params.id, qty, new Date().toISOString());

  const row = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
  return res.json(mapProduct(row));
});

function mapProduct(row) {
  return {
    id: row.id,
    name: row.name,
    category: row.category,
    description: row.description,
    price: row.price,
    imageUrl: row.image_url,
    stock: row.stock,
    isActive: row.is_active === 1,
  };
}

export default router;
