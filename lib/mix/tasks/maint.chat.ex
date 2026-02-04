defmodule Mix.Tasks.Maint.Chat do
  @moduledoc """
  Starts an interactive LLM chat session for maintenance tasks.

  The chat agent can list chores, run them, check health, and run setup
  using tool calling. Responses are streamed in real time.

  ## Usage

      mix maint.chat [--model <model_string>]

  ## Options

    * `--model` - LLM model to use (e.g., `anthropic:claude-sonnet-4-20250514`).
      Defaults to the value in `config :maint, chat: [model: ...]` or
      `anthropic:claude-sonnet-4-20250514`.

  ## Configuration

  Set the default model in `config.exs`:

      config :maint,
        chat: [model: "anthropic:claude-sonnet-4-20250514"]

  ## API Keys

  Requires an API key for the configured provider. Set via environment
  variable (e.g., `ANTHROPIC_API_KEY`) or `.env` file.
  """

  @shortdoc "Interactive LLM chat for maintenance tasks"

  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(argv, strict: [model: :string])

    chat_opts =
      case opts[:model] do
        nil -> []
        model -> [model: model]
      end

    Maint.Chat.run(chat_opts)
  end
end
