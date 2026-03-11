import { Router } from 'express';

import db from '../db.js';
import { requireAuth, requireRole } from '../middleware/auth.js';

const router = Router();

router.get('/', requireAuth, requireRole('admin'), (req, res) => {
  const rows = db
    .prepare(
      `SELECT restocks.id, restocks.product_id, restocks.quantity_added, restocks.created_at, products.name AS product_name
       FROM restocks
       LEFT JOIN products ON products.id = restocks.product_id
       ORDER BY restocks.created_at DESC`
    )
    .all();

  return res.json(
    rows.map((row) => ({
      id: row.id,
      productId: row.product_id,
      productName: row.product_name,
      quantityAdded: row.quantity_added,
      createdAt: row.created_at,
    }))
  );
});

export default router;
