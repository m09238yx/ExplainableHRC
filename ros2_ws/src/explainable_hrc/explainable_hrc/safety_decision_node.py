"""Six-state distance-based safety controller with explainable traces."""

import json
import math
from typing import Optional

import rclpy
from geometry_msgs.msg import PoseStamped, Twist
from nav_msgs.msg import Odometry
from rclpy.node import Node
from std_msgs.msg import String

from explainable_hrc.safety_logic import (
    GOAL_REACHED,
    RESUME,
    STOP,
    WAIT,
    active_constraints,
    ramp_speed,
    select_safety_state,
    target_speed_for_state,
)


class SafetyDecisionNode(Node):
    """Apply proximity safety states while driving toward a fixed goal."""

    def __init__(self) -> None:
        super().__init__('safety_decision_node')

        self.declare_parameter('obstacle_x', 8.0)
        self.declare_parameter('obstacle_y', 0.0)
        self.declare_parameter('obstacle_pose_topic', '')
        self.declare_parameter('obstacle_type', 'static_box')
        self.declare_parameter('goal_x', 11.0)
        self.declare_parameter('goal_y', 0.0)
        self.declare_parameter('caution_distance', 3.0)
        self.declare_parameter('stop_distance', 1.5)
        self.declare_parameter('resume_distance', 1.8)
        self.declare_parameter('clearance_wait', 1.0)
        self.declare_parameter('forward_speed', 0.3)
        self.declare_parameter('minimum_speed', 0.1)
        self.declare_parameter('acceleration_rate', 0.15)
        self.declare_parameter('deceleration_rate', 0.3)
        self.declare_parameter('control_rate', 10.0)
        self.declare_parameter('goal_tolerance', 0.2)

        self.obstacle_x = self._double_parameter('obstacle_x')
        self.obstacle_y = self._double_parameter('obstacle_y')
        self.obstacle_pose_topic = str(
            self.get_parameter('obstacle_pose_topic').value)
        self.obstacle_type = str(self.get_parameter('obstacle_type').value)
        self.goal_x = self._double_parameter('goal_x')
        self.goal_y = self._double_parameter('goal_y')
        self.caution_distance = self._positive_parameter('caution_distance')
        self.stop_distance = self._positive_parameter('stop_distance')
        self.resume_distance = self._positive_parameter('resume_distance')
        self.clearance_wait = self._positive_parameter('clearance_wait')
        self.forward_speed = self._positive_parameter('forward_speed')
        self.minimum_speed = self._positive_parameter('minimum_speed')
        self.acceleration_rate = self._positive_parameter(
            'acceleration_rate')
        self.deceleration_rate = self._positive_parameter(
            'deceleration_rate')
        self.control_rate = self._positive_parameter('control_rate')
        self.goal_tolerance = self._positive_parameter('goal_tolerance')
        self._validate_ranges()

        self.robot_x: Optional[float] = None
        self.robot_y: Optional[float] = None
        self.previous_decision: Optional[str] = None
        self.current_speed = 0.0
        self.clearance_started_at: Optional[float] = None

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
        self.obstacle_pose_subscription = None
        if self.obstacle_pose_topic:
            self.obstacle_pose_subscription = self.create_subscription(
                PoseStamped,
                self.obstacle_pose_topic,
                self._obstacle_pose_callback,
                10,
            )
        self.control_timer = self.create_timer(
            1.0 / self.control_rate, self._control)

        self.get_logger().info(
            'Waiting for odometry; caution=%.2f m, stop=%.2f m, '
            'resume=%.2f m, clearance_wait=%.2f s'
            % (
                self.caution_distance,
                self.stop_distance,
                self.resume_distance,
                self.clearance_wait,
            )
        )

    def _double_parameter(self, name: str) -> float:
        return float(self.get_parameter(name).value)

    def _positive_parameter(self, name: str) -> float:
        value = self._double_parameter(name)
        if value <= 0.0:
            raise ValueError(f'Parameter {name} must be greater than zero')
        return value

    def _validate_ranges(self) -> None:
        if not (
            self.stop_distance
            < self.resume_distance
            < self.caution_distance
        ):
            raise ValueError(
                'Expected stop_distance < resume_distance '
                '< caution_distance')
        if self.minimum_speed > self.forward_speed:
            raise ValueError(
                'minimum_speed must not exceed forward_speed')

    def _odometry_callback(self, message: Odometry) -> None:
        self.robot_x = message.pose.pose.position.x
        self.robot_y = message.pose.pose.position.y

    def _obstacle_pose_callback(self, message: PoseStamped) -> None:
        self.obstacle_x = message.pose.position.x
        self.obstacle_y = message.pose.position.y

    def _control(self) -> None:
        if self.robot_x is None or self.robot_y is None:
            return

        now = self.get_clock().now().nanoseconds / 1e9
        distance_to_goal = math.hypot(
            self.goal_x - self.robot_x, self.goal_y - self.robot_y)
        worker_distance = math.hypot(
            self.obstacle_x - self.robot_x,
            self.obstacle_y - self.robot_y,
        )
        reached_goal = distance_to_goal <= self.goal_tolerance
        clearance_duration = self._clearance_duration(now)
        resume_target = target_speed_for_state(
            RESUME,
            worker_distance,
            self.stop_distance,
            self.caution_distance,
            self.minimum_speed,
            self.forward_speed,
        )
        resume_complete = (
            self.previous_decision != RESUME
            or self.current_speed >= resume_target - 1e-6
        )
        previous_state = self.previous_decision

        decision = select_safety_state(
            worker_distance,
            reached_goal,
            previous_state,
            clearance_duration,
            self.clearance_wait,
            resume_complete,
            self.caution_distance,
            self.stop_distance,
            self.resume_distance,
        )
        self._update_clearance_timer(decision, previous_state, now)
        clearance_duration = self._clearance_duration(now)

        target_speed = target_speed_for_state(
            decision,
            worker_distance,
            self.stop_distance,
            self.caution_distance,
            self.minimum_speed,
            self.forward_speed,
        )
        if decision in (STOP, WAIT, GOAL_REACHED):
            self.current_speed = 0.0
        else:
            self.current_speed = ramp_speed(
                self.current_speed,
                target_speed,
                self.acceleration_rate,
                self.deceleration_rate,
                1.0 / self.control_rate,
            )
        resume_complete_after_command = (
            decision != RESUME
            or self.current_speed >= target_speed - 1e-6
        )

        command = Twist()
        command.linear.x = self.current_speed
        self.velocity_publisher.publish(command)

        constraints = active_constraints(
            decision, worker_distance, self.stop_distance)
        transition = decision != previous_state
        self._publish_trace(
            now,
            decision,
            previous_state,
            constraints,
            self.current_speed,
            distance_to_goal,
            worker_distance,
            clearance_duration,
            resume_complete_after_command,
            reached_goal,
            transition,
        )
        self.previous_decision = decision

    def _clearance_duration(self, now: float) -> float:
        if self.clearance_started_at is None:
            return 0.0
        return max(0.0, now - self.clearance_started_at)

    def _update_clearance_timer(
        self,
        decision: str,
        previous_state: Optional[str],
        now: float,
    ) -> None:
        if decision == WAIT and previous_state == STOP:
            self.clearance_started_at = now
        elif decision == STOP:
            self.clearance_started_at = None
        elif decision not in (WAIT, RESUME):
            self.clearance_started_at = None

    def _publish_trace(
        self,
        timestamp: float,
        decision: str,
        previous_state: Optional[str],
        constraints: list[str],
        command_linear_x: float,
        distance_to_goal: float,
        worker_distance: float,
        clearance_duration: float,
        resume_complete: bool,
        goal_reached: bool,
        transition: bool,
    ) -> None:
        record = {
            'timestamp': timestamp,
            'robot_x': self.robot_x,
            'robot_y': self.robot_y,
            'goal_x': self.goal_x,
            'goal_y': self.goal_y,
            'obstacle_x': self.obstacle_x,
            'obstacle_y': self.obstacle_y,
            'obstacle_type': self.obstacle_type,
            'distance_to_goal': distance_to_goal,
            'worker_distance': worker_distance,
            'caution_distance': self.caution_distance,
            'stop_distance': self.stop_distance,
            'resume_distance': self.resume_distance,
            'previous_state': previous_state or 'none',
            'clearance_duration': clearance_duration,
            'required_clearance_duration': self.clearance_wait,
            'resume_complete': resume_complete,
            'goal_reached': goal_reached,
            'nominal_action': 'go',
            'decision': decision,
            'active_constraints': constraints,
            'command_linear_x': command_linear_x,
        }
        encoded_record = json.dumps(record, separators=(',', ':'))
        message = String()
        message.data = encoded_record
        self.decision_publisher.publish(message)

        if transition:
            transition_name = (
                decision if previous_state is None
                else f'{previous_state} -> {decision}'
            )
            self.get_logger().info(
                f'DECISION_TRANSITION {transition_name} {encoded_record}')

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
