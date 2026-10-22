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

# During Fineract warm-up, answer Render's health check only. Real API calls
# receive 503 so clients never mistake the bootstrap process for Fineract.
export BOOTSTRAP_CORS_ORIGIN="${FINERACT_SECURITY_CORS_ALLOWED_ORIGIN_PATTERNS:-*}"
cat > /tmp/bootstrap-http.sh <<'EOF'
#!/bin/sh
set -eu

IFS=' ' read -r METHOD PATH PROTO || exit 0
ORIGIN=""
while IFS= read -r LINE; do
  LINE=$(printf '%s' "$LINE" | tr -d '\r')
  [ -z "$LINE" ] && break
  case "$LINE" in
    [Oo][Rr][Ii][Gg][Ii][Nn]:*) ORIGIN=$(printf '%s' "$LINE" | sed 's/^[^:]*:[[:space:]]*//') ;;
  esac
done

ALLOW_ORIGIN="${BOOTSTRAP_CORS_ORIGIN:-*}"
CORS=""
if [ "$ALLOW_ORIGIN" = "*" ] || [ -z "$ORIGIN" ] || [ "$ORIGIN" = "$ALLOW_ORIGIN" ]; then
  CORS="Access-Control-Allow-Origin: ${ALLOW_ORIGIN}\r\nAccess-Control-Allow-Methods: GET,POST,PUT,PATCH,DELETE,OPTIONS,HEAD\r\nAccess-Control-Allow-Headers: Authorization,Content-Type,Accept,Origin,X-Requested-With,Fineract-Platform-TenantId,X-Correlation-ID\r\nAccess-Control-Expose-Headers: Location,Fineract-Platform-TenantId,X-Correlation-ID\r\nVary: Origin\r\n"
  if [ "$ALLOW_ORIGIN" != "*" ]; then
    CORS="${CORS}Access-Control-Allow-Credentials: true\r\n"
  fi
fi

if [ "$METHOD" = "OPTIONS" ]; then
  printf "HTTP/1.1 204 No Content\r\n${CORS}Connection: close\r\n\r\n"
  exit 0
fi

if [ "$PATH" = "/fineract-provider/actuator/health" ]; then
  BODY='{"status":"UP","component":"bootstrap","fineractReady":false}'
  printf "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n${CORS}Connection: close\r\n\r\n%s\n" "$BODY"
  exit 0
fi

BODY='{"status":"STARTING","component":"bootstrap","fineractReady":false,"message":"Apache Fineract is still starting"}'
printf "HTTP/1.1 503 Service Unavailable\r\nContent-Type: application/json\r\nRetry-After: 15\r\n${CORS}Connection: close\r\n\r\n%s\n" "$BODY"
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
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Xms64m -Xmx220m -XX:MaxMetaspaceSize=128m -XX:ReservedCodeCacheSize=32m -XX:+UseContainerSupport -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Manila -Dspring.main.lazy-initialization=true -Dspring.data.jpa.repositories.bootstrap-mode=lazy}"

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
