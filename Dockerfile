# ── Stage 1: Build the SvelteKit static site ─────────────────────────────────
# The UI imports from ../../../../server/shared/…, so both trees must live
# under a common root to keep the relative path resolvable at build time.
FROM node:22-alpine AS ui-builder
WORKDIR /app
COPY ui/package*.json ./ui/
RUN cd ui && npm ci
COPY ui/ ./ui/
COPY server/shared/ ./server/shared/
RUN cd ui && npm run build

# ── Stage 2: Fetch and cache all Deno dependencies ────────────────────────────
# Splitting deno.json copy + deno install from the full source copy lets Docker
# cache the (slow) dependency layer independently of source changes.
FROM denoland/deno:latest AS server-deps
ENV DENO_DIR=/app/.deno
WORKDIR /app/server
COPY server/deno.json server/deno.lock* ./
# Downloads all JSR + npm packages; runs @mongodb-js/zstd build script
# (allowScripts in deno.json permits this) to compile the native .node addon.
RUN deno install
COPY server/ .
# Warm the module cache so the final image starts without hitting the network.
RUN deno cache src/main.ts

# ── Final image: nginx + Deno under supervisord ───────────────────────────────
FROM denoland/deno:latest

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        supervisor \
        curl \
    && rm -rf /var/lib/apt/lists/*

ENV DENO_DIR=/app/.deno

# Reverse proxy: serves static files and proxies /ws to the Deno server.
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Static UI assets
COPY --from=ui-builder /app/ui/build /usr/share/nginx/html

# Server source + node_modules (native addon) + JSR module cache
COPY --from=server-deps /app/.deno  /app/.deno
COPY --from=server-deps /app/server /app/server

# Process supervisor and server launcher
COPY docker/supervisord.conf /etc/supervisord.conf
COPY docker/start-server.sh  /usr/local/bin/start-server
RUN chmod +x /usr/local/bin/start-server

# SQLite data volume — mount a named volume or host path for persistence.
# Set DATABASE_PATH=:memory: at runtime to skip persistence entirely.
VOLUME ["/data"]

EXPOSE 80

# Two-part check: nginx serves the SPA, Deno server responds to plain HTTP.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -sf http://localhost/ > /dev/null \
     && curl -sf http://localhost:8080/ > /dev/null

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
