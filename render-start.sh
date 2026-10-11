#!/bin/sh
set -eu

: "${DB_HOST:?DB_HOST is required}"
: "${DB_PORT:?DB_PORT is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"

export FINERACT_HIKARI_DRIVER_SOURCE_CLASS_NAME="org.postgresql.Driver"
export FINERACT_HIKARI_JDBC_URL="jdbc:postgresql://${DB_HOST}:${DB_PORT}/fineract_tenants"
export FINERACT_HIKARI_USERNAME="${DB_USER}"
export FINERACT_HIKARI_PASSWORD="${DB_PASSWORD}"

export FINERACT_DEFAULT_TENANTDB_HOSTNAME="${DB_HOST}"
export FINERACT_DEFAULT_TENANTDB_PORT="${DB_PORT}"
export FINERACT_DEFAULT_TENANTDB_UID="${DB_USER}"
export FINERACT_DEFAULT_TENANTDB_PWD="${DB_PASSWORD}"
export FINERACT_DEFAULT_TENANTDB_NAME="${FINERACT_DEFAULT_TENANTDB_NAME:-fineract_default}"
export FINERACT_DEFAULT_TENANTDB_IDENTIFIER="${FINERACT_DEFAULT_TENANTDB_IDENTIFIER:-default}"
export FINERACT_DEFAULT_TENANTDB_DESCRIPTION="${FINERACT_DEFAULT_TENANTDB_DESCRIPTION:-KoreNXT Mifos Default Tenant}"
export FINERACT_DEFAULT_TENANTDB_CONN_PARAMS="${FINERACT_DEFAULT_TENANTDB_CONN_PARAMS:-}"

# Render terminates TLS at the edge and forwards requests to this container over HTTP.
export FINERACT_SERVER_SSL_ENABLED="false"
export FINERACT_SERVER_PORT="${PORT:-10000}"
export FINERACT_SERVER_SERVLET_CONTEXT_PATH="${FINERACT_SERVER_SERVLET_CONTEXT_PATH:-/fineract-provider}"

# Keep the initial validation deployment conservative on memory and DB connections.
export FINERACT_HIKARI_MINIMUM_IDLE="${FINERACT_HIKARI_MINIMUM_IDLE:-1}"
export FINERACT_HIKARI_MAXIMUM_POOL_SIZE="${FINERACT_HIKARI_MAXIMUM_POOL_SIZE:-5}"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Xms128m -Xmx360m -XX:MaxMetaspaceSize=128m -XX:+UseContainerSupport -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Manila}"

# Jib-generated Fineract images expose the calculated runtime classpath and main class here.
exec java -cp @/app/jib-classpath-file @/app/jib-main-class-file
