# ConstructionRBS

`ConstructionRBS` is an existing SWI-Prolog rule system for backward-chaining
reasoning and interactive Why / Why-not explanations over construction
scenarios. Its copied source is kept unchanged in `reasoning/ConstructionRBS/`.

The new files `explanation_engine.pl`, `s02_proximity_reasoning.pl`, and
`s02_occlusion_reasoning.pl` provide structured APIs for the new S02 work. The
proximity module covers the first Gazebo explanation demo; the visibility
prototype remains available for later occlusion work. Neither replaces or
modifies the legacy implementation.

## Requirements

SWI-Prolog is required. Validation used SWI-Prolog 10.0.2 on the development
host. SWI-Prolog is not installed in the ROS 2 Docker container.

Run the following commands from the `ExplainableHRC` repository root.

## S02 proximity reasoning

Load the distance-based module:

```bash
swipl -q -s reasoning/s02_proximity_reasoning.pl
```

The explicit state contains the observed worker distance, three safety timing
and distance thresholds, previous state, resume progress, and goal status:

```prolog
State = proximity_state{
    worker_distance:1.42,
    caution_distance:3.0,
    stop_distance:1.5,
    resume_distance:1.8,
    previous_state:slow,
    clearance_duration:0.0,
    required_clearance_duration:1.0,
    resume_complete:true,
    goal_reached:false
},
proximity_decision(State, Decision, ActiveConstraints).
```

This state returns:

```prolog
Decision = stop,
ActiveConstraints = [minimum_separation].
```

Request structured explanations with the same state:

```prolog
proximity_explain_why(State, stop, Explanation).
proximity_explain_why_not(State, continue, Explanation).
```

### Run the proximity dialogue

Start the menu-based dialogue with the default state:

```bash
swipl -q -s reasoning/s02_proximity_reasoning.pl -g proximity_chat -t halt
```

The dialogue can report the current decision, answer Why and Why-not, list the
facts, identify the applied rule, and print the complete proof tree. Options
`1` to `6` ask questions and option `7` exits. A specific state can instead be
passed to `proximity_chat/1`; the same immutable state is used for every turn
in that session.

The decision priority is:

```text
GOAL_REACHED > STOP > WAIT > RESUME > SLOW > GO
```

The module uses a `1.5 m` stop threshold, `1.8 m` hysteresis threshold, `3.0 m`
caution threshold, and a one-second clearance wait by default. These values are
state fields rather than hidden constants, so a future ROS 2 decision trace can
supply them explicitly.

## S02 visibility prototype

### Run the S02 dialogue

From the repository root:

```bash
swipl -q -s reasoning/s02_occlusion_reasoning.pl -g s02_chat -t halt
```

The default paper example starts in `pause` with visibility `0.52` below the
certified minimum `0.60`. Enter a menu number and press Return; a trailing
Prolog period is optional:

```text
1
```

The dialogue supports:

1. Why the current decision was selected.
2. Why `continue` was not selected.
3. A follow-up clarification of what caused the low visibility.
4. The current safety state and active constraints.
5. Exit.

The menu delegates to `s02_dialogue_reply/4`; it does not contain a second,
separate copy of the reasoning logic.

### Query the API directly

Load the S02 module:

```bash
swipl -q -s reasoning/s02_occlusion_reasoning.pl
```

Create the deterministic occlusion state used in the paper example:

```prolog
State = s02_state{
    visibility_confidence:0.52,
    minimum_visibility:0.60,
    observed_entity:worker,
    occluding_object:forklift,
    zone:zone_c,
    nominal_action:continue
}.
```

Evaluate the safety decision:

```prolog
s02_decision(State, Decision, ActiveConstraints).
```

The result is:

```prolog
Decision = pause,
ActiveConstraints = [visibility_below_minimum].
```

Request structured Why and Why-not explanations:

```prolog
s02_explain_why(State, pause, Explanation).
s02_explain_why_not(State, continue, Explanation).
```

Both explanations contain the observed confidence, certified minimum,
occluding object, Zone C context, binding constraint, and backward proof tree.
They fail when the requested explanation is inconsistent with the evaluated
state; for example, a safe visibility value cannot produce a Why-PAUSE answer.

Run all automated tests with:

```bash
cd reasoning/tests
swipl -q -s run_tests.pl
```

The 39 tests cover all six proximity states, threshold boundaries, structured
Why and behavior-level Why-not, the visibility prototype and dialogue, safe
negative cases, and the legacy ConstructionRBS deduction baseline.

## Load the system and a scenario

`legal_move_v1.pl` provides the interactive `chat/0` entry point. Load it with
one scenario, for example `construction1.pl`:

```bash
swipl -q \
  -s reasoning/ConstructionRBS/legal_move_v1.pl \
  -s reasoning/ConstructionRBS/construction1.pl
```

At the Prolog prompt, start the interaction with:

```prolog
chat.
```

The other copied construction scenarios are `construction2.pl` and
`construction_joint.pl`.

## Normal reasoning query

```prolog
deduce_backwards(can_lift_beam, Node).
```

This succeeds with `construction1.pl` and returns the deduction tree rooted at
rule 4.

The other scenario conclusions can be tested with:

```prolog
deduce_backwards(safe_to_execute_lift, Node). % construction2.pl
deduce_backwards(can_lift_beam, Node).        % construction_joint.pl
```

## Why question

Run `chat.`, answer `2.` when asked whether you agree with the true conclusion,
and the system explains why `can_lift_beam` was inferred. It reports rule 4 and
the supporting facts `can_start_erection`, `can_move_robot`, `beam_secured`,
and `not(worker_in_swing_zone)`. Selecting the follow-up question for
`can_start_erection` continues the dialogue and explains it using rule 2 and
the facts `can_build_foundation` and `crew_ready`.

The underlying predicate is:

```prolog
why(can_lift_beam).
```

It expects the dialogue output stream and deduction state initialized by the
interactive workflow.

## Why-not question

The underlying interactive predicate is:

```prolog
whynot(Fact).
```

The copied positive construction scenarios do not naturally produce a false
top-level conclusion. The Why-not path was therefore verified without changing
the source files by removing the system's `crew_ready` node in memory and
retaining the user's existing `crew_ready` fact:

```prolog
retractall(node(_, crew_ready, _, _)),
whynot(crew_ready).
```

Selecting reason `1.` correctly reports that the user has `crew_ready` as an
initial fact while the computer neither believes nor infers it.

## Verified examples

- All three construction scenario files load successfully.
- The top-level backward deductions succeed for all three scenarios:
  `can_lift_beam` for `construction1.pl` and `construction_joint.pl`, and
  `safe_to_execute_lift` for `construction2.pl`.
- `chat/0` starts successfully with `construction1.pl`.
- The interactive Why explanation for `can_lift_beam` succeeds, including a
  follow-up Why question for `can_start_erection`.
- The interactive Why-not disagreement for `crew_ready` succeeds with the
  documented in-memory test setup.

All local loading directives resolve correctly from their source directory; no
path changes were required.

## Current limitations

The system uses dynamic global predicates, interactive terminal input, and
timestamped text reports in the current working directory. Scenarios should be
tested in fresh SWI-Prolog processes to avoid mixing dynamic facts and rules.
The copied examples do not include a naturally false top-level construction
conclusion for a direct Why-not demonstration.

This component is not connected to ROS 2 or Gazebo. Counterfactual explanations
are not implemented. The proximity API now covers `go`, `slow`, `stop`, `wait`,
`resume`, and `goal_reached`, but does not yet calculate velocity commands or
consume live robot state. Manual-follow recovery and an evolving dialogue
memory remain future work. The visibility menu preserves one decision state
across multiple questions but does not yet update that state from user actions.
