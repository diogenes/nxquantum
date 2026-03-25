# Decision Matrix: NxQuantum vs Python-First Tooling

Use this matrix for platform decisions.

Status note (as of March 19, 2026):

1. This matrix reflects current NxQuantum maturity and known ecosystem tradeoffs.
2. Revisit when provider bridge depth and additional case-study evidence expand.

| Situation | Prefer NxQuantum | Prefer Python-first |
| --- | --- | --- |
| Team stack | Elixir/Nx/BEAM-native services | Python-heavy research + infra |
| Determinism and typed contracts | High priority for deterministic-by-default simulator/fixture workflows plus typed contracts | Lower priority or handled elsewhere |
| Hardware-provider breadth needed today | Moderate requirements, staged adoption acceptable | Immediate broad provider support required |
| Integration model | Keep training/serving in same BEAM runtime | Existing Python orchestration is strategic |
| Migration appetite | Incremental migration with shadow runs | Continue optimizing current Python stack |

Determinism scope note:

1. In this matrix, deterministic refers to seeded simulator/fixture behavior and typed contract stability.
2. Live provider/QPU measured outcomes are probabilistic and should be evaluated with statistical acceptance criteria.

## Honest Current Limits

1. Hardware-provider depth is still maturing.
2. Some advanced dynamic/provider paths remain phased.
3. Cross-ecosystem benchmark breadth is still growing.

## Recommendation Pattern

1. Choose NxQuantum when integration simplicity and deterministic contracts in BEAM matter most.
2. Choose Python-first when immediate provider breadth is the top requirement.
3. Use hybrid rollout when you need both in the short term.
