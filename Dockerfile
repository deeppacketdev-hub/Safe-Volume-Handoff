# Root Dockerfile for Coolify (builds Castlie Connect Server from /server)
FROM node:20-alpine

WORKDIR /app

# Install dependencies from server/
COPY server/package*.json ./
RUN npm install --omit=dev

# Copy server code from server/
COPY server/server.js ./

ENV NODE_ENV=production
ENV PORT=80

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:80/health || exit 1

CMD ["node", "server.js"]
