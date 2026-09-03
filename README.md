# Sovalune Infrastructure

Infrastructure as Code for the Sovalune AI Agent Platform.

## Components

- **PostgreSQL** (Supabase) - Primary database with pgvector extension
- **NATS** - Message bus with JetStream for persistent messaging
- **Supabase Storage** - S3-compatible object storage
- **Supabase Studio** - Database dashboard (purple theme)
- **Kong** - API Gateway

## Quick Start

```bash
# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f

# Stop services
docker compose down -v
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| PostgreSQL | 5432 | Main database with pgvector |
| NATS | 4222 | Message bus |
| NATS Monitor | 8222 | NATS monitoring UI |
| Studio | 3000 | Supabase Studio dashboard |
| API Gateway | 8000 | PostgREST API |
| Storage | 5000 | Object storage API |
| Auth | 9999 | GoTrue authentication |
| Kong | 8443 | API gateway |

## Development

### Prerequisites

- Docker Engine 24.0+
- Docker Compose v2.20+

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

### Database Migrations

Migrations are automatically applied on first startup from `migrations/` directory.

### Adding New Migrations

1. Create a new file in `migrations/` with format `NNN_description.sql`
2. Restart services to apply: `docker compose restart postgres`

## CI/CD

GitHub Actions workflows are configured for:
- **Lint & Test** - On every PR and push
- **Build** - On push to main/develop
- **Security Audit** - Regular security checks

## Architecture

See [docs/01-architecture.md](../docs/01-architecture.md) for full architecture details.
