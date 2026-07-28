#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker compose -f "${repo_root}/docker/compose.yaml" exec \
    --user ubuntu \
    --env DISPLAY=:1 \
    --env LIBGL_ALWAYS_SOFTWARE=1 \
    ros2-desktop \
    bash -lc 'source /opt/ros/jazzy/setup.bash && exec gz sim -v 4 empty.sdf'
