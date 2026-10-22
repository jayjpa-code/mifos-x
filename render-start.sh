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

# Render creates a physical database name that can differ from the requested
# Blueprint name. Use the actual database property injected by Render.
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

# Wait for Render Postgres to accept connections before starting Fineract.
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

# Fineract requires a tenant registry database plus a separate default tenant
# database. Render provisions the registry database; create the tenant database
# on the same Postgres instance on first boot if it does not exist yet.
if ! psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc \
  "SELECT 1 FROM pg_database WHERE datname = '${TENANT_DB_NAME}'" | grep -q 1; then
  echo "Creating Fineract tenant database ${TENANT_DB_NAME}"
  createdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${TENANT_DB_NAME}"
fi
unset PGPASSWORD

# Render terminates TLS at the edge. Bind its public port immediately and proxy
# to Fineract's internal HTTP port so slow Spring startup does not fail Render's
# port scan. Connections will succeed as soon as Fineract is ready.
socat TCP-LISTEN:"${PUBLIC_PORT}",fork,reuseaddr TCP:127.0.0.1:"${FINERACT_INTERNAL_PORT}" &
PROXY_PID=$!
trap 'kill ${PROXY_PID} 2>/dev/null || true' EXIT INT TERM

export FINERACT_SERVER_SSL_ENABLED="false"
export FINERACT_SERVER_PORT="${FINERACT_INTERNAL_PORT}"
export FINERACT_SERVER_SERVLET_CONTEXT_PATH="${FINERACT_SERVER_SERVLET_CONTEXT_PATH:-/fineract-provider}"

# Keep the initial validation deployment conservative on memory and DB connections.
export FINERACT_HIKARI_MINIMUM_IDLE="${FINERACT_HIKARI_MINIMUM_IDLE:-1}"
export FINERACT_HIKARI_MAXIMUM_POOL_SIZE="${FINERACT_HIKARI_MAXIMUM_POOL_SIZE:-5}"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Xms64m -Xmx240m -XX:MaxMetaspaceSize=96m -XX:ReservedCodeCacheSize=48m -XX:+UseContainerSupport -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Manila -Dspring.main.lazy-initialization=true}"

# Jib-generated Fineract images expose the calculated runtime classpath and main class here.
java -cp @/app/jib-classpath-file @/app/jib-main-class-file &
JAVA_PID=$!
wait "${JAVA_PID}"
