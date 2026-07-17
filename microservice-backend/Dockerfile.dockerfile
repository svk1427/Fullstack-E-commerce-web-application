FROM node:Alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm install

RUN npm ci

COPY . .

RUN npm run build

### Runtime image

FROM node:Alpine

WORKDIR /app

COPY FROM builder /app/dist ./dist
COPY FROM builder /app/node_modules ./node_modules

cmd ["node", "dist/index.js"]