:- module(explanation_engine, [
    prove/4,
    explain_why/4,
    explain_why_not/5
]).

/** <module> Pure rule-based proof and explanation predicates.

Rules use the representation rule(Id, Head, Body), where Body is a list of
goals. Facts and rules are passed explicitly so separate decisions cannot
pollute one another through dynamic global state.
*/


prove(Goal, Facts, Rules, Proof) :-
    prove_goal(Goal, Facts, Rules, [], Proof).


explain_why(Goal, Facts, Rules, why(Goal, Proof)) :-
    prove(Goal, Facts, Rules, Proof).


explain_why_not(Alternative, Selected, Facts, Rules,
                why_not(Alternative, Selected, Constraint, Proof)) :-
    prove(action_blocked(Alternative, Constraint), Facts, Rules, Proof),
    prove(selected_action(Selected), Facts, Rules, _).


prove_goal(Goal, Facts, _Rules, _Visited, proof(Goal, fact)) :-
    memberchk(Goal, Facts),
    !.
prove_goal(Goal, _Facts, _Rules, _Visited, proof(Goal, builtin)) :-
    safe_builtin(Goal),
    !.
prove_goal(Goal, Facts, Rules, Visited,
           proof(Goal, rule(RuleId), PremiseProofs)) :-
    \+ memberchk(Goal, Visited),
    member(RuleTemplate, Rules),
    copy_term(RuleTemplate, rule(RuleId, Head, Premises)),
    Goal = Head,
    prove_premises(Premises, Facts, Rules, [Goal|Visited], PremiseProofs).


prove_premises([], _Facts, _Rules, _Visited, []).
prove_premises([Goal|Goals], Facts, Rules, Visited,
               [Proof|Proofs]) :-
    prove_goal(Goal, Facts, Rules, Visited, Proof),
    prove_premises(Goals, Facts, Rules, Visited, Proofs).


safe_builtin(less_than(Left, Right)) :-
    number(Left),
    number(Right),
    Left < Right.
safe_builtin(greater_than_or_equal(Left, Right)) :-
    number(Left),
    number(Right),
    Left >= Right.
safe_builtin(less_than_or_equal(Left, Right)) :-
    number(Left),
    number(Right),
    Left =< Right.
safe_builtin(greater_than(Left, Right)) :-
    number(Left),
    number(Right),
    Left > Right.
