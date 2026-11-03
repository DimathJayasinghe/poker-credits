# Cloud server image: docs/DEPLOY.md
# Build:  docker build -t poker-credits-server .
# Run:    docker run -p 7878:7878 -v poker-data:/data poker-credits-server

FROM rust:1.97.1-slim-bookworm AS build
WORKDIR /src
# Only the members the server needs are built; the bridge crate is part of the workspace manifest
# and must be present, but it is not compiled.
COPY Cargo.toml Cargo.lock rust-toolchain.toml ./
COPY crates ./crates
COPY server ./server
COPY packages/poker_bridge/rust ./packages/poker_bridge/rust
RUN cargo build --release --locked -p poker_server

FROM debian:bookworm-slim
RUN useradd --system --uid 10001 --home-dir /data --shell /usr/sbin/nologin poker \
 && mkdir -p /data && chown poker /data
COPY --from=build /src/target/release/poker_server /usr/local/bin/poker_server
USER poker
ENV POKER_BIND=0.0.0.0:7878 POKER_DATA_DIR=/data RUST_LOG=info
VOLUME /data
EXPOSE 7878
# SIGTERM (docker stop) flushes the journal and closes sockets; give it a moment.
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/local/bin/poker_server"]
