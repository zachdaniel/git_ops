defmodule GitOps.Commit do
  import NimbleParsec

  defstruct [:type, :scope, :message, :body, :footer, :breaking?]

  # def parse(message) do
  # end
  whitespace = ignore(ascii_string([9, 32], min: 1))

  type =
    optional(whitespace)
    |> tag(ascii_string([not: ?:], min: 1), :type)
    |> optional(whitespace)
    |> ignore(ascii_char([?:]))

  # 40/41 are `(` and `)`, but syntax highlighters don't like ?( and ?)
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
             |> concat(message)

  def parse(text) do
    case commit(text) do
      # {:ok, [{:type, ["docs"]}, 58], " Adding addendums to readme", %{}, {1, 0}, 5}
      {:ok, result, remaining, _state, _dunno, _also_dunno} ->
        remaining_lines =
          remaining
          |> String.split("\n")
          |> Enum.map(&String.trim/1)

        {:ok,
         %__MODULE__{
           type: result[:type],
           scope: scopes(result[:scope]),
           message: result[:message],
           body: Enum.at(remaining_lines, 0),
           footer: Enum.at(remaining_lines, 1)
         }}

      error = {:error, message, _remaining, _state, _dunno, _also_dunno} ->
        IO.inspect(error)
        {:error, message}
    end
  end

  defp scopes(value) when is_bitstring(value), do: String.split(value)
  defp scopes(_), do: nil
end
