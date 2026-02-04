defmodule Maint.MixProject do
  use Mix.Project

  def project do
    [
      app: :maint,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:igniter, "~> 0.7"},
      {:usage_rules, "~> 0.1"},
      {:jido, "~> 1.1.0-rc.2"},
      {:jido_ai, "~> 0.5"},
      {:req_llm, "~> 1.5"}
    ]
  end
end
