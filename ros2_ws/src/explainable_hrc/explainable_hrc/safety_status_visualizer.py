"""Gazebo status beacon and concise safety explanation publisher."""

import json
from collections import deque
from typing import Optional

import rclpy
from geometry_msgs.msg import Pose
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, QoSProfile, ReliabilityPolicy
from ros_gz_interfaces.msg import Entity
from ros_gz_interfaces.srv import SetEntityPose
from std_msgs.msg import String

from explainable_hrc.prolog_bridge import VALID_STATES
from explainable_hrc.status_visualizer_logic import explanation_text


class SafetyStatusVisualizer(Node):
    """Move a coloured beacon with the robot and publish concise text."""

    def __init__(self) -> None:
        super().__init__('safety_status_visualizer')
        self.declare_parameter(
            'set_pose_service',
            '/world/construction_crossing_scenario/set_pose',
        )
        self.declare_parameter('beacon_height', 0.65)
        service_name = str(self.get_parameter('set_pose_service').value)
        self.beacon_height = float(self.get_parameter('beacon_height').value)
        self.pose_client = self.create_client(SetEntityPose, service_name)
        self.pose_requests: deque[tuple[str, Pose]] = deque()
        self.pending_request = None
        self.current_state: Optional[str] = None
        self.latest_active_pose: Optional[Pose] = None

        text_qos = QoSProfile(
            depth=1,
            durability=DurabilityPolicy.TRANSIENT_LOCAL,
            reliability=ReliabilityPolicy.RELIABLE,
        )
        self.text_publisher = self.create_publisher(
            String, '/safety_explanation_text', text_qos)
        self.trace_subscription = self.create_subscription(
            String, '/safety_decision', self._trace_callback, 10)
        self.request_timer = self.create_timer(0.05, self._send_next_pose)

    def _trace_callback(self, message: String) -> None:
        try:
            trace = json.loads(message.data)
            state = trace['decision']
            robot_x = float(trace['robot_x'])
            robot_y = float(trace['robot_y'])
            if state not in VALID_STATES:
                raise ValueError(f'unsupported state {state!r}')
        except (json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
            self.get_logger().warning(f'Ignoring invalid visual trace: {error}')
            return

        active_pose = self._pose(robot_x, robot_y, self.beacon_height)
        self.latest_active_pose = active_pose
        if state != self.current_state:
            if self.current_state is not None:
                self.pose_requests.append(
                    (self._entity_name(self.current_state),
                     self._pose(0.0, 0.0, -2.0)))
            self.current_state = state
            self.pose_requests.append((self._entity_name(state), active_pose))
            text = String()
            text.data = explanation_text(trace)
            self.text_publisher.publish(text)
            self.get_logger().info(text.data)

    def _send_next_pose(self) -> None:
        if not self.pose_client.service_is_ready():
            return
        if self.pending_request is not None and not self.pending_request.done():
            return
        if self.pose_requests:
            entity_name, pose = self.pose_requests.popleft()
        elif self.current_state is not None and self.latest_active_pose is not None:
            entity_name = self._entity_name(self.current_state)
            pose = self.latest_active_pose
            self.latest_active_pose = None
        else:
            return
        request = SetEntityPose.Request()
        request.entity.name = entity_name
        request.entity.type = Entity.MODEL
        request.pose = pose
        self.pending_request = self.pose_client.call_async(request)

    @staticmethod
    def _entity_name(state: str) -> str:
        return f'safety_beacon_{state}'

    @staticmethod
    def _pose(x: float, y: float, z: float) -> Pose:
        pose = Pose()
        pose.position.x = x
        pose.position.y = y
        pose.position.z = z
        pose.orientation.w = 1.0
        return pose


def main(args=None) -> None:
    rclpy.init(args=args)
    node: Optional[SafetyStatusVisualizer] = None
    try:
        node = SafetyStatusVisualizer()
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
