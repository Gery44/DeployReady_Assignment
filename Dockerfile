# ── Stage 1: install dependencies ────────────────────────────────────────────
# Use a pinned LTS Alpine image to keep the final image small and reproducible.
FROM node:20.14.0-alpine3.20 AS deps

WORKDIR /app

# Copy only the manifest files first so Docker can cache this layer.
# The layer is only invalidated when package.json or package-lock.json changes.
COPY app/package.json app/package-lock.json ./

# Install production dependencies only — devDependencies are not needed at runtime.
RUN npm ci --omit=dev

# ── Stage 2: production image ─────────────────────────────────────────────────
# Start from the same base to avoid pulling a second image.
FROM node:20.14.0-alpine3.20 AS production

# Set NODE_ENV so any library that branches on it uses production defaults.
ENV NODE_ENV=production

WORKDIR /app

# Copy only the pruned node_modules from the deps stage.
COPY --from=deps /app/node_modules ./node_modules

# Copy the application source code.
COPY app/ ./

# Create a non-root user and group, then transfer ownership.
# Running as root inside a container is a security risk.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
    && chown -R appuser:appgroup /app

USER appuser

# Expose the port the app listens on (informational; overridden by PORT env var).
EXPOSE 3000

# Use the PORT environment variable; the app already reads process.env.PORT.
ENV PORT=3000

# Run the application. Using the array form avoids a shell wrapper, which means
# signals (SIGTERM, SIGINT) are delivered directly to the Node process — essential
# for graceful shutdown in a container orchestrator.
CMD ["node", "index.js"]
