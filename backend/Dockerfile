# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim AS dependency-base

WORKDIR /app

# Copy workspace manifests first so dependency installation remains cacheable.
COPY package.json package-lock.json ./
COPY backend/package.json ./backend/package.json
COPY packages/shared/package.json ./packages/shared/package.json
COPY web/package.json ./web/package.json

FROM dependency-base AS development-dependencies
RUN npm ci --ignore-scripts

FROM development-dependencies AS build
COPY backend ./backend
COPY packages/shared ./packages/shared
RUN npm run build --workspace=@technopro/shared \
    && npm run build --workspace=@technopro/backend

# This target intentionally retains drizzle-kit and the TypeScript migration
# sources. It is used only by the one-shot `migrate` Compose service.
FROM build AS migration
ENV NODE_ENV=production
WORKDIR /app/backend
CMD ["npm", "run", "db:migrate"]

FROM dependency-base AS production-dependencies
ENV NODE_ENV=production
RUN npm ci --omit=dev --ignore-scripts \
      --workspace=@technopro/backend \
      --workspace=@technopro/shared \
    && npm cache clean --force

FROM node:22-bookworm-slim AS api

ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app/backend

COPY --from=production-dependencies /app/node_modules /app/node_modules
COPY --from=production-dependencies /app/backend/package.json ./package.json
COPY --from=production-dependencies /app/packages/shared/package.json /app/packages/shared/package.json
COPY --from=build /app/backend/dist ./dist

# A named volume is mounted here in production. Pre-creating the directory
# gives a newly-created volume the unprivileged node user's ownership.
RUN mkdir -p /app/backend/uploads \
    && chown -R node:node /app/backend /app/packages

USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:3000/api/v1/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"]

CMD ["node", "dist/index.js"]
