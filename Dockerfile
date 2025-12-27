# Multi-arch Dockerfile for GHCR publishing
# Uses pre-built binaries (cross-compiled in CI)

FROM alpine:3.23

ARG TARGETARCH
ARG RELEASE

LABEL name="MinIO" \
      vendor="MinIO Fork" \
      maintainer="gmautner" \
      version="${RELEASE}" \
      release="${RELEASE}" \
      summary="MinIO is a High Performance Object Storage, API compatible with Amazon S3 cloud storage service." \
      description="MinIO object storage is fundamentally different. Designed for performance and the S3 API, it is 100% open-source. MinIO is ideal for large, private cloud environments with stringent security requirements and delivers mission-critical availability across a diverse range of workloads."

# Install curl for healthchecks
RUN apk add -U --no-cache ca-certificates curl

ENV MINIO_ACCESS_KEY_FILE=access_key \
    MINIO_SECRET_KEY_FILE=secret_key \
    MINIO_ROOT_USER_FILE=access_key \
    MINIO_ROOT_PASSWORD_FILE=secret_key \
    MINIO_KMS_SECRET_KEY_FILE=kms_master_key \
    MINIO_CONFIG_ENV_FILE=config.env

# Copy the pre-built binary for this architecture
COPY minio-${TARGETARCH} /usr/bin/minio
COPY CREDITS /licenses/CREDITS
COPY LICENSE /licenses/LICENSE
COPY dockerscripts/docker-entrypoint.sh /usr/bin/docker-entrypoint.sh

RUN chmod +x /usr/bin/minio /usr/bin/docker-entrypoint.sh

EXPOSE 9000
VOLUME ["/data"]

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["minio"]
