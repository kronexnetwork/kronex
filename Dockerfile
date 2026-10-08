# Packs a released krnxd binary into an image; nothing is compiled here. The
# archive comes from the GitHub release named by VERSION and is checked against
# the SHA256SUMS published next to it, so the image carries the same bytes as
# the release.
#
#   docker build --build-arg VERSION=v1.0.0-testnet.1 -t krnxd .
#
# .github/workflows/docker.yml runs this for linux/amd64 and linux/arm64 on
# every release and pushes the result to ghcr.io/kronexnetwork/krnxd.

ARG VERSION

# The archive is fetched and unpacked on the build platform. Only the final
# stage is target-specific, and it runs nothing, so no emulation is needed.
FROM --platform=$BUILDPLATFORM alpine:3.22 AS fetch
ARG VERSION
ARG TARGETARCH
RUN test -n "$VERSION" || { echo "VERSION build-arg is required, e.g. --build-arg VERSION=v1.0.0-testnet.1" >&2; exit 1; }
ADD https://github.com/kronexnetwork/kronex/releases/download/${VERSION}/SHA256SUMS /src/
ADD https://github.com/kronexnetwork/kronex/releases/download/${VERSION}/krnxd-${VERSION}-linux-${TARGETARCH}.tar.gz /src/
RUN cd /src \
 && archive="krnxd-${VERSION}-linux-${TARGETARCH}.tar.gz" \
 && grep "  ${archive}\$" SHA256SUMS > sums \
 && test -s sums \
 && sha256sum -c sums \
 && tar -xzf "$archive" \
 && install -D -m 0755 "${archive%.tar.gz}/krnxd" /out/usr/local/bin/krnxd \
 && install -D -m 0644 "${archive%.tar.gz}/COPYING" /out/usr/share/licenses/krnxd/COPYING \
 && install -D -m 0644 "${archive%.tar.gz}/COPYING.LESSER" /out/usr/share/licenses/krnxd/COPYING.LESSER

FROM alpine:3.22
ARG VERSION
COPY --from=fetch /out/ /
EXPOSE 8545 8546 30303 30303/udp
ENTRYPOINT ["krnxd"]
CMD ["--testnet"]
LABEL org.opencontainers.image.title="krnxd" \
      org.opencontainers.image.description="Kronex node" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://github.com/kronexnetwork/kronex" \
      org.opencontainers.image.licenses="GPL-3.0-only"
