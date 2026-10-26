# Stage 1: build
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .

ARG CLIENT_NAME
RUN if [ -n "$CLIENT_NAME" ]; then \
    grep -rlI "$CLIENT_NAME" --exclude-dir=node_modules . \
    | xargs -r sed -i "s/$CLIENT_NAME S\.A\.S\.\{0,1\}/Empresa Demo S.A.S./g; s/AUD-$CLIENT_NAME/AUD-DEMO/g"; \
    fi

ENV BUILD_STANDALONE=1 \
    NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# Stage 2: run (only what the server needs)
FROM node:22-slim AS run
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
RUN chmod -R a+rX /app
USER node
EXPOSE 3000
CMD ["node", "server.js"]