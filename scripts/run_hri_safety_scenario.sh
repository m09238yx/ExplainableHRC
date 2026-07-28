#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="${repo_root}/docker/compose.yaml"
world_file="${repo_root}/simulation/worlds/hri_safety_scenario.sdf"
container_world="/tmp/hri_safety_scenario.sdf"

if ! command -v docker >/dev/null 2>&1; then
    printf 'Required command not found: docker\n' >&2
    exit 1
fi
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
    --no-TTY \
    --user ubuntu \
    --env DISPLAY=:1 \
    --env LIBGL_ALWAYS_SOFTWARE=1 \
    ros2-desktop \
    bash -lc '
        set -eo pipefail

        : "${ROS_DISTRO:?ROS_DISTRO is not set}"
        ros_setup="/opt/ros/${ROS_DISTRO}/setup.bash"
        workspace_setup="/home/ubuntu/ros2_ws/install/setup.bash"
        if [[ ! -f "${ros_setup}" ]]; then
            printf "ROS setup file not found: %s\n" "${ros_setup}" >&2
            exit 1
        fi
        source "${ros_setup}"
        if [[ ! -f "${workspace_setup}" ]]; then
            printf "Workspace is not built. Run the documented colcon build command first.\n" >&2
            exit 1
        fi
        source "${workspace_setup}"
        set -u

        for command_name in gz ros2; do
            if ! command -v "${command_name}" >/dev/null 2>&1; then
                printf "Required command not found in container: %s\n" "${command_name}" >&2
                exit 1
            fi
        done
        if ! ros2 pkg prefix explainable_hrc >/dev/null 2>&1; then
            printf "explainable_hrc is not installed in the workspace.\n" >&2
            printf "Build it with: cd /home/ubuntu/ros2_ws && colcon build --symlink-install\n" >&2
            exit 1
        fi

        cleanup() {
            trap - EXIT INT TERM
            for process_group in \
                "${node_pid:-}" "${bridge_pid:-}" "${gazebo_pid:-}"; do
                if [[ -n "${process_group}" ]]; then
                    kill -- "-${process_group}" 2>/dev/null || true
                fi
            done
            wait "${node_pid:-}" "${bridge_pid:-}" "${gazebo_pid:-}" \
                2>/dev/null || true
        }
        trap cleanup EXIT INT TERM

        setsid gz sim -r -v 4 /tmp/hri_safety_scenario.sdf &
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

        setsid ros2 run ros_gz_bridge parameter_bridge \
            "/model/minimal_robot/cmd_vel@geometry_msgs/msg/Twist]gz.msgs.Twist" \
            "/model/minimal_robot/odometry@nav_msgs/msg/Odometry[gz.msgs.Odometry" &
        bridge_pid=$!

        setsid ros2 run explainable_hrc safety_decision_node \
            --ros-args \
            -p obstacle_x:=8.0 \
            -p obstacle_y:=0.0 \
            -p goal_x:=11.0 \
            -p goal_y:=0.0 \
            -p safety_threshold:=1.0 \
            -p forward_speed:=0.3 \
            -p control_rate:=10.0 \
            -p goal_tolerance:=0.2 &
        node_pid=$!

        printf "\nHRI safety scenario is running.\n"
        printf "Open the desktop at http://127.0.0.1:6080/\n\n"
        printf "Robot command:  /model/minimal_robot/cmd_vel\n"
        printf "Robot odometry: /model/minimal_robot/odometry\n"
        printf "Decisions:      /safety_decision (std_msgs/msg/String JSON)\n\n"
        printf "Inspect odometry:\n"
        printf "  ros2 topic echo /model/minimal_robot/odometry nav_msgs/msg/Odometry\n\n"
        printf "Inspect decision transitions:\n"
        printf "  ros2 topic echo /safety_decision std_msgs/msg/String\n\n"
        printf "Press Ctrl-C here to stop the node, bridge, and Gazebo.\n\n"

        wait "${gazebo_pid}"
    '
