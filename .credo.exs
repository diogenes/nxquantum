%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      strict: true,
      checks: [
        {Credo.Check.Readability.MaxLineLength, max_length: 130},
        {Credo.Check.Design.AliasUsage, false},
        {Credo.Check.Refactor.Nesting, false}
      ]
    }
  ]
}
