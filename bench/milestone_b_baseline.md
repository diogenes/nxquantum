# Milestone B Baseline Report

Date: 2026-03-19

Environment:

- Runtime profile for baseline run: `cpu_portable`
- EXLA enabled: `false`
- Torchx enabled: `false`
- Command:
  - `NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=0 mise exec -- mix run bench/milestone_b.exs`

## Benchmark Scenarios

1. `expectation_1q`
2. `expectation_2q`
3. `shots_seeded_2048`
4. `noise_depolarizing`
5. `noise_amplitude_damping`
6. `optimize_pipeline`

## Initial Baseline

From benchmark run on 2026-03-19:

1. `optimize_pipeline`
- ips: `5485.22 K`
- average: `0.182 μs`
- deviation: `±2312.78%`

2. `noise_depolarizing`
- ips: `59.92 K`
- average: `16.69 μs`
- deviation: `±16.32%`

3. `noise_amplitude_damping`
- ips: `59.54 K`
- average: `16.80 μs`
- deviation: `±31.97%`

4. `expectation_1q`
- ips: `59.50 K`
- average: `16.81 μs`
- deviation: `±24.04%`

5. `expectation_2q`
- ips: `16.49 K`
- average: `60.66 μs`
- deviation: `±9.18%`

6. `shots_seeded_2048`
- ips: `14.17 K`
- average: `70.57 μs`
- deviation: `±17.05%`
