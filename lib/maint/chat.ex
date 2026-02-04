defmodule Maint.Chat do
  @moduledoc """
  Interactive LLM chat interface for the Maint framework.

  Provides a streaming conversation loop using ReqLLM with tool calling
  support. The LLM can list chores, run them, check health, and run setup.
  """

  alias ReqLLM.{Context, Tool}

  @default_model "anthropic:claude-sonnet-4-20250514"

  @doc """
  Starts the interactive chat loop.

  ## Options

    * `:model` - LLM model string (default: from config or `#{@default_model}`)
  """
  @spec run(keyword()) :: :ok
  def run(opts \\ []) do
    model = opts[:model] || configured_model()
    tools = Maint.Chat.Tools.all()
    context = Context.new([Context.system(system_prompt())])

    Mix.shell().info("Maint Chat (#{model})")
    Mix.shell().info("Type 'exit' or 'quit' to end the session.\n")

    chat_loop(model, context, tools)
  end

  defp configured_model do
    :maint
    |> Application.get_env(:chat, [])
    |> Keyword.get(:model, @default_model)
  end

  defp system_prompt do
    chores = Maint.configured_chores()

    chore_summary =
      case chores do
        [] ->
          "No chores are currently configured."

        chores ->
          Enum.map_join(chores, ", ", fn c -> "#{c[:name]}" end)
      end

    """
    You are a helpful assistant for the Maint maintenance automation framework.
    Maint helps Elixir developers manage project maintenance tasks called "chores".

    You have tools to interact with the chore system. Always use tools to gather
    information rather than guessing. When the user asks about chores, dependencies,
    project health, or maintenance tasks, use the appropriate tool.

    Currently configured chores: #{chore_summary}
    """
  end

  defp chat_loop(model, context, tools) do
    case read_input() do
      :eof ->
        Mix.shell().info("\nGoodbye!")
        :ok

      :exit ->
        Mix.shell().info("Goodbye!")
        :ok

      "" ->
        chat_loop(model, context, tools)

      message ->
        new_context = Context.append(context, Context.user(message))

        case stream_and_handle_tools(model, new_context, tools) do
          {:ok, updated_context} ->
            IO.write("\n\n")
            chat_loop(model, updated_context, tools)

          {:error, error} ->
            Mix.shell().error("Error: #{inspect(error)}")
            chat_loop(model, context, tools)
        end
    end
  end

  defp read_input do
    case IO.gets("you> ") do
      :eof ->
        :eof

      {:error, _} ->
        :eof

      input ->
        trimmed = String.trim(input)

        if trimmed in ["exit", "quit"] do
          :exit
        else
          trimmed
        end
    end
  end

  defp stream_and_handle_tools(model, context, tools) do
    IO.write("\n")

    case ReqLLM.stream_text(model, context.messages, tools: tools) do
      {:ok, stream_response} ->
        chunks = collect_and_stream_chunks(stream_response.stream)

        case extract_tool_calls(chunks) do
          [] ->
            text = chunks |> Enum.map_join("", & &1.text)
            final_context = Context.append(context, Context.assistant(text))
            {:ok, final_context}

          tool_calls ->
            initial_text = chunks |> Enum.map_join("", & &1.text)
            assistant_msg = Context.assistant(initial_text, tool_calls: tool_calls)
            context_with_calls = Context.append(context, assistant_msg)

            context_with_results = execute_tool_calls(context_with_calls, tool_calls, tools)

            # Follow-up call for final response after tool results
            case ReqLLM.stream_text(model, context_with_results.messages) do
              {:ok, followup_stream} ->
                IO.write("\n")
                followup_chunks = collect_and_stream_chunks(followup_stream.stream)
                followup_text = followup_chunks |> Enum.map_join("", & &1.text)

                final_context =
                  Context.append(context_with_results, Context.assistant(followup_text))

                {:ok, final_context}

              {:error, error} ->
                {:error, error}
            end
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp collect_and_stream_chunks(stream) do
    Enum.map(stream, fn chunk ->
      IO.write(chunk.text)
      chunk
    end)
  end

  defp extract_tool_calls(chunks) do
    tool_calls =
      chunks
      |> Enum.filter(&(&1.type == :tool_call))
      |> Enum.map(fn chunk ->
        %{
          id: Map.get(chunk.metadata, :id) || "call_#{:erlang.unique_integer([:positive])}",
          name: chunk.name,
          arguments: chunk.arguments || %{},
          index: Map.get(chunk.metadata, :index, 0)
        }
      end)

    arg_fragments =
      chunks
      |> Enum.filter(fn
        %{type: :meta, metadata: %{tool_call_args: _}} -> true
        _ -> false
      end)
      |> Enum.group_by(& &1.metadata.tool_call_args.index)
      |> Map.new(fn {index, fragments} ->
        json = fragments |> Enum.map_join("", & &1.metadata.tool_call_args.fragment)
        {index, json}
      end)

    Enum.map(tool_calls, fn call ->
      case Map.get(arg_fragments, call.index) do
        nil ->
          Map.delete(call, :index)

        json ->
          case Jason.decode(json) do
            {:ok, args} -> call |> Map.put(:arguments, args) |> Map.delete(:index)
            {:error, _} -> Map.delete(call, :index)
          end
      end
    end)
  end

  defp execute_tool_calls(context, tool_calls, tools) do
    Enum.reduce(tool_calls, context, fn tool_call, ctx ->
      tool = Enum.find(tools, fn t -> t.name == tool_call.name end)

      IO.write("\n")

      if tool do
        case Tool.execute(tool, tool_call.arguments) do
          {:ok, result} ->
            IO.write("[tool: #{tool_call.name}] Done\n")
            result_str = if is_binary(result), do: result, else: inspect(result)

            tool_msg = Context.tool_result_message(tool_call.name, tool_call.id, result_str)
            Context.append(ctx, tool_msg)

          {:error, error} ->
            IO.write("[tool: #{tool_call.name}] Error: #{inspect(error)}\n")

            error_msg =
              Context.tool_result_message(
                tool_call.name,
                tool_call.id,
                "Error: #{inspect(error)}"
              )

            Context.append(ctx, error_msg)
        end
      else
        IO.write("[tool: #{tool_call.name}] Not found\n")
        ctx
      end
    end)
  end
end
