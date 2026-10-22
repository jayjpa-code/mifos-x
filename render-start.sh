#!/bin/sh
set -eu

: "${DB_HOST:?DB_HOST is required}"
: "${DB_PORT:?DB_PORT is required}"
: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"

TENANT_DB_NAME="${FINERACT_DEFAULT_TENANTDB_NAME:-fineract_default}"
PUBLIC_PORT="${PORT:-10000}"
FINERACT_INTERNAL_PORT="${FINERACT_INTERNAL_PORT:-8443}"

export FINERACT_HIKARI_DRIVER_SOURCE_CLASS_NAME="org.postgresql.Driver"
export FINERACT_HIKARI_JDBC_URL="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"
export FINERACT_HIKARI_USERNAME="${DB_USER}"
export FINERACT_HIKARI_PASSWORD="${DB_PASSWORD}"

export FINERACT_DEFAULT_TENANTDB_HOSTNAME="${DB_HOST}"
export FINERACT_DEFAULT_TENANTDB_PORT="${DB_PORT}"
export FINERACT_DEFAULT_TENANTDB_UID="${DB_USER}"
export FINERACT_DEFAULT_TENANTDB_PWD="${DB_PASSWORD}"
export FINERACT_DEFAULT_TENANTDB_NAME="${TENANT_DB_NAME}"
export FINERACT_DEFAULT_TENANTDB_IDENTIFIER="${FINERACT_DEFAULT_TENANTDB_IDENTIFIER:-default}"
export FINERACT_DEFAULT_TENANTDB_DESCRIPTION="${FINERACT_DEFAULT_TENANTDB_DESCRIPTION:-KoreNXT Mifos Default Tenant}"
export FINERACT_DEFAULT_TENANTDB_CONN_PARAMS="${FINERACT_DEFAULT_TENANTDB_CONN_PARAMS:-}"

export PGPASSWORD="${DB_PASSWORD}"
attempt=1
while ! pg_isready -q -h "${DB_HOST}" -p "${DB_PORT}" -d "${DB_NAME}" -U "${DB_USER}"; do
  if [ "${attempt}" -ge 60 ]; then
    echo "Postgres did not become ready in time" >&2
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 2
done

if ! psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
  "SELECT 1 FROM pg_database WHERE datname = '${TENANT_DB_NAME}'" | grep -q 1; then
  echo "Creating Fineract tenant database ${TENANT_DB_NAME}"
  createdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${TENANT_DB_NAME}"
fi
unset PGPASSWORD

# Render must see a real HTTP listener and a successful health response while
# Fineract warms up. A tiny per-connection helper avoids pulling another web
# server into the image. It answers only during bootstrap; once Fineract opens
# its internal port this listener is replaced by a transparent proxy.
cat > /tmp/bootstrap-http.sh <<'EOF'
#!/bin/sh
printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n{"status":"UP","component":"bootstrap","fineractReady":false}\n'
EOF
chmod 0755 /tmp/bootstrap-http.sh
socat "TCP-LISTEN:${PUBLIC_PORT},fork,reuseaddr" EXEC:/tmp/bootstrap-http.sh &
BOOTSTRAP_PID=$!
WATCH_PID=""
JAVA_PID=""

cleanup() {
  [ -z "${WATCH_PID}" ] || kill "${WATCH_PID}" 2>/dev/null || true
  [ -z "${BOOTSTRAP_PID}" ] || kill "${BOOTSTRAP_PID}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

export FINERACT_SERVER_SSL_ENABLED="false"
export FINERACT_SERVER_PORT="${FINERACT_INTERNAL_PORT}"
export FINERACT_SERVER_SERVLET_CONTEXT_PATH="${FINERACT_SERVER_SERVLET_CONTEXT_PATH:-/fineract-provider}"

export FINERACT_HIKARI_MINIMUM_IDLE="${FINERACT_HIKARI_MINIMUM_IDLE:-1}"
export FINERACT_HIKARI_MAXIMUM_POOL_SIZE="${FINERACT_HIKARI_MAXIMUM_POOL_SIZE:-4}"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Xms64m -Xmx220m -XX:MaxMetaspaceSize=128m -XX:ReservedCodeCacheSize=32m -XX:+UseContainerSupport -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Manila -Dspring.main.lazy-initialization=true}"

java -cp @/app/jib-classpath-file @/app/jib-main-class-file &
JAVA_PID=$!

(
  while kill -0 "${JAVA_PID}" 2>/dev/null; do
    if socat -T1 -u /dev/null "TCP:127.0.0.1:${FINERACT_INTERNAL_PORT}" >/dev/null 2>&1; then
      echo "Fineract is accepting connections on ${FINERACT_INTERNAL_PORT}; switching public traffic"
      kill "${BOOTSTRAP_PID}" 2>/dev/null || true
      wait "${BOOTSTRAP_PID}" 2>/dev/null || true
      exec socat "TCP-LISTEN:${PUBLIC_PORT},fork,reuseaddr" "TCP:127.0.0.1:${FINERACT_INTERNAL_PORT}"
    fi
    sleep 2
  done
) &
WATCH_PID=$!

wait "${JAVA_PID}"
