FROM node:22-slim

WORKDIR /app
ENV PORT=2567

COPY package*.json tsconfig.json .npmrc* ./
RUN npm install --legacy-peer-deps

COPY src ./src

ENV NODE_ENV=production
EXPOSE 2567

CMD ["npm", "start"]
