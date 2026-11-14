#!/usr/bin/env bash
# 임시 Postgres 클러스터에 Supabase 스텁 + 마이그레이션을 적용하고 RLS 테스트를 실행한다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
TMP="$(mktemp -d)"
PORT="${PGPORT_TEST:-55432}"
cleanup() { "$PGBIN/pg_ctl" -D "$TMP/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap cleanup EXIT

RUNAS=()
if [ "$(id -u)" = "0" ]; then
  chown -R postgres "$TMP" 2>/dev/null || { useradd -m postgres; chown -R postgres "$TMP"; }
  RUNAS=(su postgres -s /bin/bash -c)
  run() { su postgres -s /bin/bash -c "$*"; }
else
  run() { bash -c "$*"; }
fi

run "'$PGBIN/initdb' -D '$TMP/data' -U postgres -A trust >/dev/null"
run "'$PGBIN/pg_ctl' -D '$TMP/data' -o '-p $PORT -k $TMP -c listen_addresses=' -l '$TMP/log' start -w >/dev/null"

PSQL=(psql -h "$TMP" -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q -X)
"${PSQL[@]}" -f "$ROOT/tests/db/supabase-stub.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do
  echo "▶ migrate $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done
for f in "$ROOT"/tests/db/*.test.sql; do
  echo "▶ test $(basename "$f")"
  "${PSQL[@]}" -o /dev/null -f "$f"
done
echo "✔ DB tests passed"
