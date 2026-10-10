#!/usr/bin/env bash
# Build the agent image for linux/arm64 and push it to an existing Amazon ECR
# repository, tagged `latest`. Unlike some other projects, this script does NOT
# create the repository: if it does not exist, it tells you and stops, so you
# create it yourself first (see Step 3 of the article).
#
# Usage:
#   AWS_PROFILE=<your-profile> ./scripts/build_and_push.sh
# Optional overrides: AWS_REGION, ECR_REPO, IMAGE_TAG
set -euo pipefail

# --- Configuration (edit here) ---------------------------------------------
ECR_REPO="${ECR_REPO:-agentcore/car-agent-runtime}"
AWS_REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
# ---------------------------------------------------------------------------

# --- Make sure the Docker daemon is running --------------------------------
# `docker info` only succeeds when the daemon is up and reachable.
wait_for_docker() {
  local tries=0
  while ! docker info >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -gt 60 ]; then   # ~90s (60 x 1.5s)
      return 1
    fi
    sleep 1.5
  done
  return 0
}

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not running. Trying to start it..."
  case "$(uname -s)" in
    Darwin)
      open -a Docker 2>/dev/null || true   # macOS: start Docker Desktop
      ;;
    Linux)
      sudo systemctl start docker 2>/dev/null || true
      ;;
    *)
      echo "ERROR: unsupported OS; start Docker manually and re-run." >&2
      exit 1
      ;;
  esac
  echo "Waiting for the Docker daemon to become ready..."
  if ! wait_for_docker; then
    echo "ERROR: Docker did not become ready in time. Start it manually and re-run." >&2
    exit 1
  fi
fi
echo "Docker daemon is running."
# ---------------------------------------------------------------------------

# Build context is the project root (where the Dockerfile and agent.py live).
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE="${REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"

# Fail early if the repository does not exist. We do not create it here.
if ! aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "ERROR: ECR repository '${ECR_REPO}' does not exist in ${AWS_REGION}." >&2
  echo "Create it first, for example:" >&2
  echo "  aws ecr create-repository --repository-name ${ECR_REPO} --region ${AWS_REGION}" >&2
  exit 1
fi

aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"

echo "Building ${IMAGE}"
# --provenance=false --sbom=false keep the push to a single image manifest,
# without extra untagged attestation/index entries in ECR.
docker buildx build --platform linux/arm64 \
  --provenance=false --sbom=false \
  --tag "${IMAGE}" --push "${ROOT_DIR}"
echo "Pushed ${IMAGE}"
