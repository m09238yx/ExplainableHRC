#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="${repo_root}/docker/compose.yaml"
world_file="${repo_root}/simulation/worlds/construction_crossing_scenario.sdf"
container_world="/tmp/construction_crossing_scenario.sdf"

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

cleanup_container_demo() {
    docker compose -f "${compose_file}" exec --no-TTY ros2-desktop \
        bash -lc '
            pid_file=/tmp/explainable_hrc_crossing.pids
            if [[ -f "${pid_file}" ]]; then
                while IFS= read -r process_group; do
                    if [[ "${process_group}" =~ ^[0-9]+$ ]]; then
                        kill -- "-${process_group}" 2>/dev/null || true
                    fi
                done < "${pid_file}"
                rm -f "${pid_file}"
            fi
        ' >/dev/null 2>&1 || true
}

# Recover from a previous host-side interruption before starting a new run.
cleanup_container_demo
trap cleanup_container_demo EXIT INT TERM

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
        source "/opt/ros/${ROS_DISTRO}/setup.bash"
        workspace_setup="/home/ubuntu/ros2_ws/install/setup.bash"
        if [[ ! -f "${workspace_setup}" ]]; then
            printf "Workspace is not built. Run colcon build first.\n" >&2
            exit 1
        fi
        source "${workspace_setup}"
        set -u

        if ! ros2 pkg prefix explainable_hrc >/dev/null 2>&1; then
            printf "explainable_hrc is not installed in the workspace.\n" >&2
            exit 1
        fi

        cleanup() {
            trap - EXIT INT TERM
            for process_group in \
                "${safety_pid:-}" "${worker_pid:-}" \
                "${bridge_pid:-}" "${gazebo_pid:-}"; do
                if [[ -n "${process_group}" ]]; then
                    kill -- "-${process_group}" 2>/dev/null || true
                fi
            done
            wait "${safety_pid:-}" "${worker_pid:-}" \
                "${bridge_pid:-}" "${gazebo_pid:-}" 2>/dev/null || true
            rm -f /tmp/explainable_hrc_crossing.pids
        }
        trap cleanup EXIT INT TERM

        setsid gz sim -r -v 3 /tmp/construction_crossing_scenario.sdf &
        gazebo_pid=$!

        for attempt in {1..30}; do
            if gz topic -l 2>/dev/null |
                grep -qx "/model/minimal_robot/odometry"; then
                break
            fi
            if ! kill -0 "${gazebo_pid}" 2>/dev/null; then
                printf "Gazebo exited before robot topics became available.\n" >&2
                exit 1
            fi
            if [[ "${attempt}" -eq 30 ]]; then
                printf "Timed out waiting for robot odometry.\n" >&2
                exit 1
            fi
            sleep 1
        done

        setsid ros2 run ros_gz_bridge parameter_bridge \
            "/model/minimal_robot/cmd_vel@geometry_msgs/msg/Twist]gz.msgs.Twist" \
            "/model/minimal_robot/odometry@nav_msgs/msg/Odometry[gz.msgs.Odometry" \
            "/world/construction_crossing_scenario/set_pose@ros_gz_interfaces/srv/SetEntityPose" &
        bridge_pid=$!

        setsid ros2 run explainable_hrc worker_motion_node &
        worker_pid=$!

        setsid ros2 run explainable_hrc safety_decision_node \
            --ros-args \
            -p obstacle_pose_topic:=/worker/pose \
            -p obstacle_type:=human_worker \
            -p obstacle_x:=7.5 \
            -p obstacle_y:=-3.0 \
            -p goal_x:=11.0 \
            -p goal_y:=0.0 \
            -p caution_distance:=3.0 \
            -p stop_distance:=1.5 \
            -p resume_distance:=1.8 \
            -p clearance_wait:=1.0 \
            -p forward_speed:=0.3 \
            -p minimum_speed:=0.1 \
            -p acceleration_rate:=0.15 \
            -p deceleration_rate:=0.3 \
            -p control_rate:=10.0 \
            -p goal_tolerance:=0.2 &
        safety_pid=$!

        printf "%s\n" \
            "${safety_pid}" "${worker_pid}" \
            "${bridge_pid}" "${gazebo_pid}" \
            > /tmp/explainable_hrc_crossing.pids

        printf "\nConstruction crossing scenario S02 is running.\n"
        printf "Open the desktop at http://127.0.0.1:6080/\n"
        printf "The worker begins crossing after 15 seconds and pauses\n"
        printf "in the robot lane for 10 seconds. The yellow circle shows\n"
        printf "the 3.0 m caution zone; red shows the 1.5 m stop zone.\n"
        printf "The six safety states are:\n"
        printf "GO, SLOW, STOP, WAIT, RESUME, and GOAL_REACHED.\n"
        printf "The robot slows within 3.0 m, stops at 1.5 m, waits\n"
        printf "one second after clearing 1.8 m, then resumes smoothly.\n\n"
        printf "Worker pose:    /worker/pose\n"
        printf "Robot odometry: /model/minimal_robot/odometry\n"
        printf "Decisions:      /safety_decision\n\n"
        printf "Inspect decisions:\n"
        printf "  ros2 topic echo /safety_decision std_msgs/msg/String\n\n"
        printf "Press Ctrl-C here to stop all scenario processes.\n\n"

        wait "${gazebo_pid}"
    '
