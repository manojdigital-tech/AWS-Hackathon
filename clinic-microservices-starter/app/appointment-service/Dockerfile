# syntax=docker/dockerfile:1
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3002
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3002/health || exit 1
CMD ["node", "src/index.js"]
