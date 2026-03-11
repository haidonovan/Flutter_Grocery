import { Router } from 'express';

import db from '../db.js';
import { requireAuth, requireRole } from '../middleware/auth.js';

const router = Router();

router.get('/', requireAuth, requireRole('admin'), (req, res) => {
  const rows = db
    .prepare(
      `SELECT orders.*, users.email AS customer_email
       FROM orders
       LEFT JOIN users ON users.id = orders.customer_id
       ORDER BY orders.created_at DESC`
    )
    .all();
  return res.json(rows.map(mapOrder));
});

router.get('/me', requireAuth, (req, res) => {
  const rows = db
    .prepare(
      `SELECT orders.*, users.email AS customer_email
       FROM orders
       LEFT JOIN users ON users.id = orders.customer_id
       WHERE orders.customer_id = ?
       ORDER BY orders.created_at DESC`
    )
    .all(req.user.id);
  return res.json(rows.map(mapOrder));
});

router.post('/', requireAuth, (req, res) => {
  const { shippingAddress, paymentMethod, lines } = req.body || {};
  if (!shippingAddress || !paymentMethod || !Array.isArray(lines) || lines.length === 0) {
    return res.status(400).json({ error: 'Invalid order payload.' });
  }

  const products = new Map(
    db.prepare('SELECT * FROM products').all().map((row) => [row.id, row])
  );

  let total = 0;
  for (const line of lines) {
    const product = products.get(line.productId);
    if (!product || product.is_active !== 1) {
      return res.status(400).json({ error: 'Product unavailable.' });
    }
    if (product.stock < line.quantity) {
      return res.status(400).json({ error: 'Insufficient stock.' });
    }
    total += product.price * line.quantity;
  }

  const orderId = `ORD-${Date.now()}`;
  const now = new Date().toISOString();

  const tx = db.transaction(() => {
    db.prepare(
      `INSERT INTO orders (id, customer_id, shipping_address, payment_method, total, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    ).run(orderId, req.user.id, shippingAddress, paymentMethod, total, 'pending', now);

    const insertLine = db.prepare(
      `INSERT INTO order_lines (order_id, product_id, product_name, quantity, unit_price)
       VALUES (?, ?, ?, ?, ?)`
    );
    const updateStock = db.prepare('UPDATE products SET stock = ?, updated_at = ? WHERE id = ?');

    for (const line of lines) {
      const product = products.get(line.productId);
      insertLine.run(orderId, product.id, product.name, line.quantity, product.price);
      updateStock.run(product.stock - line.quantity, now, product.id);
      products.set(product.id, { ...product, stock: product.stock - line.quantity });
    }
  });

  tx();

  const order = db
    .prepare(
      `SELECT orders.*, users.email AS customer_email
       FROM orders
       LEFT JOIN users ON users.id = orders.customer_id
       WHERE orders.id = ?`
    )
    .get(orderId);
  return res.status(201).json(mapOrder(order));
});

router.patch('/:id/status', requireAuth, requireRole('admin'), (req, res) => {
  const { status } = req.body || {};
  const allowed = new Set(['pending', 'processing', 'shipped', 'delivered', 'cancelled']);
  if (!allowed.has(status)) {
    return res.status(400).json({ error: 'Invalid status.' });
  }

  const existing = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
  if (!existing) {
    return res.status(404).json({ error: 'Order not found.' });
  }

  db.prepare('UPDATE orders SET status = ? WHERE id = ?').run(status, req.params.id);
  const order = db
    .prepare(
      `SELECT orders.*, users.email AS customer_email
       FROM orders
       LEFT JOIN users ON users.id = orders.customer_id
       WHERE orders.id = ?`
    )
    .get(req.params.id);
  return res.json(mapOrder(order));
});

router.get('/:id/lines', requireAuth, (req, res) => {
  const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
  if (!order) {
    return res.status(404).json({ error: 'Order not found.' });
  }

  if (req.user.role !== 'admin' && order.customer_id !== req.user.id) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  const lines = db
    .prepare('SELECT * FROM order_lines WHERE order_id = ?')
    .all(req.params.id);

  return res.json(
    lines.map((line) => ({
      productId: line.product_id,
      productName: line.product_name,
      quantity: line.quantity,
      unitPrice: line.unit_price,
      subtotal: line.unit_price * line.quantity,
    }))
  );
});

function mapOrder(row) {
  return {
    id: row.id,
    customerId: row.customer_id,
    customerEmail: row.customer_email || '',
    shippingAddress: row.shipping_address,
    paymentMethod: row.payment_method,
    total: row.total,
    status: row.status,
    createdAt: row.created_at,
  };
}

export default router;
