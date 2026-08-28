FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171

# Same versions CI builds with (.github/workflows/hugo.yaml). linux/amd64.
ARG HUGO_VERSION=0.164.0
ARG DART_SASS_VERSION=1.97.2
ARG HUGO_SHA256=fea17b8c076f950bb2e9f9486667bdaa29422883888d509d63931c73e8a9b3a4
ARG DART_SASS_SHA256=814df31fa1ba98d15ccea390ac0d8fa00e26cecb075c6b764e35fa61da1cb720

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl tar \
    && curl --fail --location --silent --show-error \
         --output /tmp/hugo.tar.gz \
         "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz" \
    && echo "${HUGO_SHA256}  /tmp/hugo.tar.gz" | sha256sum --check --strict \
    && tar -C /usr/local/bin -xf /tmp/hugo.tar.gz hugo \
    && curl --fail --location --silent --show-error \
         --output /tmp/dart-sass.tar.gz \
         "https://github.com/sass/dart-sass/releases/download/${DART_SASS_VERSION}/dart-sass-${DART_SASS_VERSION}-linux-x64.tar.gz" \
    && echo "${DART_SASS_SHA256}  /tmp/dart-sass.tar.gz" | sha256sum --check --strict \
    && tar -C /usr/local -xf /tmp/dart-sass.tar.gz \
    && ln -s /usr/local/dart-sass/sass /usr/local/bin/sass \
    && rm -f /tmp/hugo.tar.gz /tmp/dart-sass.tar.gz \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

EXPOSE 1313

HEALTHCHECK --interval=5s --timeout=3s --retries=20 --start-period=45s \
    CMD curl -fsS http://127.0.0.1:1313/en/ >/dev/null || exit 1

CMD ["hugo", "server", \
     "--bind", "0.0.0.0", "--port", "1313", \
     "--appendPort=false", "--baseURL", "http://localhost:8080/", \
     "--disableFastRender", "--watch", "--force_polling"]
