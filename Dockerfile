# from https://cli.vuejs.org/guide/deployment.html#docker-nginx

FROM node:latest as build-stage
WORKDIR /app
COPY package*.json ./
RUN npm install
RUN npm install @wikimedia/codex d3 --legacy-peer-deps
COPY ./ .
RUN npm run build

FROM nginx as production-stage
RUN mkdir /app
COPY --from=build-stage /app/dist /app
COPY nginx.conf /etc/nginx/nginx.conf