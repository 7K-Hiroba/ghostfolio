# =============================================================================
# ghostfolio
# Ghostfolio
# =============================================================================

# -- Build stage
# TODO: Replace with your application's build image and commands
FROM node:20-alpine AS builder

WORKDIR /build
COPY package*.json ./
RUN npm ci --production
COPY . .
RUN npm run build

# -- Runtime stage
FROM gcr.io/distroless/nodejs20-debian12:nonroot

LABEL maintainer="7KGroup <https://github.com/7KGroup>"
LABEL org.opencontainers.image.source="https://github.com/7KGroup/ghostfolio"
LABEL org.opencontainers.image.description="Ghostfolio"

WORKDIR /app

COPY --from=builder /build/dist ./dist
COPY --from=builder /build/node_modules ./node_modules

EXPOSE 8080

ENTRYPOINT ["dist/index.js"]
