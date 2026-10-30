# Goldens for examples/livebook/supervised_service.livemd.
# cos(1.2) = 0.3623577544766736 (f32: 0.36235774). Counts and ids are exact.
# Two provider lifecycle runs (one per set of three calls), each recording
# 4 span starts, 4 span stops, 6 metrics and 3 logs.
%{
  "results_before_kill" => %{
    expectation: 0.36235774,
    counts: %{"0" => 1325, "1" => 723},
    lifecycle: %{job_id: "ibm_job_ff6ecf9c987e", state: :completed}
  },
  "restart_identical" => %{new_process: true, identical: true},
  "signal_counts" => %{
    sources: [:nxquantum, :user],
    nxquantum: %{span_start: 8, span_stop: 8, metric: 12, log: 6},
    user: %{start: 6, stop: 6},
    user_calls: [:expectation, :sample, :lifecycle, :expectation, :sample, :lifecycle]
  }
}
