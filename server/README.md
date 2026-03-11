# Grocery API (Node + Express)

## Setup

```bash
cd server
npm install
cp .env.example .env
npm run dev
```

## Auth

- `POST /api/auth/register`
- `POST /api/auth/login`

## Products

- `GET /api/products`
- `GET /api/products/:id`
- `POST /api/products` (admin)
- `PUT /api/products/:id` (admin)
- `DELETE /api/products/:id` (admin)
- `POST /api/products/:id/restock` (admin)

## Orders

- `GET /api/orders` (admin)
- `GET /api/orders/me` (client)
- `POST /api/orders` (client)
- `PATCH /api/orders/:id/status` (admin)
- `GET /api/orders/:id/lines` (admin or owner)

## Restocks

- `GET /api/restocks` (admin)

## Uploads (local file storage)

- `POST /api/uploads` (admin, multipart `image` field)
- Files are served at `http://localhost:4000/uploads/<filename>`

## Notes

- Admin seed uses `ADMIN_EMAIL` + `ADMIN_PASSWORD` from `.env`.
- Auth uses JWT (`Authorization: Bearer <token>`).
- SQLite file stored at `server/data/grocery.db`.
- Uploaded images stored in `server/uploads`.
