# syntax=docker/dockerfile:1.7
FROM debian:trixie-slim AS build
ARG LOGSEQ_REF=master
ARG MISE_VERSION=v2026.4.11

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/root/.local/bin:$PATH
ENV MISE_YES=1

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://mise.run | MISE_VERSION="${MISE_VERSION}" sh

WORKDIR /tooling
COPY mise.toml /tooling/mise.toml
RUN mise trust /tooling/mise.toml && mise install

WORKDIR /src
RUN git init . \
  && git remote add origin https://github.com/logseq/logseq.git \
  && git fetch --depth 1 origin "${LOGSEQ_REF}" \
  && git checkout --detach FETCH_HEAD

COPY mise.toml /src/mise.toml
RUN mise trust /src/mise.toml

RUN mise exec -- corepack enable
RUN --mount=type=cache,target=/root/.local/share/pnpm/store mise exec -- pnpm install --frozen-lockfile

WORKDIR /src/deps/db-sync
RUN mise exec -- pnpm build:node-adapter

# Use pnpm deploy to isolate db-sync and its production dependencies
WORKDIR /src
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    mise exec -- pnpm --filter=db-sync deploy /pruned-app

RUN mkdir -p /tmp/runtime-data

# ---------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------
FROM gcr.io/distroless/nodejs22-debian12:nonroot

WORKDIR /app

# Copy from build stage
COPY --chown=nonroot:nonroot --from=build /pruned-app /app
COPY --chown=nonroot:nonroot --from=build /tmp/runtime-data /app/data

ENV DB_SYNC_PORT=8787
EXPOSE 8787

# Execute directly out of the flattened worker output path inside the copied folder
CMD ["worker/dist/node-adapter.js"]
