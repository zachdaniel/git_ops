defmodule GitOps.Commit do
  import NimbleParsec

  defstruct [:type, :scope, :message, :body, :footer, :breaking?]

  whitespace = ignore(ascii_string([9, 32], min: 1))

  # 40/41 are `(` and `)`, but syntax highlighters don't like ?( and ?)
  type =
    optional(whitespace)
    |> tag(ascii_string([not: ?:, not: 40, not: 41], min: 1), :type)
    |> optional(whitespace)

  scope =
    optional(whitespace)
    |> ignore(ascii_char([40]))
    |> tag(ascii_string([not: 40, not: 41], min: 1), :scope)
    |> ignore(ascii_char([41]))
    |> optional(whitespace)

  breaking_change_indicator = tag(ascii_char([?!]), :breaking_change)

  message =
    optional(whitespace)
    |> tag(ascii_string([not: ?\n], min: 1), :message)
    |> optional(ignore(ascii_char([?\n])))

  defparsecp :commit,
             optional(breaking_change_indicator)
             |> concat(type)
             |> concat(optional(scope))
             |> ignore(ascii_char([?:]))
             |> concat(message)

  def parse(text) do
    case commit(text) do
      {:ok, result, remaining, _state, _dunno, _also_dunno} ->
        remaining_lines =
          remaining
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&Kernel.==(&1, ""))

        body = Enum.at(remaining_lines, 0)
        footer = Enum.at(remaining_lines, 1)

        {:ok,
         %__MODULE__{
           type: Enum.at(result[:type], 0),
           scope: scopes(result[:scope]),
           message: result[:message],
           body: body,
           footer: footer,
           breaking?: breaking?(result[:breaking?], body, footer)
         }}

      error = {:error, _message, _remaining, _state, _dunno, _also_dunno} ->
        error
    end
  end

  defp scopes([value]) when is_bitstring(value), do: String.split(value, ",")
  defp scopes(_), do: nil

  defp breaking?(breaking, _, _) when not is_nil(breaking), do: true
  defp breaking?(_, "BREAKING CHANGE:" <> _, _), do: true
  defp breaking?(_, _, "BREAKING CHANGE:" <> _), do: true
  defp breaking?(_, _, _), do: false
end
