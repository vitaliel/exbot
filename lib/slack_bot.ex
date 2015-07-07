defmodule SlackBot do
  use Slacker
  require Amnesia
  require Logger
  require Database.User
  require Exquisite
  alias Database.User

  @bot "exbot"
  @rules [
    {~r{#{@bot}\s+(set|unset)\s+ops\s+(\w+)}, :do_set_ops},
    {~r{#{@bot}\s+list\s+ops}, :list_ops},
    {~r{https://[\w-]+.assembla.com/spaces/([\w_-]+)/tickets/(\d+)}, :show_ticket},
    {~r{https://[\w-]+.assembla.com/code/([\w_-]+)/([\w_-]+)/merge_requests/(\d+)}, :show_mr},
    {~r{#{@bot}\s+help}, :help},
  ]

  @doc """
  Returns Slack token
  """
  def token(server) do
    GenServer.call(server, :token)
  end

  @doc """
  token call
  """
  def handle_call(:token, _from, state) do
    {:reply, state.api_token, state}
  end

  @doc """
  Message edited by user
  %{"channel" => "C0777G1UG", "event_ts" => "1436150974.263528", "hidden" => true,
      "message" => %{"edited" => %{"ts" => "1436150974.000000", "user" => "U03V6PA8W"},
        "text" => "exbot unset ops vitalie &gt;&gt;&gt;", "ts" => "1436150964.000027",
        "type" => "message", "user" => "U03V6PA8W"},
      "subtype" => "message_changed", "ts" => "1436150974.000029"}
  """
  def handle_cast({:handle_incoming, "message", %{"subtype" => "message_changed"} = _msg}, state) do
    {:noreply, state}
  end

  @doc """
  %{"attachments" => [%{"color" => "f9b564", "fallback" => "An error occurred in Breakout (production): Repository::Abstract::InvalidRevision:
  Repository::Abstract::InvalidRevision - <https://assembla.airbrake.io/projects/8344/groups/1458500049998284918>",
  "id" => 1, "mrkdwn_in" => ["pretext", "text"],
  "pretext" => "*Breakout (production)* - 1 occurrence", "text" =>
  "*<https://assembla.airbrake.io/projects/8344/groups/1458500049998284918|#1458500049998284918>*\nRepository::Abstract::InvalidRevision: Repository::Abstract::InvalidRevision"}],
  "bot_id" => "B04R9U6AK", "channel" => "C04TVK89J", "subtype" => "bot_message", "text" => "", "ts" => "1436170760.000066"}
  """
  def handle_cast({:handle_incoming, "message", %{"subtype" => "bot_message"} = msg}, state) do
    Logger.debug "bot msg: #{inspect msg}"
    {:noreply, state}
  end

  @doc """
  Message format:
  %{"channel" => "C0777G1UG", "team" => "T024FA4FV", "text" => "epa",
    "ts" => "1436138280.000014", "user" => "U03V6PA8W"}
  """
  def handle_cast({:handle_incoming, "message", msg}, state) do
    Logger.debug "msg: #{inspect msg}"

    u = check_user(state.api_token, msg["user"])

    unless Enum.any?(@rules, fn {pattern, mfa} ->
      ok = false
      match = Regex.run(pattern, msg["text"])

      if match do
        [_| args] = match
        case mfa do
          [m, f] ->
            :erlang.apply(m, f, [self, msg] ++ args)
          f ->
            :erlang.apply(__MODULE__, f, [msg, args])
        end
        ok = true
      end

      ok
    end) do
      if Regex.run(~r{#{@bot}.*}, msg["text"]) do
        unknown_cmd(msg, [])
      end
    end

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

  def handle_cast({:handle_incoming, "hello", _msg}, state) do
    {:noreply, state}
  end

  def unknown_cmd(msg, _) do
    say(self, msg["channel"], "I'm sorry, could not understand you...")
  end

  def show_mr(msg, args) do
    slacker = self

    spawn fn ->
      u = check_user(token(slacker), msg["user"])

      if u.slack_login != "jenks" do
        IO.puts inspect(args)
        [space, tool, id] = args
        SlackBot.Assembla.show_mr(slacker, msg["channel"], space, tool, id)
      end
    end
  end

  def show_ticket(_msg, _args) do

  end

  @doc """
  List sysops logins that are set
  """
  def list_ops(msg, _) do
    ops = Amnesia.transaction do
      User.where is_ops == true,
        select: slack_login
    end |> Amnesia.Selection.values

    Logger.debug "ops #{inspect ops}"

    text = unless Enum.empty?(ops) do
      Enum.join(ops, ", ")
    else
      "There are no ops registered..."
    end

    say(self, msg["channel"], text)
  end

  @doc """
  Display regular expressions and function to be called.
  """
  def help(msg, _) do
    text = Enum.map_join(@rules, "", fn reg -> inspect(reg) <> "\n" end)
    say(self, msg["channel"], text)
  end

  @doc """
  Add another login to the sysops list, userful to check online presence before deploy.
  """
  def do_set_ops(msg, args) do
    [op, login] = args

    case set_ops(login, op == "set") do
      :ok -> say(self, msg["channel"], "Done.")
      :not_found -> say(self, msg["channel"], "User not found.")
    end
  end

  # Set is_ops in the database for the user `login`
  defp set_ops(login, status) do
    rows = Amnesia.transaction(fn -> User.where(slack_login == login) |> Amnesia.Selection.values end)

    case rows do
      [user] -> user
        _user = Amnesia.transaction(fn -> %{user | is_ops: status } |> User.write end)
        :ok
      [] ->
        :not_found
    end
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
                slack_login: user["name"],
                email: user["profile"]["email"], slack_id: s_id,
                presence: "active"} |> User.write end)
        Logger.debug "User created: #{inspect db_user}"
        db_user
    end
  end
end
