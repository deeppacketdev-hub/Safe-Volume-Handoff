# Castlie Connect WebSocket Hub for Coolify
FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install --omit=dev

# Copy server code
COPY server.js ./

# Set environment
ENV NODE_ENV=production
ENV PORT=80

EXPOSE 80

# Healthcheck for container orchestrators
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:80/health || exit 1

CMD ["node", "server.js"]
