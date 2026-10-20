# v0.9 Quantum AI Rollout Playbook

## Objective

Operate deterministic rollout decisions for hybrid quantum-AI tool paths using typed evidence and promotion gates.

## Gate outcomes

1. `promote`: thresholds satisfied and no blocking typed errors.
2. `hold`: non-blocking regressions require operator review.
3. `rollback`: blocking typed errors or policy threshold violations.

## Required inputs

1. Hybrid benchmark evidence (`fallback_rate`, `typed_error_rate`, `quality_delta`).
2. TurboQuant production KPI evidence for rerank promotion lanes (`quality_drop`, `memory_bytes_per_vector`, `compression_ratio_vs_fp32`).
3. Request correlation metadata (`request_id`, `correlation_id`).
4. Decision thresholds snapshot.

## TurboQuant threshold profile (recommended)

Use `NxQuantum.Migration.AIGates.evaluate/2` with:

1. `require_turboquant_metrics: true`
2. `max_quality_drop: 0.05`
3. `max_memory_bytes_per_vector: 96`
4. `min_compression_ratio: 4.0`

Decision codes for TurboQuant gating:

1. `:turboquant_metrics_missing`
2. `:quality_drop_exceeded`
3. `:memory_bytes_per_vector_exceeded`
4. `:compression_ratio_below_threshold`

## Operational flow

1. Build AI request envelope.
2. Execute tool handler (`quantum-kernel reranking` or `constrained optimization helper`).
3. Evaluate rollout policy with `NxQuantum.Migration.AIGates.evaluate/2`.
4. Export machine-readable report with `NxQuantum.Migration.AIReport.to_map/3`.
5. Emit observability events with decision and evidence correlation metadata.

## Failure handling

1. Schema/input mismatch => fail fast (`:ai_rollout_invalid_input`).
2. Error-rate threshold breach => `rollback`.
3. Fallback-rate or quality-threshold breach => `hold`.
4. TurboQuant KPI threshold breach => `hold` with typed KPI-specific reason code.
