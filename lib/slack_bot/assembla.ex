defmodule SlackBot.Assembla do
  alias AssemblaApi.Spaces.SpaceTools.MergeRequests

  @doc """
  Post MR title to channel
  """
  def show_mr(slacker, channel, space, tool, id) do
    {:ok, mr} = MergeRequests.get(space, tool, id)
    SlackBot.say(slacker, channel, mr.title)
  end

  @doc """
  Post ticket title to channel
  """
  def show_ticket(_space, _number) do

  end
end
