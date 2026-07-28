"""Deterministic distance-based safety controller."""

import json
import math
from typing import Optional

import rclpy
from geometry_msgs.msg import Twist
from nav_msgs.msg import Odometry
from rclpy.node import Node
from std_msgs.msg import String


class SafetyDecisionNode(Node):
    """Drive forward until the goal is reached or an obstacle is too close."""

    def __init__(self) -> None:
        super().__init__('safety_decision_node')

        self.declare_parameter('obstacle_x', 8.0)
        self.declare_parameter('obstacle_y', 0.0)
        self.declare_parameter('goal_x', 11.0)
        self.declare_parameter('goal_y', 0.0)
        self.declare_parameter('safety_threshold', 1.0)
        self.declare_parameter('forward_speed', 0.3)
        self.declare_parameter('control_rate', 10.0)
        self.declare_parameter('goal_tolerance', 0.2)

        self.obstacle_x = self._double_parameter('obstacle_x')
        self.obstacle_y = self._double_parameter('obstacle_y')
        self.goal_x = self._double_parameter('goal_x')
        self.goal_y = self._double_parameter('goal_y')
        self.safety_threshold = self._positive_parameter('safety_threshold')
        self.forward_speed = self._positive_parameter('forward_speed')
        self.control_rate = self._positive_parameter('control_rate')
        self.goal_tolerance = self._positive_parameter('goal_tolerance')

        self.robot_x: Optional[float] = None
        self.robot_y: Optional[float] = None
        self.previous_decision: Optional[str] = None

        self.velocity_publisher = self.create_publisher(
            Twist, '/model/minimal_robot/cmd_vel', 10)
        self.decision_publisher = self.create_publisher(
            String, '/safety_decision', 10)
        self.odometry_subscription = self.create_subscription(
            Odometry,
            '/model/minimal_robot/odometry',
            self._odometry_callback,
            10,
        )
        self.control_timer = self.create_timer(
            1.0 / self.control_rate, self._control)

        self.get_logger().info(
            'Waiting for odometry; obstacle=(%.2f, %.2f), goal=(%.2f, %.2f), '
            'safety_threshold=%.2f m'
            % (
                self.obstacle_x,
                self.obstacle_y,
                self.goal_x,
                self.goal_y,
                self.safety_threshold,
            )
        )

    def _double_parameter(self, name: str) -> float:
        return float(self.get_parameter(name).value)

    def _positive_parameter(self, name: str) -> float:
        value = self._double_parameter(name)
        if value <= 0.0:
            raise ValueError(f'Parameter {name} must be greater than zero')
        return value

    def _odometry_callback(self, message: Odometry) -> None:
        self.robot_x = message.pose.pose.position.x
        self.robot_y = message.pose.pose.position.y

    def _control(self) -> None:
        if self.robot_x is None or self.robot_y is None:
            return

        distance_to_goal = math.hypot(
            self.goal_x - self.robot_x, self.goal_y - self.robot_y)
        distance_to_obstacle = math.hypot(
            self.obstacle_x - self.robot_x,
            self.obstacle_y - self.robot_y,
        )

        if distance_to_goal <= self.goal_tolerance:
            decision = 'GOAL_REACHED'
            command_linear_x = 0.0
        elif distance_to_obstacle <= self.safety_threshold:
            decision = 'STOP'
            command_linear_x = 0.0
        else:
            decision = 'CONTINUE'
            command_linear_x = self.forward_speed

        command = Twist()
        command.linear.x = command_linear_x
        self.velocity_publisher.publish(command)

        if decision != self.previous_decision:
            self._publish_transition(
                decision,
                command_linear_x,
                distance_to_goal,
                distance_to_obstacle,
            )
            self.previous_decision = decision

    def _publish_transition(
        self,
        decision: str,
        command_linear_x: float,
        distance_to_goal: float,
        distance_to_obstacle: float,
    ) -> None:
        record = {
            'timestamp': self.get_clock().now().nanoseconds / 1e9,
            'robot_x': self.robot_x,
            'robot_y': self.robot_y,
            'goal_x': self.goal_x,
            'goal_y': self.goal_y,
            'obstacle_x': self.obstacle_x,
            'obstacle_y': self.obstacle_y,
            'distance_to_goal': distance_to_goal,
            'distance_to_obstacle': distance_to_obstacle,
            'safety_threshold': self.safety_threshold,
            'decision': decision,
            'command_linear_x': command_linear_x,
        }
        encoded_record = json.dumps(record, separators=(',', ':'))
        message = String()
        message.data = encoded_record
        self.decision_publisher.publish(message)

        transition = (
            decision if self.previous_decision is None
            else f'{self.previous_decision} -> {decision}'
        )
        self.get_logger().info(
            f'DECISION_TRANSITION {transition} {encoded_record}')

    def stop(self) -> None:
        """Publish a best-effort stop before shutdown."""
        self.velocity_publisher.publish(Twist())


def main(args=None) -> None:
    rclpy.init(args=args)
    node: Optional[SafetyDecisionNode] = None
    try:
        node = SafetyDecisionNode()
        rclpy.spin(node)
    except (KeyboardInterrupt, rclpy.executors.ExternalShutdownException):
        pass
    finally:
        if node is not None:
            node.stop()
            node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
