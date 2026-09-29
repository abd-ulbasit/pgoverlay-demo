#!/usr/bin/env bash
# Applies pending SQL migrations in order, tracked in schema_migrations.
# Connection comes from the standard libpq env vars (PGHOST, PGPORT,
# PGUSER, PGPASSWORD, PGDATABASE) — so pointing this at a pgoverlay branch
# is just:
#   PGDATABASE="postgres@$(./scripts/pgoverlay-branch.sh owner/repo '' 42)" PGPORT=6432 ./scripts/migrate.sh
set -euo pipefail
cd "$(dirname "$0")/.."

psql -v ON_ERROR_STOP=1 -qc \
  "CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"

for f in migrations/*.sql; do
    v="$(basename "$f" .sql)"
    if [ "$(psql -tAc "SELECT 1 FROM schema_migrations WHERE version='$v'")" = "1" ]; then
        echo "skip  $v (already applied)"
        continue
    fi
    echo "apply $v"
    psql -v ON_ERROR_STOP=1 -q -1 -f "$f" -c "INSERT INTO schema_migrations (version) VALUES ('$v')"
done
echo "migrations up to date"
