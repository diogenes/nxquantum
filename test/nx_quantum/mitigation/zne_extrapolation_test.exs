defmodule NxQuantum.Mitigation.ZneExtrapolationTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Mitigation
  alias NxQuantum.Sampler

  @tol 1.0e-12

  defp estimate do
    {:ok, estimate} = Estimator.run(Circuit.new(qubits: 1), observables: [:pauli_z], wire: 0)
    estimate
  end

  defp polynomial(coefficients, x) do
    coefficients
    |> Enum.with_index()
    |> Enum.reduce(0.0, fn {c, k}, acc -> acc + c * :math.pow(x, k) end)
  end

  defp run_pass(pass, opts) do
    {:ok, out} = Mitigation.pipeline(estimate(), [{pass, opts}])
    List.last(out.metadata.mitigation_trace)
  end

  defp pass_error(pass, opts) do
    Mitigation.pipeline(estimate(), [{pass, opts}])
  end

  describe "zne_richardson" do
    test "recovers a known quadratic at zero exactly from three points" do
      coefficients = [2.0, 3.0, -0.5]
      scales = [1.0, 2.0, 3.0]
      values = Enum.map(scales, &polynomial(coefficients, &1))

      entry = run_pass(:zne_richardson, scales: scales, values: values)

      assert_in_delta entry.extrapolated_value, 2.0, @tol
      assert entry.std_error == nil
    end

    test "recovers a known cubic at zero exactly from four points" do
      coefficients = [-1.5, 0.25, 0.75, -0.125]
      scales = [1.0, 1.5, 2.0, 3.0]
      values = Enum.map(scales, &polynomial(coefficients, &1))

      entry = run_pass(:zne_richardson, scales: scales, values: values)

      assert_in_delta entry.extrapolated_value, -1.5, @tol
    end

    test "two points reproduce the linear extrapolation and the zne_linear scales" do
      scales = [1.0, 3.0]
      values = [0.9, 0.7]

      entry = run_pass(:zne_richardson, scales: scales, values: values)
      linear = run_pass(:zne_linear, scales: scales)

      # Line through (1, 0.9) and (3, 0.7) at x = 0: 1.5 * 0.9 - 0.5 * 0.7
      assert_in_delta entry.extrapolated_value, 1.0, @tol
      assert entry.scales == linear.scales
      assert entry.pass == :zne_richardson
    end

    test "propagates standard errors through the two-point weights in closed form" do
      # weights are 3/2 and -1/2, so sigma = sqrt(2.25 * 0.2^2 + 0.25 * 0.4^2) = sqrt(0.13)
      entry =
        run_pass(:zne_richardson,
          scales: [1.0, 3.0],
          values: [0.9, 0.7],
          std_errors: [0.2, 0.4]
        )

      assert_in_delta entry.std_error, :math.sqrt(0.13), @tol
    end

    test "propagates standard errors through the three-point weights in closed form" do
      # Lagrange weights at 0 for scales 1, 2, 3 are 3, -3, 1; with sigma 0.1 each,
      # sigma = 0.1 * sqrt(9 + 9 + 1) = 0.1 * sqrt(19)
      coefficients = [2.0, 3.0, -0.5]
      scales = [1.0, 2.0, 3.0]
      values = Enum.map(scales, &polynomial(coefficients, &1))

      entry =
        run_pass(:zne_richardson,
          scales: scales,
          values: values,
          std_errors: [0.1, 0.1, 0.1]
        )

      assert_in_delta entry.extrapolated_value, 2.0, @tol
      assert_in_delta entry.std_error, 0.1 * :math.sqrt(19), @tol
    end

    test "accepts a sampler result and records the trace" do
      {:ok, sample} = Sampler.run(Circuit.new(qubits: 1), shots: 64, seed: 3)

      assert {:ok, out} =
               Mitigation.pipeline(sample, [
                 {:zne_richardson, scales: [1.0, 2.0], values: [0.5, 0.4]}
               ])

      assert [%{pass: :zne_richardson, extrapolated_value: value}] = out.metadata.mitigation_trace
      assert_in_delta value, 0.6, @tol
    end

    test "returns a typed error for a non-result input" do
      assert {:error, %{code: :invalid_mitigation_input, reason: :unsupported_result}} =
               Mitigation.pipeline(:not_a_result, [
                 {:zne_richardson, scales: [1.0, 2.0], values: [0.5, 0.4]}
               ])
    end

    test "returns a typed error for fewer than two points" do
      assert {:error, %{code: :invalid_mitigation_input, reason: :too_few_points, minimum: 2}} =
               pass_error(:zne_richardson, scales: [1.0], values: [0.5])
    end

    test "returns a typed error for non-numeric scales" do
      assert {:error, %{code: :invalid_mitigation_input, reason: :invalid_scales}} =
               pass_error(:zne_richardson, scales: [1.0, :two], values: [0.5, 0.4])
    end

    test "returns a typed error for duplicate scale factors, including 1 and 1.0" do
      assert {:error, %{code: :invalid_mitigation_input, reason: :duplicate_scales}} =
               pass_error(:zne_richardson, scales: [1, 1.0, 2.0], values: [0.5, 0.5, 0.4])
    end

    test "returns a typed error for distinct scales closer than 1.0e-9" do
      assert {:error, %{code: :invalid_mitigation_input, reason: :duplicate_scales}} =
               pass_error(:zne_richardson, scales: [1.0, 1.0 + 1.0e-12], values: [0.5, 0.4])
    end

    test "returns a typed error when values are missing" do
      assert {:error, %{code: :invalid_mitigation_input, reason: :missing_values}} =
               pass_error(:zne_richardson, scales: [1.0, 2.0])
    end

    test "returns a typed error when values do not match the scales" do
      assert {:error, %{code: :invalid_mitigation_input, reason: :invalid_values, expected_length: 2}} =
               pass_error(:zne_richardson, scales: [1.0, 2.0], values: [0.5])

      assert {:error, %{code: :invalid_mitigation_input, reason: :invalid_values}} =
               pass_error(:zne_richardson, scales: [1.0, 2.0], values: [0.5, :bad])

      assert {:error, %{code: :invalid_mitigation_input, reason: :invalid_values}} =
               pass_error(:zne_richardson, scales: [1.0, 2.0], values: 0.5)
    end

    test "returns a typed error for invalid standard errors" do
      assert {:error, %{code: :invalid_mitigation_input, reason: :invalid_std_errors}} =
               pass_error(:zne_richardson,
                 scales: [1.0, 2.0],
                 values: [0.5, 0.4],
                 std_errors: [0.1, -0.2]
               )

      assert {:error, %{code: :invalid_mitigation_input, reason: :invalid_std_errors}} =
               pass_error(:zne_richardson,
                 scales: [1.0, 2.0],
                 values: [0.5, 0.4],
                 std_errors: [0.1]
               )
    end
  end

  describe "zne_poly_ls" do
    test "recovers a known quadratic at zero exactly from five points with degree 2" do
      coefficients = [2.0, 3.0, -0.5]
      scales = [1.0, 1.5, 2.0, 2.5, 3.0]
      values = Enum.map(scales, &polynomial(coefficients, &1))

      entry = run_pass(:zne_poly_ls, scales: scales, values: values, degree: 2)

      assert_in_delta entry.extrapolated_value, 2.0, @tol
      assert entry.degree == 2
      assert entry.pass == :zne_poly_ls
    end

    test "matches the hand-computed linear least-squares intercept on fixed noisy data" do
      # x = 1..4, y = [1.1, 1.9, 3.2, 3.9]: slope 4.85 / 5 = 0.97, intercept 2.525 - 0.97 * 2.5 = 0.1
      # weights at 0 are [1.0, 0.5, 0.0, -0.5]; with sigma 0.1 each, sigma = 0.1 * sqrt(1.5)
      scales = [1.0, 2.0, 3.0, 4.0]
      values = [1.1, 1.9, 3.2, 3.9]

      entry =
        run_pass(:zne_poly_ls,
          scales: scales,
          values: values,
          degree: 1,
          std_errors: [0.1, 0.1, 0.1, 0.1]
        )

      assert_in_delta entry.extrapolated_value, 0.1, @tol
      assert_in_delta entry.std_error, 0.1 * :math.sqrt(1.5), @tol
    end

    test "defaults to degree 1" do
      scales = [1.0, 2.0, 3.0, 4.0]
      values = [1.1, 1.9, 3.2, 3.9]

      default = run_pass(:zne_poly_ls, scales: scales, values: values)
      explicit = run_pass(:zne_poly_ls, scales: scales, values: values, degree: 1)

      assert default.degree == 1
      assert_in_delta default.extrapolated_value, explicit.extrapolated_value, @tol
    end

    test "with degree equal to points minus one, matches Richardson on noisy data" do
      scales = [1.0, 2.0, 3.0, 4.0]
      values = [1.1, 1.9, 3.2, 3.9]
      std_errors = [0.1, 0.2, 0.15, 0.05]

      richardson =
        run_pass(:zne_richardson, scales: scales, values: values, std_errors: std_errors)

      poly = run_pass(:zne_poly_ls, scales: scales, values: values, degree: 3, std_errors: std_errors)

      assert_in_delta poly.extrapolated_value, richardson.extrapolated_value, @tol
      assert_in_delta poly.std_error, richardson.std_error, @tol
    end

    test "returns a typed error when degree is not less than the number of points" do
      assert {:error, %{code: :invalid_mitigation_input, reason: :degree_too_large, degree: 3, points: 3}} =
               pass_error(:zne_poly_ls, scales: [1.0, 2.0, 3.0], values: [0.5, 0.4, 0.3], degree: 3)
    end

    test "refuses a least-squares fit whose Vandermonde matrix is ill-conditioned" do
      # Scales spanning 1 to 3000 at degree 3 put x^3 near 2.7e10 in one column, far above the threshold.
      assert {:error, %{code: :invalid_mitigation_input, reason: :ill_conditioned, degree: 3}} =
               pass_error(:zne_poly_ls,
                 scales: [1.0, 1000.0, 2000.0, 3000.0],
                 values: [0.5, 0.4, 0.3, 0.2],
                 degree: 3
               )
    end

    test "returns a typed error for a negative or non-integer degree" do
      assert {:error, %{code: :invalid_mitigation_input, reason: :invalid_degree}} =
               pass_error(:zne_poly_ls, scales: [1.0, 2.0], values: [0.5, 0.4], degree: -1)

      assert {:error, %{code: :invalid_mitigation_input, reason: :invalid_degree}} =
               pass_error(:zne_poly_ls, scales: [1.0, 2.0], values: [0.5, 0.4], degree: 1.5)
    end

    test "returns the shared typed errors for too few points and duplicate scales" do
      assert {:error, %{code: :invalid_mitigation_input, reason: :too_few_points}} =
               pass_error(:zne_poly_ls, scales: [1.0], values: [0.5], degree: 0)

      assert {:error, %{code: :invalid_mitigation_input, reason: :duplicate_scales}} =
               pass_error(:zne_poly_ls, scales: [1.0, 1.0], values: [0.5, 0.4])
    end

    test "returns a typed error for a non-result input" do
      assert {:error, %{code: :invalid_mitigation_input, reason: :unsupported_result}} =
               Mitigation.pipeline(:not_a_result, [
                 {:zne_poly_ls, scales: [1.0, 2.0], values: [0.5, 0.4]}
               ])
    end
  end

  describe "pipeline registration" do
    test "zne_richardson and zne_poly_ls chain after the existing passes in order" do
      scales = [1.0, 2.0, 3.0]
      values = [0.9, 0.8, 0.7]

      assert {:ok, out} =
               Mitigation.pipeline(estimate(), [
                 {:zne_linear, scales: scales},
                 {:zne_richardson, scales: scales, values: values},
                 {:zne_poly_ls, scales: scales, values: values, degree: 1}
               ])

      assert Enum.map(out.metadata.mitigation_trace, & &1.pass) ==
               [:zne_linear, :zne_richardson, :zne_poly_ls]
    end

    test "unknown pass names remain typed errors" do
      assert {:error, %{code: :unsupported_mitigation_pass, pass: :zne_cubic}} =
               Mitigation.pipeline(estimate(), [{:zne_cubic, scales: [1.0, 2.0]}])
    end
  end
end
