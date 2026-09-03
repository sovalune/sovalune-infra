# Sovalune Infrastructure

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Git

### Running the Stack

1. Clone the repository:
```bash
git clone https://github.com/sovalune/sovalune-infra.git
cd sovalune-infra
```

2. Start all services:
```bash
docker-compose up -d
```

3. Check the status:
```bash
docker-compose ps
```

### Services

| Service | Port | Description |
|---------|------|-------------|
| PostgreSQL | 5432 | Database with pgvector |
| NATS | 4222 | Message bus with JetStream |
| Studio | 3000 | Supabase Studio |
| API Gateway | 8000 | PostgREST |
| Storage | 5000 | Object Storage |
| Auth | 9999 | GoTrue |
| Kong | 8080, 8443 | API Gateway |
| Sovalune Core | 8090, 8091 | Rust Backend |
| Sovalune Frontend | 3001 | Next.js Frontend |

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Key variables:
- `POSTGRES_PASSWORD`: Database password
- `JWT_SECRET`: JWT signing secret
- `NATS_URL`: NATS connection URL

### Database Migrations

Migrations are automatically applied when PostgreSQL starts. They are located in `migrations/`:

1. `001_initial_schema.sql` - Core tables
2. `002_decay_cron_and_functions.sql` - Decay cron and functions
3. `003_optimization_and_triggers.sql` - Indexes and triggers

### Development

To rebuild a specific service:
```bash
docker-compose build sovalune-core
docker-compose up -d sovalune-core
```

To view logs:
```bash
docker-compose logs -f sovalune-core
```

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Sovalune Platform                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Frontend   │  │    Core      │  │    Studio    │     │
│  │   (Next.js)  │  │   (Rust)     │  │  (Supabase)  │     │
│  │   :3001      │  │   :8090      │  │   :3000      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│          │               │               │                 │
│          └───────────────┼───────────────┘                 │
│                          │                                 │
│  ┌───────────────────────┼───────────────────────┐        │
│  │                       │                       │        │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐   │        │
│  │  │PostgreSQL│  │   NATS   │  │   Kong   │   │        │
│  │  │  :5432   │  │  :4222   │  │  :8080   │   │        │
│  │  └──────────┘  └──────────┘  └──────────┘   │        │
│  │                       │                       │        │
│  └───────────────────────┼───────────────────────┘        │
│                          │                                 │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### PostgreSQL won't start
Check if port 5432 is already in use:
```bash
netstat -ano | findstr :5432
```

### NATS connection issues
Ensure NATS is healthy:
```bash
docker-compose ps nats
docker-compose logs nats
```

### Frontend can't connect to API
Check if sovalune-core is running:
```bash
docker-compose ps sovalune-core
curl http://localhost:8090/health/live
```
