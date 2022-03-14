defmodule UeberauthStrava.Mixfile do
  use Mix.Project

  @version "0.4.0"
  @url "https://github.com/andrewhao/ueberauth_strava"

  def project do
    [
      app: :ueberauth_strava,
      version: @version,
      name: "Ueberauth Strava Strategy",
      package: package(),
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      source_url: @url,
      homepage_url: @url,
      description: description(),
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [applications: [:logger, :oauth2, :ueberauth]]
  end

  defp deps do
    [
      {:ueberauth, "~> 0.6"},
      {:oauth2, "~> 1.0 or ~> 2.0"},
      {:credo, "~> 1.6", only: [:dev, :test]},
      {:ex_doc, ">= 0.24.2", only: :dev, runtime: false},
      {:earmark, ">= 0.0.0", only: :dev},
      {:dogma, ">= 0.0.0", only: [:dev, :test]},
      {:mock, "~> 0.3.7", only: :test}
    ]
  end

  defp docs do
    [extras: docs_extras(), main: "extra-readme"]
  end

  defp docs_extras do
    ["README.md"]
  end

  defp description do
    "An Uberauth strategy for Strava authentication."
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Andrew Hao"],
      licenses: ["MIT"],
      links: %{GitHub: @url}
    ]
  end
end
