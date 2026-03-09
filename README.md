# Zope 5 w/ Eionet Data Repository Add-ons ready to run Docker image

Modern, optimized, and hardened Docker image for Reportek based on Docker Hardened Images (DHI) (`dhi.io/python:3.12-debian13`) and Python 3.12.

## Features

- **Fast Package Installation**: Uses [uv](https://github.com/astral-sh/uv) instead of pip for 10-100x faster Python package installation.
- **Multi-stage Build**: Smaller final image size by separating build and runtime dependencies.
- **Optimized Caching**: Better Docker layer caching for faster rebuilds.
- **Security**: Runs as non-root user with proper permission handling.
- **Health Checks**: Built-in health monitoring.
- **Production Ready**: Includes proper logging, monitoring, and error handling.

## Quick Start

### Build the Image

```bash
# Build the image
docker build -t reportek:latest .

# Or using docker-compose
docker-compose build
```

### Run Zope

```bash
# Using Docker
docker run -p 8080:8080 reportek:latest

# Using docker-compose
docker-compose up -d
```

Access Zope at: http://localhost:8080

Default credentials: `admin` / `admin`

## Running standard profile

By default the `docker-compose.yml` includes the core Zope instances and a lightweight Valkey (Redis) container to manage session data.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ZOPE_HOME` | `/opt/zope` | Zope installation directory |
| `ZOPE_USER` | `zope-www` | User to run Zope as |
| `ZOPE_UID` | `1000` | UID for Zope user |
| `ZOPE_GID` | `1000` | GID for Zope group |
| `ZOPE_ADMIN_USER` | `admin` | Initial admin username |
| `ZOPE_ADMIN_PASSWORD` | `admin` | Initial admin password |
| `USE_BEAKER_SESSION` | `1` | Enables Beaker WSGI middleware for session management |
| `REDIS_URL` | `redis://redis:6379/0` | Redis connection string (Currently used for Beaker sessions) |
| `SESSION_SECRET` | `secret_key` | Secret used for signing session cookies |
| `RELSTORAGE_DSN` | *(empty)* | If provided, connects ZODB to a RelStorage backend (e.g. `dbname='reportek'...`) |
| `ZEO_ADDRESS` | *(empty)* | If set (e.g. `zeo:8100`), Zope connects to this ZEO server instead of using local FileStorage |
| `ZEO_SHARED_BLOB_DIR` | `off` | Declares if the blob directory is natively shared with a ZEO server volume mount (`on` / `off`) |
| `ZODB_CACHE_SIZE` | `50000` | Size of the ZODB cache for the main database |
| `ZOPE_THREADS` | `4` | Number of threads to use in the Waitress WSGI server |
| `ZOPE_DEBUG_MODE` | `off` | Toggles the Zope application debug mode (`on`, `off`) |
| `ZOPE_VERBOSE_SECURITY` | `off` | Toggles verbose security exceptions inside Zope (`on`, `off`) |
| `EVENT_LOG_LEVEL` | `INFO` | The root logging level for Zope/Waitress applications (`INFO`, `DEBUG`, `WARN`, `ERROR`) |
| `ACCESS_LOG_LEVEL` | `WARN` | The WSGI access logging level (`INFO`, `WARN`, `ERROR`) |
| `UNS_NOTIFICATIONS` | *(empty)*| Toggles the Unified Notification System (e.g. `on`) |
| `REPORTEK_DEPLOYMENT` | *(empty)*| Specifies environment (e.g. `CDR`, `BDR`) |
| `DATADICTIONARY_SCHEMAS_URL` | *(empty)* | Custom URL for EIONET DD validation |

## Available Commands

```bash
# Start Zope in foreground mode
docker run reportek:latest fg

# Start Zope console
docker run -it reportek:latest console

# Run zopepy script
docker run reportek:latest zopepy /path/to/script.py

# Start bash shell
docker run -it reportek:latest shell

# Show help
docker run reportek:latest help
```

## Development Mode

Mount your local code for development:

```yaml
# Uncomment in docker-compose.yml
volumes:
  - ./src/Products.Reportek:/opt/zope/src/Products.Reportek
```

Then restart the container to pick up changes:

```bash
docker-compose restart zope
```

## Volumes

The image uses volumes for persistent data:

- `zope-data`: Zope var directory (Data.fs, logs, etc.)
- `redis-data`: Redis cache data

### Backup Data

```bash
# Backup Zope data
docker run --rm \
  -v reportek_zope-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/zope-data-$(date +%Y%m%d).tar.gz -C /data .
```

### Restore Data

```bash
# Restore Zope data
docker run --rm \
  -v reportek_zope-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/zope-data-YYYYMMDD.tar.gz -C /data
```

### Clean rebuild

Remove all containers and volumes:
```bash
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

## Performance Tuning

### For Development
```yaml
# docker-compose.override.yml
services:
  zope:
    environment:
      - ZOPE_DEBUG_MODE=on
    command: fg  # Run in foreground for logs
```

### For Production
```yaml
services:
  zope:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
```

## Maintenance

### Update Base Image

```bash
docker pull python:3.8-slim-bookworm
docker-compose build --pull
```

### Update Dependencies

Edit `requirements.txt` and rebuild:
```bash
docker-compose build --no-cache
```

### Security Scanning

```bash
docker scan reportek:latest
```

## Copyright and license

The Initial Owner of the Original Code is European Environment Agency (EEA).
All Rights Reserved.

The Original Code is free software;
you can redistribute it and/or modify it under the terms of the GNU
General Public License as published by the Free Software Foundation;
either version 2 of the License, or (at your option) any later
version.

## Funding

[European Environment Agency (EU)](http://eea.europa.eu)
