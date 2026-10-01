# Castlie Connect WebSocket Hub for Coolify
FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install --omit=dev

# Copy server code
COPY server.js ./

ENV NODE_ENV=production

EXPOSE 80 3000

# Dynamic healthcheck using Node.js directly on process.env.PORT
HEALTHCHECK --interval=15s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:' + (process.env.PORT || 80) + '/health', res => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "server.js"]
