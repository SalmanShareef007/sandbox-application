FROM node:24-trixie-slim AS build
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ENV NEXT_STANDALONE=true \
    NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM node:24-trixie-slim AS runtime
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV NODE_ENV=production HOSTNAME=0.0.0.0 PORT=3000 NEXT_TELEMETRY_DISABLED=1
COPY --from=build --chown=node:node /app/.next/standalone ./
COPY --from=build --chown=node:node /app/.next/static ./.next/static
COPY --from=build --chown=node:node /app/public ./public
COPY --from=build --chown=node:node /app/write-config.mjs ./write-config.mjs
USER node
EXPOSE 3000
# Per-customer values are read from the environment at startup and written to public/config.js.
CMD ["sh", "-c", "node write-config.mjs && node server.js"]
