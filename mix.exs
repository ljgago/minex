defmodule Minex.MixProject do
  use Mix.Project

  @version "0.1.0"
  @repo_url "https://github.com/ljgago/minex"

  def project do
    [
      app: :minex,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Doc
      name: "Minex",

      # Pakcage
      package: package(),
      description: "Unofficial Elixir MinIO/S3 client"
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
      {:finch, "~> 0.12"},
      {:mint, "~> 1.4"},
      {:castore, "~> 0.1"},
      {:erlsom, "~> 1.5"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:benchee, "~> 1.1", only: :dev},
      {:bypass, "~> 2.1", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end
end
