"""Move a simplified worker across a controlled Gazebo crossing zone."""

import math
from typing import Optional

import rclpy
from geometry_msgs.msg import PoseStamped
from rclpy.node import Node
from ros_gz_interfaces.msg import Entity
from ros_gz_interfaces.srv import SetEntityPose


def worker_y_position(
    elapsed: float,
    start_y: float,
    end_y: float,
    start_delay: float,
    crossing_duration: float,
    crossing_pause: float,
    end_pause: float,
) -> float:
    """Return a crossing pose with a visible pause in the robot lane."""
    if elapsed < start_delay:
        return start_y

    half_crossing = crossing_duration / 2.0
    leg_duration = crossing_duration + crossing_pause + end_pause
    phase = (elapsed - start_delay) % (2.0 * leg_duration)

    def crossing_leg(from_y: float, to_y: float, leg_phase: float) -> float:
        centre_y = (from_y + to_y) / 2.0
        if leg_phase < half_crossing:
            progress = leg_phase / half_crossing
            return from_y + progress * (centre_y - from_y)
        if leg_phase < half_crossing + crossing_pause:
            return centre_y
        if leg_phase < crossing_duration + crossing_pause:
            progress = (
                leg_phase - half_crossing - crossing_pause
            ) / half_crossing
            return centre_y + progress * (to_y - centre_y)
        return to_y

    if phase < leg_duration:
        return crossing_leg(start_y, end_y, phase)
    return crossing_leg(end_y, start_y, phase - leg_duration)


class WorkerMotionNode(Node):
    """Command and publish the worker's deterministic Gazebo pose."""

    def __init__(self) -> None:
        super().__init__('worker_motion_node')
        self.declare_parameter('entity_name', 'construction_worker')
        self.declare_parameter(
            'set_pose_service',
            '/world/construction_crossing_scenario/set_pose',
        )
        self.declare_parameter('worker_x', 7.5)
        self.declare_parameter('start_y', -3.0)
        self.declare_parameter('end_y', 3.0)
        self.declare_parameter('start_delay', 15.0)
        self.declare_parameter('crossing_duration', 10.0)
        self.declare_parameter('crossing_pause', 10.0)
        self.declare_parameter('end_pause', 60.0)
        self.declare_parameter('update_rate', 10.0)

        self.entity_name = str(self.get_parameter('entity_name').value)
        service_name = str(self.get_parameter('set_pose_service').value)
        self.worker_x = float(self.get_parameter('worker_x').value)
        self.start_y = float(self.get_parameter('start_y').value)
        self.end_y = float(self.get_parameter('end_y').value)
        self.start_delay = float(self.get_parameter('start_delay').value)
        self.crossing_duration = float(
            self.get_parameter('crossing_duration').value)
        self.crossing_pause = float(
            self.get_parameter('crossing_pause').value)
        self.end_pause = float(self.get_parameter('end_pause').value)
        update_rate = float(self.get_parameter('update_rate').value)
        if (
            self.crossing_duration <= 0.0
            or self.crossing_pause < 0.0
            or update_rate <= 0.0
        ):
            raise ValueError('crossing_duration and update_rate must be positive')

        self.pose_publisher = self.create_publisher(
            PoseStamped, '/worker/pose', 10)
        self.pose_client = self.create_client(SetEntityPose, service_name)
        self.start_time = self.get_clock().now()
        self.pending_request: Optional[rclpy.task.Future] = None
        self.wait_message_logged = False
        self.timer = self.create_timer(1.0 / update_rate, self._update)

    def _update(self) -> None:
        if not self.pose_client.service_is_ready():
            if not self.wait_message_logged:
                self.get_logger().info('Waiting for Gazebo set-pose service')
                self.wait_message_logged = True
            return
        if self.pending_request is not None and not self.pending_request.done():
            return

        elapsed = (self.get_clock().now() - self.start_time).nanoseconds / 1e9
        worker_y = worker_y_position(
            elapsed,
            self.start_y,
            self.end_y,
            self.start_delay,
            self.crossing_duration,
            self.crossing_pause,
            self.end_pause,
        )
        leg_duration = (
            self.crossing_duration + self.crossing_pause + self.end_pause)
        moving_forward = self.start_delay <= elapsed and (
            (elapsed - self.start_delay) % (2.0 * leg_duration)
            < leg_duration
        )
        yaw = math.pi / 2.0 if moving_forward else -math.pi / 2.0

        request = SetEntityPose.Request()
        request.entity.name = self.entity_name
        request.entity.type = Entity.MODEL
        request.pose.position.x = self.worker_x
        request.pose.position.y = worker_y
        request.pose.position.z = 0.0
        request.pose.orientation.z = math.sin(yaw / 2.0)
        request.pose.orientation.w = math.cos(yaw / 2.0)
        self.pending_request = self.pose_client.call_async(request)

        pose_message = PoseStamped()
        pose_message.header.stamp = self.get_clock().now().to_msg()
        pose_message.header.frame_id = 'world'
        pose_message.pose = request.pose
        self.pose_publisher.publish(pose_message)


def main(args=None) -> None:
    rclpy.init(args=args)
    node: Optional[WorkerMotionNode] = None
    try:
        node = WorkerMotionNode()
        rclpy.spin(node)
    except (KeyboardInterrupt, rclpy.executors.ExternalShutdownException):
        pass
    finally:
        if node is not None:
            node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
