# Football League — Admin scaffold

This scaffold provides a starting point for the Admin system: auth, DB schema, and seasons CRUD.

Quickstart:
1. Copy files into a project folder.
2. npm install
3. Copy .env.example -> .env and set DATABASE_URL and JWT_SECRET.
4. npx prisma migrate dev --name init
5. npm run dev
6. Visit http://localhost:4000/admin/index.html (or open the file directly). The admin UI expects the API on port 4000.

Notes:
- This is a minimal scaffold for rapid iteration. Do not use JS JWT storage in production; prefer HttpOnly cookies for session tokens.
- Next tasks: registration endpoints and UI, fixture generator service, background jobs.
