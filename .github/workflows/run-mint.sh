#!/bin/bash
#
# This script runs the Mint S3 compatibility test suite.
# It uses the forked mint image from GHCR.
#
# Required environment variable:
#   MINT_IMAGE - The mint Docker image to use (e.g., ghcr.io/username/mint:edge)
#

set -ex

if [ -z "$MINT_IMAGE" ]; then
    # Default to gmautner's forked mint image
    export MINT_IMAGE="ghcr.io/gmautner/mint:edge"
fi

if [ -z "$MINIO_IMAGE" ]; then
    echo "ERROR: MINIO_IMAGE environment variable is not set"
    echo "Please set it to the locally built MinIO image, e.g.:"
    echo "  export MINIO_IMAGE=minio-test:abc123"
    exit 1
fi

export MODE="$1"
export ACCESS_KEY="$2"
export SECRET_KEY="$3"
export JOB_NAME="$4"
export MINT_MODE="full"

docker system prune -f || true
docker volume prune -f || true
docker volume rm $(docker volume ls -f dangling=true) || true

## change working directory
cd .github/workflows/mint

## pull the mint image
echo "Using mint image: $MINT_IMAGE"
docker pull "$MINT_IMAGE"

docker compose -f minio-${MODE}.yaml up -d
sleep 1m

docker system prune -f || true
docker volume prune -f || true
docker volume rm $(docker volume ls -q -f dangling=true) || true

# Stop two nodes, one of each pool, to check that all S3 calls work while quorum is still there
[ "${MODE}" == "pools" ] && docker compose -f minio-${MODE}.yaml stop minio2
[ "${MODE}" == "pools" ] && docker compose -f minio-${MODE}.yaml stop minio6

# Pause one node, to check that all S3 calls work while one node goes wrong
[ "${MODE}" == "resiliency" ] && docker compose -f minio-${MODE}.yaml pause minio4

docker run --rm --net=mint_default \
	--name="mint-${MODE}-${JOB_NAME}" \
	-e SERVER_ENDPOINT="nginx:9000" \
	-e ACCESS_KEY="${ACCESS_KEY}" \
	-e SECRET_KEY="${SECRET_KEY}" \
	-e ENABLE_HTTPS=0 \
	-e MINT_MODE="${MINT_MODE}" \
	"$MINT_IMAGE"

# FIXME: enable this after fixing aws-sdk-java-v2 tests
# # unpause the node, to check that all S3 calls work while one node goes wrong
# [ "${MODE}" == "resiliency" ] && docker compose -f minio-${MODE}.yaml unpause minio4
# [ "${MODE}" == "resiliency" ] && docker run --rm --net=mint_default \
# 	--name="mint-${MODE}-${JOB_NAME}" \
# 	-e SERVER_ENDPOINT="nginx:9000" \
# 	-e ACCESS_KEY="${ACCESS_KEY}" \
# 	-e SECRET_KEY="${SECRET_KEY}" \
# 	-e ENABLE_HTTPS=0 \
# 	-e MINT_MODE="${MINT_MODE}" \
# 	"$MINT_IMAGE"

docker compose -f minio-${MODE}.yaml down || true
sleep 10s

docker system prune -f || true
docker volume prune -f || true
docker volume rm $(docker volume ls -q -f dangling=true) || true

## change working directory
cd ../../../
