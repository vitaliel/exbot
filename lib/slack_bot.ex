defmodule SlackBot do
  use Slacker
  require Amnesia
  require Logger
  require Database.User
  require Exquisite
  alias Database.User

  @doc """
  Message format:
  %{"channel" => "C0777G1UG", "team" => "T024FA4FV", "text" => "epa",
    "ts" => "1436138280.000014", "user" => "U03V6PA8W"}
  """
  def handle_cast({:handle_incoming, "message", msg}, state) do
    Logger.debug "msg: #{inspect msg}"

    check_user(state.api_token, msg["user"])

    {:noreply, state}
  end

  @doc """
  Message format:
  %{"presence" => "away", "user" => "U051Q84S9"}
  %{"presence" => "active", "user" => "U051Q84S9"}
  """
  def handle_cast({:handle_incoming, "presence_change", msg}, state) do
    Logger.debug "presence: #{inspect msg}"
    u = check_user(state.api_token, msg["user"])
    IO.puts inspect(Amnesia.transaction(fn -> %{u | presence: msg["presence"] } |> User.write end))

    {:noreply, state}
  end

  # %{"channel" => "C0777G1UG", "user" => "U03V6PA8W"}
  def handle_cast({:handle_incoming, "user_typing", _msg}, state) do
    {:noreply, state}
  end

  # Create user in our db if it not exists
  defp check_user(token, s_id) do
    result = Amnesia.transaction(fn -> User.where(slack_id == s_id) |> Amnesia.Selection.values end)

    case result do
      [user] -> user
      [] ->
        Logger.debug "Creating new user"
        {:ok, %{ok: true, user: user}} = Web.users_info(token, user: s_id)
        db_user = Amnesia.transaction(fn ->
          %User{name: user["real_name"],
                email: user["profile"]["email"], slack_id: s_id,
                presence: "active"} |> User.write end)
        Logger.debug "User created: #{inspect db_user}"
        db_user
    end
  end
end
