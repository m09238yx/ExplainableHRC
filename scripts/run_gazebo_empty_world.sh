#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="${repo_root}/docker/compose.yaml"
world_file="${repo_root}/simulation/worlds/minimal_robot_world.sdf"
container_world="/tmp/minimal_robot_world.sdf"

for command_name in docker; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "${command_name}" >&2
        exit 1
    fi
done

if ! docker compose version >/dev/null 2>&1; then
    printf 'Docker Compose v2 is required.\n' >&2
    exit 1
fi

if [[ ! -f "${world_file}" ]]; then
    printf 'World file not found: %s\n' "${world_file}" >&2
    exit 1
fi

if [[ -z "$(docker compose -f "${compose_file}" ps --status running -q ros2-desktop)" ]]; then
    printf 'The ros2-desktop container is not running.\n' >&2
    printf 'Start it with: docker compose -f "%s" up -d\n' "${compose_file}" >&2
    exit 1
fi

docker compose -f "${compose_file}" cp \
    "${world_file}" "ros2-desktop:${container_world}"

docker compose -f "${compose_file}" exec \
    --user ubuntu \
    --env DISPLAY=:1 \
    --env LIBGL_ALWAYS_SOFTWARE=1 \
    ros2-desktop \
    bash -lc '
        set -eo pipefail

        : "${ROS_DISTRO:?ROS_DISTRO is not set}"
        ros_setup="/opt/ros/${ROS_DISTRO}/setup.bash"
        if [[ ! -f "${ros_setup}" ]]; then
            printf "ROS setup file not found: %s\n" "${ros_setup}" >&2
            exit 1
        fi
        source "${ros_setup}"
        set -u

        for command_name in gz ros2; do
            if ! command -v "${command_name}" >/dev/null 2>&1; then
                printf "Required command not found in container: %s\n" "${command_name}" >&2
                exit 1
            fi
        done

        cleanup() {
            trap - EXIT INT TERM
            kill "${bridge_pid:-}" "${gazebo_pid:-}" 2>/dev/null || true
            wait "${bridge_pid:-}" "${gazebo_pid:-}" 2>/dev/null || true
        }
        trap cleanup EXIT INT TERM

        gz sim -r -v 4 /tmp/minimal_robot_world.sdf &
        gazebo_pid=$!

        for attempt in {1..30}; do
            if gz topic -l 2>/dev/null |
                grep -qx "/model/minimal_robot/odometry"; then
                break
            fi
            if ! kill -0 "${gazebo_pid}" 2>/dev/null; then
                printf "Gazebo exited before the robot topics became available.\n" >&2
                exit 1
            fi
            if [[ "${attempt}" -eq 30 ]]; then
                printf "Timed out waiting for the robot odometry topic.\n" >&2
                exit 1
            fi
            sleep 1
        done

        ros2 run ros_gz_bridge parameter_bridge \
            "/model/minimal_robot/cmd_vel@geometry_msgs/msg/Twist]gz.msgs.Twist" \
            "/model/minimal_robot/odometry@nav_msgs/msg/Odometry[gz.msgs.Odometry" &
        bridge_pid=$!

        printf "\nMinimal robot demo is running.\n"
        printf "Open the desktop at http://127.0.0.1:6080/\n"
        printf "In a browser-desktop terminal, run:\n\n"
        printf "Forward:\n"
        printf "  ros2 topic pub --rate 10 /model/minimal_robot/cmd_vel geometry_msgs/msg/Twist \"{linear: {x: 0.8}, angular: {z: 0.0}}\"\n\n"
        printf "Stop (after pressing Ctrl-C in the active publisher):\n"
        printf "  ros2 topic pub --once /model/minimal_robot/cmd_vel geometry_msgs/msg/Twist \"{linear: {x: 0.0}, angular: {z: 0.0}}\"\n\n"
        printf "Inspect odometry:\n"
        printf "  ros2 topic echo /model/minimal_robot/odometry nav_msgs/msg/Odometry\n\n"
        printf "Press Ctrl-C here to stop Gazebo and the bridges.\n\n"

        wait "${gazebo_pid}"
    '
