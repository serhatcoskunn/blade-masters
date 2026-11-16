FROM node:22-alpine

WORKDIR /app
ENV PORT=2567

COPY package*.json tsconfig.json ./
RUN npm install

COPY src ./src

ENV NODE_ENV=production
EXPOSE 2567

# Healthcheck for Coolify / VPS
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:2567/health || exit 1

CMD ["npm", "start"]
