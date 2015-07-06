defmodule SlackBot.Application do
  use Application

  @env_var "SLACK_TOKEN"

  def start(_status, _type) do
    :ok = Amnesia.start
    {:ok, pid} = SlackBot.start_link(System.get_env(@env_var))
    {:ok, pid}
  end

  def stop(_app) do
    :stopped = Amnesia.stop
  end
end
