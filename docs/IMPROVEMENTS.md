# Docker Compose Improvements

## Purpose

This document tracks the practical hardening and maintainability improvements in the template files used by this repo.

## Current improvements

### 1. Security defaults

- Added `socket-proxy` for Docker API mediation instead of direct socket access from tooling containers.
- Kept Docker socket mount read-only in the proxy service.
- Tightened proxy permissions for the current Diun workflow:
  - `CONTAINERS=1`
  - `IMAGES=1`
  - `POST=0`
  - dangerous endpoints disabled (`EXEC`, `SECRETS`, etc.)
- Added `security_opt: no-new-privileges:true` broadly across services.

### 2. Reliability

- Added/standardized health checks.
- Added dependency gates with `depends_on: condition: service_healthy` where useful.
- Consistent restart policy (`unless-stopped`) across templates.

### 3. Synology compatibility

- CPU limits are intentionally not used (DSM/kernel compatibility concerns).
- Memory reservations and limits are retained.

### 4. Observability and operations

- Standardized logging options with `.env` variables:
  - `DOCKERLOGGING_MAXFILE`
  - `DOCKERLOGGING_MAXSIZE`
- Diun included for update notifications (monitor-only, no auto-update behavior).

### 5. Template consistency

- Unified placeholder usage (`{{VAR}}`) for `substitute_env.sh` generation.
- Updated Gramps template to avoid hardcoded URLs and align with shared `.env` keys.
- Added missing `.env.sample` keys for database and VPN provider settings.

## Resource profile (all stacks)

The templates currently define memory-only constraints.

- Total memory reservation: `4.00 GB`
- Total memory limit: `15.00 GB`

## Recommended workflow

```bash
# 1) Generate files from templates
./substitute_env.sh docker-compose-files/arr-stack_template.yaml docker-compose.arr-stack.yml
./substitute_env.sh docker-compose-files/postgres_template.yaml docker-compose.postgres.yml
./substitute_env.sh docker-compose-files/vault_template.yaml docker-compose.vault.yml

# 2) Validate generated compose
docker-compose -f docker-compose.arr-stack.yml config
docker-compose -f docker-compose.postgres.yml config
docker-compose -f docker-compose.vault.yml config

# 3) Deploy
docker-compose -f docker-compose.arr-stack.yml up -d
docker-compose -f docker-compose.postgres.yml up -d
docker-compose -f docker-compose.vault.yml up -d
```

## Notes

- `docs/SOCKET_PROXY.md` contains current proxy-specific validation and troubleshooting.
- `docs/TROUBLESHOOTING.md` is the primary operational runbook.

---

**Last Updated:** 2026-02-14
