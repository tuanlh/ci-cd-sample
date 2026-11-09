#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"
: "${IMAGE_REF:?Set IMAGE_REF}"
: "${EXPECTED_VERSION:?Set EXPECTED_VERSION}"
[[ "$IMAGE_REF" =~ ^ghcr\.io/[a-z0-9._/-]+@sha256:[a-f0-9]{64}$ ]] || { echo 'Invalid image digest'; exit 1; }
[[ "$EXPECTED_VERSION" =~ ^[a-f0-9]{40}$ ]] || { echo 'Expected version must be a full commit SHA'; exit 1; }
# Also prevents manual and automatic deployments from racing on this host.
exec 9>.deploy.lock
flock -w 300 9
export IMAGE_REF
compose=(docker compose -p taskapi-staging -f compose.yaml)
old_id=$("${compose[@]}" ps -q api)
previous=''
if [[ -n "$old_id" ]]; then previous=$(docker inspect --format '{{.Config.Image}}' "$old_id"); fi
# Pull before replacing the running container. Pull failure leaves it untouched.
"${compose[@]}" pull api
rollback() {
  trap - ERR
  echo 'Deployment failed. Container logs:'
  "${compose[@]}" logs --tail 100 api || true
  if [[ -n "$previous" ]]; then
    export IMAGE_REF="$previous"
    "${compose[@]}" up -d --no-build --pull never api
    echo "Restored previous image: $previous; inspect health before declaring recovery."
  else
    "${compose[@]}" stop api || true
    echo 'First deployment failed; no previous image to restore.'
  fi
  exit 1
}
trap rollback ERR
"${compose[@]}" up -d --no-build api
ready=false
for attempt in {1..30}; do
  if curl -fsS --max-time 3 http://127.0.0.1:8080/health | grep -Fq '"status":"healthy"'; then
    if curl -fsS --max-time 3 http://127.0.0.1:8080/version | grep -Fq "\"version\":\"$EXPECTED_VERSION\""; then
      ready=true
      break
    fi
  fi
  sleep 2
done
[[ "$ready" == true ]] || { echo 'Health/version verification failed'; false; }
printf '%s\n' "$previous" > previous-image.txt
printf '%s\n' "$IMAGE_REF" > current-image.txt
trap - ERR
echo "PASS: deployed $IMAGE_REF, commit $EXPECTED_VERSION"
