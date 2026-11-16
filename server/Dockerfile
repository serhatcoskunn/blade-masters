FROM node:22-slim

WORKDIR /app
ENV PORT=2567

# Install curl/wget for healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends curl wget && rm -rf /var/lib/apt/lists/*

COPY package*.json tsconfig.json .npmrc* ./
RUN npm install --legacy-peer-deps

COPY src ./src

ENV NODE_ENV=production
EXPOSE 2567

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:2567/health || exit 1

CMD ["npm", "start"]
