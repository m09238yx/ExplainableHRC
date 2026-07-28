# ROS 2 Jazzy targets Ubuntu 24.04 and is supported until May 2029.
# This upstream image provides an Ubuntu MATE desktop, TigerVNC, and noVNC
# for both linux/amd64 and linux/arm64.
FROM ghcr.io/tiryoh/ros2-desktop-vnc:jazzy

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy

USER root

# Keep the upstream desktop startup available behind this project's wrapper.
RUN cp /entrypoint.sh /usr/local/bin/ros2-desktop-vnc-entrypoint.sh

# Gazebo Harmonic is the recommended Gazebo release paired with ROS 2 Jazzy.
# ros_gz supplies the Gazebo/ROS integration and Gazebo Sim command-line tools.
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool \
        ros-dev-tools \
        ros-jazzy-ros-gz \
        ros-jazzy-rviz2 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/ubuntu/ros2_ws/src \
    && chown -R ubuntu:ubuntu /home/ubuntu/ros2_ws

COPY docker/entrypoint.sh /usr/local/bin/explainablehrc-entrypoint.sh
RUN chmod 0755 /usr/local/bin/explainablehrc-entrypoint.sh

WORKDIR /home/ubuntu/ros2_ws

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/explainablehrc-entrypoint.sh"]
