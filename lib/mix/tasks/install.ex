defmodule Mix.Tasks.Install do
  use Mix.Task
  use Database
  alias Database.User

  @shortdoc "Creates the amnesia database"
  def run(_) do
    # This creates the mnesia schema, this has to be done on every node before
    # starting mnesia itself, the schema gets stored on disk based on the
    # `-mnesia` config, so you don't really need to create it every time.
    IO.puts "Schema: #{inspect(Amnesia.Schema.create)}"

    # Once the schema has been created, you can start mnesia.
    :ok = Amnesia.start

    # When you call create/1 on the database, it creates a metadata table about
    # the database for various things, then iterates over the tables and creates
    # each one of them with the passed copying behaviour
    #
    # In this case it will keep a ram and disk copy on the current node.
    IO.puts "db create: #{inspect(Database.create(disk: [node]))}"

    # This waits for the database to be fully created.
    :ok = Database.wait

    IO.puts inspect(User.attributes)

    # all_users = Amnesia.transaction fn -> Database.User.foldl([], fn row, acc -> [row|acc] end) end
    # Do not use! :ok = Amnesia.Table.transform(User, Keyword.keys(User.attributes))
    # New records will be created for existing users.
    # TODO create tmp table, move rows migrated there, after delete and recreate users table
    # insert rows back and remove tmp table.

    rez = Amnesia.transaction do
    end

    IO.puts "Txn: #{inspect(rez)}"

    # Stop mnesia so it can flush everything and keep the data sane.
    IO.puts "Stop: #{inspect(Amnesia.stop)}"
    IO.puts "Finished"
  end
end
