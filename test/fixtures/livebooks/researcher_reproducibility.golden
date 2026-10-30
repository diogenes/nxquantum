# Goldens for examples/livebook/researcher_reproducibility.livemd.
#
# The fingerprint is exact. Its value was measured as identical on OTP 27, 28 and 29
# (Elixir 1.18.5, 1.19.5, 1.20.4) for this input, but OTP does not promise that
# term_to_binary(_, [:deterministic]) stays stable across majors. If a future OTP changes it,
# re-derive the value here and in the notebook prose, and say so in the CHANGELOG.
# Counts are exact. Floats use the 1.0e-6 absolute tolerance (f32 results, docs/backend-support.md).
%{
  "fingerprint_properties" => %{
    format_ok: true,
    key_order_independent: true,
    value_sensitive: true,
    list_order_sensitive: true
  },
  "fingerprint_golden" => "v1:6a65205f6292c5336526e8dcb7fed7fd3f54edfa3910729e25c5b24a0a9c4c00",
  "seeded_replay" => %{
    replay_equal: true,
    counts_seed_2026: %{"0" => 1325, "1" => 723},
    counts_seed_2027: %{"0" => 1406, "1" => 642},
    different_seed_differs: true
  },
  # cos(0.0, 0.4, 0.8, 1.2, 2.0, 3.0) to f32 precision
  "closed_form" => %{
    all_within_tolerance: true,
    values: [
      1.0,
      0.9210609940028851,
      0.6967067093471654,
      0.3623577544766736,
      -0.4161468365471424,
      -0.9899924966004454
    ]
  },
  # |(1406 - 642) / 2048 - cos(1.2)| = |0.37304688 - 0.36235775| = 0.0106891205 (exact: 0.373046875 - cos(1.2))
  "portability_delta" => %{
    expectation_delta_abs: 0.0106891205,
    latency_delta_ms: 0.0,
    sample_kl_divergence: 0.0
  }
}
