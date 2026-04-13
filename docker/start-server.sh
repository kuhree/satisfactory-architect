#!/bin/sh
# Launcher for the Deno collaboration server inside the Docker image.
# Environment variables:
#   DATABASE_PATH  — SQLite path or :memory:  (default: /data/db.sqlite)
#   SERVER_PORT    — listening port            (default: 8080)
# Any additional flags accepted by src/main.ts can be appended here or
# passed as extra arguments when invoking this script directly.
set -e

DB_PATH="${DATABASE_PATH:-/data/db.sqlite}"
SERVER_PORT="${SERVER_PORT:-8080}"

# Path to the prebuilt @mongodb-js/zstd native addon inside the image.
ZSTD_NODE="/app/server/node_modules/.deno/@mongodb-js+zstd@2.0.0/node_modules/@mongodb-js/zstd/build/Release/zstd.node"

DENO_FLAGS="--allow-net --allow-ffi=${ZSTD_NODE}"

# Grant filesystem access only when writing to a real path, not :memory:.
if [ "${DB_PATH}" != ":memory:" ]; then
    DENO_FLAGS="${DENO_FLAGS} --allow-read=${DB_PATH},${DB_PATH}-journal"
    DENO_FLAGS="${DENO_FLAGS} --allow-write=${DB_PATH},${DB_PATH}-journal"
fi

# shellcheck disable=SC2086  # intentional word-splitting of DENO_FLAGS
exec deno run \
    ${DENO_FLAGS} \
    /app/server/src/main.ts \
    --database-path="${DB_PATH}" \
    --port="${SERVER_PORT}" \
    "$@"
