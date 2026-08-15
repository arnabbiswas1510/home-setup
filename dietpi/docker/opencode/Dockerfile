FROM ghcr.io/anomalyco/opencode:latest

USER root

# 1. Install libc6-compat and gcompat (This provides the missing ld-linux-x86-64.so.2)
RUN apk add --no-cache libc6-compat gcompat nodejs npm

# 2. Fix the path so Bun can find the loader exactly where it expects it
RUN [ ! -e /lib64/ld-linux-x86-64.so.2 ] && ln -s /lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2 || true

WORKDIR /projects
