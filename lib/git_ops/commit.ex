defmodule GitOps.Commit do
  @moduledoc """
  Manages the structure, parsing, and formatting of commits.

  Using `parse/1` you can parse a commit struct out of a commit message

  Using `format/1` you can format a commit struct in the way that the
  changelog expects.
  """
  import NimbleParsec

  defstruct [:type, :scope, :message, :body, :footer, :breaking?]

  @type t :: %__MODULE__{}

  # credo:disable-for-lines:27 Credo.Check.Refactor.PipeChainStart
  whitespace = ignore(ascii_string([9, 32], min: 1))

  # 40/41 are `(` and `)`, but syntax highlighters don't like ?( and ?)
  type =
    optional(whitespace)
    |> optional(whitespace)
    |> tag(ascii_string([not: ?:, not: ?!, not: 40, not: 41, not: 10, not: 32], min: 1), :type)
    |> optional(whitespace)

  scope =
    optional(whitespace)
    |> ignore(ascii_char([40]))
    |> tag(utf8_string([not: 40, not: 41], min: 1), :scope)
    |> ignore(ascii_char([41]))
    |> optional(whitespace)

  breaking_change_indicator = tag(ascii_char([?!]), :breaking?)

  message = tag(optional(whitespace), ascii_string([not: ?\n], min: 1), :message)

  commit =
    type
    |> concat(optional(scope))
    |> concat(optional(breaking_change_indicator))
    |> ignore(ascii_char([?:]))
    |> concat(message)
    |> concat(optional(whitespace))
    |> concat(optional(ignore(ascii_string([10], min: 1))))

  body =
    [commit, eos()]
    |> choice()
    |> lookahead_not()
    |> utf8_char([])
    |> repeat()
    |> reduce({List, :to_string, []})
    |> tag(:body)

  defparsecp(
    :commits,
    commit
    |> concat(body)
    |> tag(:commit)
    |> repeat(),
    inline: true
  )

  def format(commit) do
    %{
      scope: scopes,
      message: message,
      body: body,
      footer: footer,
      breaking?: breaking?
    } = commit

    scope = Enum.join(scopes || [], ",")

    body_text =
      if breaking? && String.starts_with?(body || "", "BREAKING CHANGE:") do
        "\n\n" <> body
      else
        ""
      end

    footer_text =
      if breaking? && String.starts_with?(body || "", "BREAKING CHANGE:") do
        "\n\n" <> footer
      end

    scope_text =
      if String.trim(scope) != "" do
        "#{scope}: "
      else
        ""
      end

    "* #{scope_text}#{message}#{body_text}#{footer_text}"
  end

  def parse(text) do
    case commits(text) do
      {:ok, [], _, _, _, _} ->
        :error

      {:ok, results, _remaining, _state, _dunno, _also_dunno} ->
        commits =
          Enum.map(results, fn {:commit, result} ->
            remaining_lines =
              result[:body]
              |> Enum.map_join("\n", &String.trim/1)
              # Remove multiple newlines
              |> String.split("\n")
              |> Enum.map(&String.trim/1)
              |> Enum.reject(&Kernel.==(&1, ""))

            body = Enum.at(remaining_lines, 0)
            footer = Enum.at(remaining_lines, 1)

            %__MODULE__{
              type: Enum.at(result[:type], 0),
              scope: scopes(result[:scope]),
              message: Enum.at(result[:message], 0),
              body: body,
              footer: footer,
              breaking?: breaking?(result[:breaking?], body, footer)
            }
          end)

        {:ok, commits}
    end
  rescue
    _ ->
      :error
  end

  def breaking?(%GitOps.Commit{breaking?: breaking?}), do: breaking?

  def feature?(%GitOps.Commit{type: type}) do
    String.downcase(type) == "feat"
  end

  def fix?(%GitOps.Commit{type: type}) do
    String.downcase(type) == "fix" || String.downcase(type) == "improvement"
  end

  defp scopes([value]) when is_bitstring(value), do: String.split(value, ",")
  defp scopes(_), do: nil

  defp breaking?(breaking, _, _) when not is_nil(breaking), do: true
  defp breaking?(_, "BREAKING CHANGE:" <> _, _), do: true
  defp breaking?(_, _, "BREAKING CHANGE:" <> _), do: true
  defp breaking?(_, _, _), do: false
end
