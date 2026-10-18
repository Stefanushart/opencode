FROM docker.io/library/node:24-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git curl ca-certificates openssh-client ripgrep gosu tini \
    && rm -rf /var/lib/apt/lists/*

ARG OPENCODE_VERSION=2.0.32
RUN npm install -g "@opencode/cli@${OPENCODE_VERSION}" \
    && npm cache clean --force \
    && opencode --version

RUN useradd --uid 10001 --home-dir /data/home --no-create-home --shell /bin/sh opencode

ENV HOME=/data/home \
    PORT=4096 \
    NPM_CONFIG_CACHE=/tmp/npm-cache

COPY --chmod=755 start.sh /usr/local/bin/start-opencode

EXPOSE 4096
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/start-opencode"]
