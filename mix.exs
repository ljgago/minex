defmodule Minex.MixProject do
  use Mix.Project

  @version "0.1.0"
  @repo_url "https://github.com/ljgago/minex"

  def project do
    [
      app: :minex,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Doc
      name: "Minex",

      # Pakcage
      package: package(),
      description: "Elixir MinIO client"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      # extra_applications: [:logger], mod: {Minex, []}
      mod: {Minex.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:finch, "~> 0.7"},
      {:mint, "~> 1.3"},
      {:castore, "~> 0.1"},
      {:erlsom, "~> 1.5"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:benchee, "~> 1.0", only: :dev},
      {:bypass, "~> 2.0", only: :test}
      # {:observer_cli, "~> 1.5"},
      #{:tesla, "~> 1.3"},
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end
end
