# Spry Monorepo Specification

## Project Overview
Monorepo structure for the "Spry" application, including frontend, backend, database configuration, and local orchestration using Docker Compose.

---

## Directory Structure & Purpose

- `/backend`: FastAPI service handling meeting domain logic, ORM models, and database migrations.
- `/frontend`: React SPA for displaying and adding meetings.
- `/docker-compose.yml`: Root orchestrator for local development environment.

---

## Technical Stack & Pinned Versions

- **Backend**: Python 3.12 (`python:3.12-slim`), FastAPI 0.110.0, SQLAlchemy 2.0.28, Alembic 1.13.1, Uvicorn 0.28.0
- **Frontend**: Node 20 (`node:20-slim`), React 18, Vite 5, Tailwind CSS 3, shadcn/ui
- **Database**: PostgreSQL 16 (`postgres:16-alpine`)

---

## API Contract

### Models
`Meeting`:
- `id`: integer (primary key, auto-increment)
- `title`: string (required, non-empty)
- `starts_at`: string (ISO 8601 datetime format, e.g., `2026-10-01T10:00:00Z`)
- `ends_at`: string (ISO 8601 datetime format, e.g., `2026-10-01T11:00:00Z`)
- `attendee_count`: integer (min: 1)

### Endpoints
1. `GET /api/meetings`
   - **Response**: `200 OK`
   - **Body**: Array of `Meeting` objects:
     ```json
     [
       {
         "id": 1,
         "title": "Architecture Sync",
         "starts_at": "2026-10-01T10:00:00Z",
         "ends_at": "2026-10-01T11:00:00Z",
         "attendee_count": 4
       }
     ]
     ```

2. `POST /api/meetings`
   - **Request Body**:
     ```json
     {
       "title": "Architecture Sync",
       "starts_at": "2026-10-01T10:00:00Z",
       "ends_at": "2026-10-01T11:00:00Z",
       "attendee_count": 4
     }
     ```
   - **Response**: `201 Created` with created `Meeting` object.

---

## Docker Compose & Service Readiness Contract

- `postgres`:
  - **Port**: `5432` (internal)
  - **Healthcheck**: `pg_isready -U postgres` (interval: 5s, timeout: 5s, retries: 5)
  - **Volumes**: Named volume `pgdata` mounted to `/var/lib/postgresql/data`

- `backend`:
  - **Port**: `8000` (mapped `8000:8000`)
  - **Depends on**: `postgres` with `condition: service_healthy`
  - **Command**: Run Alembic migrations (`alembic upgrade head`), then start Uvicorn (`uvicorn app.main:app --host 0.0.0.0 --port 8000`).

- `frontend`:
  - **Port**: `5173` (mapped `5173:5173`)
  - **Depends on**: `backend`
  - **Command**: Run Vite dev server with host binding (`npm run dev -- --host`).

---

## Constraints
- Single command execution: `docker compose up --build` brings up the entire functional stack.
- No Redis, Celery, Nginx, or Kubernetes manifests permitted in this repository slice.
