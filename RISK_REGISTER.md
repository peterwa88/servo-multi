# RISK REGISTER

## R-001 Upstream churn
Servo evolves quickly. Mitigation: pin exact upstream commit and sync intentionally.

## R-002 Boundary erosion
Developers may start editing `servo_origin/` casually. Mitigation: enforce separation and patch queue discipline.

## R-003 Build complexity
Servo has nontrivial dependencies and build setup. Mitigation: document exact bootstrap and platform assumptions early.

## R-004 Over-automation
Claude Code may attempt oversized refactors. Mitigation: require smallest-step implementation and milestone gating.
