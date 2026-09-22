"""Read-only ROS 2 bridge from safety traces to Prolog explanations."""

import json
from typing import Any, Optional

import rclpy
from rclpy.node import Node
from std_msgs.msg import String

from explainable_hrc.prolog_bridge import run_prolog_reasoning, validate_trace


class PrologExplanationBridge(Node):
    """Validate the latest safety trace and publish Prolog explanations."""

    def __init__(self) -> None:
        super().__init__('prolog_explanation_bridge')
        self.declare_parameter(
            'prolog_cli_path',
            '/home/ubuntu/ExplainableHRC/reasoning/proximity_bridge_cli.pl',
        )
        self.declare_parameter('processing_rate', 2.0)
        self.declare_parameter('prolog_timeout', 2.0)
        self.prolog_cli_path = str(
            self.get_parameter('prolog_cli_path').value)
        processing_rate = float(self.get_parameter('processing_rate').value)
        self.prolog_timeout = float(
            self.get_parameter('prolog_timeout').value)
        if processing_rate <= 0.0 or self.prolog_timeout <= 0.0:
            raise ValueError('processing_rate and prolog_timeout must be positive')

        self.latest_trace: Optional[dict[str, Any]] = None
        self.latest_sequence = 0
        self.processed_sequence = 0
        self.trace_subscription = self.create_subscription(
            String, '/safety_decision', self._trace_callback, 10)
        self.explanation_publisher = self.create_publisher(
            String, '/prolog_explanation', 10)
        self.processing_timer = self.create_timer(
            1.0 / processing_rate, self._process_latest_trace)
        self.get_logger().info(
            'Read-only Prolog explanation bridge is waiting for '
            '/safety_decision')

    def _trace_callback(self, message: String) -> None:
        try:
            trace = json.loads(message.data)
            self.latest_trace = validate_trace(trace)
        except (json.JSONDecodeError, ValueError) as error:
            self.get_logger().warning(f'Ignoring invalid decision trace: {error}')
            return
        self.latest_sequence += 1

    def _process_latest_trace(self) -> None:
        if (
            self.latest_trace is None
            or self.processed_sequence == self.latest_sequence
        ):
            return
        trace = self.latest_trace
        sequence = self.latest_sequence
        try:
            result = run_prolog_reasoning(
                trace, self.prolog_cli_path, self.prolog_timeout)
        except RuntimeError as error:
            self.get_logger().error(str(error))
            return
        result['source_topic'] = '/safety_decision'
        message = String()
        message.data = json.dumps(result, separators=(',', ':'))
        self.explanation_publisher.publish(message)
        self.processed_sequence = sequence
        if not result['decision_matches']:
            self.get_logger().error(
                'DECISION_MISMATCH ROS=%s Prolog=%s'
                % (result['trace_decision'], result['prolog_decision']))


def main(args=None) -> None:
    rclpy.init(args=args)
    node: Optional[PrologExplanationBridge] = None
    try:
        node = PrologExplanationBridge()
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
