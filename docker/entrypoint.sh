#!/usr/bin/env bash
set -e

# Make the base ROS installation and any built workspace overlay available in
# terminals opened through the browser desktop.
cat > /etc/profile.d/explainablehrc-ros.sh <<'EOF'
source /opt/ros/jazzy/setup.bash
if [ -f /home/ubuntu/ros2_ws/install/setup.bash ]; then
    source /home/ubuntu/ros2_ws/install/setup.bash
fi
EOF
chmod 0644 /etc/profile.d/explainablehrc-ros.sh

mkdir -p /home/ubuntu/ros2_ws/src

exec /usr/local/bin/ros2-desktop-vnc-entrypoint.sh
