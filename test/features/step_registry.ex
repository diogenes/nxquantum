defmodule NxQuantum.Features.StepRegistry do
  @moduledoc false

  @step_modules [
    NxQuantum.Features.Steps.VariationalCircuitSteps,
    NxQuantum.Features.Steps.BackendCompilationSteps,
    NxQuantum.Features.Steps.CircuitOptimizationSteps,
    NxQuantum.Features.Steps.DifferentiationModesSteps,
    NxQuantum.Features.Steps.HybridTrainingSteps,
    NxQuantum.Features.Steps.NoiseAndShotsSteps,
    NxQuantum.Features.Steps.QuantumKernelMethodsSteps,
    NxQuantum.Features.Steps.PrimitivesApiSteps,
    NxQuantum.Features.Steps.BatchedPqcSteps,
    NxQuantum.Features.Steps.ErrorMitigationSteps,
    NxQuantum.Features.Steps.TopologyTranspilationSteps,
    NxQuantum.Features.Steps.DynamicCircuitIrFoundationSteps
  ]

  @feature_to_module Map.new(@step_modules, &{&1.feature(), &1})

  def module_for_feature(feature) do
    case Map.fetch(@feature_to_module, feature) do
      {:ok, module} -> module
      :error -> raise ArgumentError, "no feature step module registered for #{inspect(feature)}"
    end
  end
end
