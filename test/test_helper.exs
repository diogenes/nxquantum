ExUnit.start()

(Path.wildcard("test/support/**/*.ex") ++
   Path.wildcard("test/features/**/*.ex"))
|> Enum.sort_by(fn path ->
  cond do
    String.contains?(path, "/features/steps/") -> {1, path}
    String.ends_with?(path, "/features/step_registry.ex") -> {2, path}
    String.ends_with?(path, "/features/steps.ex") -> {3, path}
    String.ends_with?(path, "/features/runner.ex") -> {4, path}
    true -> {0, path}
  end
end)
|> Enum.each(&Code.require_file/1)
