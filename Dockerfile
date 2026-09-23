FROM node:22-alpine AS pac
WORKDIR /pac-generator
COPY .pac-generator/package.json .pac-generator/package-lock.json ./
RUN npm ci --omit=dev
COPY .pac-generator/ ./
ARG PAC_SOURCE_DATE
RUN test -n "$PAC_SOURCE_DATE" && node index.js

FROM alpine:3.24 AS assemble
RUN apk add --no-cache coreutils findutils gzip jq
ARG PUBLIC_SHA
ARG PAC_GENERATOR_SHA
ARG PAC_SOURCE_DATE
COPY . /src
COPY --from=pac /pac-generator /pac-generator
RUN /src/scripts/assemble.sh /src /pac-generator /site

FROM nginx:1.30-alpine AS prod
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY --from=assemble /site /srv/www
