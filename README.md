# ExplainableHRC

ExplainableHRC is a research project exploring dialogue-based interactive explanations for safety-related robot decisions in human–robot collaboration.

## Initial HRI scenario

A mobile robot transports construction material in an environment where a human worker and obstacles may affect its safety decisions. Depending on the situation, the robot may stop, slow down, wait, replan, or continue. A user can ask why the robot made a particular decision.

## Planned explanation types

- Causal explanations
- Contrastive explanations
- Counterfactual explanations
- Follow-up dialogue

## Planned technology

- ROS 2
- Gazebo
- Python
- Docker

## Current status

The repository now provides a base Docker development environment with ROS 2
Jazzy, Gazebo Harmonic integration, RViz, and a browser-accessible Ubuntu
desktop. No robot simulation scenario, ROS 2 package, or explanation system has
been implemented yet.

## Docker development environment

### Requirements

- Docker Desktop with Docker Compose v2
- On Apple Silicon, Docker Desktop configured to use Linux ARM64 containers
- At least 4 GB of memory available to Docker Desktop; more may be useful for
  Gazebo and RViz

The environment pins ROS 2 to **Jazzy** on Ubuntu 24.04. Gazebo is pinned by the
Jazzy `ros_gz` package family to the compatible **Gazebo Harmonic** release.
The upstream desktop image supports both `linux/arm64` and `linux/amd64`; Compose
uses the host's native architecture by default.

### Build and start with Docker Compose

Start Docker Desktop, open a terminal, and change to the repository root:

```bash
cd ExplainableHRC
```

Build the image:

```bash
docker compose -f docker/compose.yaml build
```

Start the container in the background:

```bash
docker compose -f docker/compose.yaml up -d
```

Open <http://127.0.0.1:6080/> in a browser. The initial desktop and VNC password
is `ubuntu`. The service binds only to localhost.

Check the container status:

```bash
docker compose -f docker/compose.yaml ps
```

Follow its logs:

```bash
docker compose -f docker/compose.yaml logs -f ros2-desktop
```

Open an interactive shell inside the running container:

```bash
docker compose -f docker/compose.yaml exec ros2-desktop bash
```

After changing the Dockerfile, rebuild and recreate the container with:

```bash
docker compose -f docker/compose.yaml up -d --build
```

The host directory `ros2_ws` is mounted at `/home/ubuntu/ros2_ws`, so source and
build results persist outside the container.

Validate the command-line tools:

```bash
docker compose -f docker/compose.yaml exec ros2-desktop printenv ROS_DISTRO
docker compose -f docker/compose.yaml exec ros2-desktop bash -lc 'ros2 --help'
docker compose -f docker/compose.yaml exec ros2-desktop bash -lc 'gz sim --versions'
docker compose -f docker/compose.yaml exec ros2-desktop bash -lc 'command -v rviz2'
docker compose -f docker/compose.yaml exec ros2-desktop \
  bash -lc 'findmnt --target /home/ubuntu/ros2_ws && test -d /home/ubuntu/ros2_ws/src'
```

Gazebo and RViz can be launched from a terminal inside the browser desktop:

```bash
gz sim -v 4 empty.sdf
rviz2
```

For the smallest Gazebo smoke test, start the container, open the browser
desktop, and run the repository launcher from a host terminal:

```bash
./scripts/run_gazebo_empty_world.sh
```

This launches Gazebo's installed official `empty.sdf` example. The repository
does not provide a custom world, robot, or model.

This configuration forces Mesa software rendering for more predictable graphics
inside Docker Desktop on macOS. It avoids X11 forwarding but may be slower than
native GPU rendering.

Stop and remove the container and Compose network:

```bash
docker compose -f docker/compose.yaml down
```

This does not delete the host-mounted `ros2_ws` directory.

## Future development

Future work will create a minimal HRI scenario, add decision logging and
explanation prototypes, and support dialogue-based interaction and evaluation.
