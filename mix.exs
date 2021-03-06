defmodule SlackBot.Mixfile do
  use Mix.Project

  def project do
    [app: :slack_bot,
     version: "0.0.1",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :slacker],
     mod: {SlackBot.Application, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:websocket_client, github: "jeremyong/websocket_client"},
     {:slacker,  "~> 0.0.1"},
     {:assembla_api,  "~> 0.1.0", path: "../assembla_api"},
     {:amnesia, github: "meh/amnesia"}
    ]
  end
end
