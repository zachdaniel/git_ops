defmodule GitOps.Commit do
  @moduledoc """
  Manages the structure, parsing, and formatting of commits.

  Using `parse/1` you can parse a commit struct out of a commit message

  Using `format/1` you can format a commit struct in the way that the
  changelog expects.
  """
  import NimbleParsec

  defstruct [
    :type,
    :scope,
    :message,
    :body,
    :footer,
    :breaking?,
    :author_name,
    :author_email,
    :github_user_data,
    :hash,
    :pr_info
  ]

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
      breaking?: breaking?,
      author_name: author_name,
      author_email: author_email,
      github_user_data: github_user_data,
      pr_info: pr_info
    } = commit

    scope = Enum.join(scopes || [], ",")

    body_text =
      if breaking? && String.starts_with?(body || "", "BREAKING CHANGE:") do
        "\n\n" <> body
      else
        ""
      end

    footer_text =
      if breaking? && footer && String.starts_with?(body || "", "BREAKING CHANGE:") do
        "\n\n" <> footer
      end

    scope_text =
      if String.trim(scope) != "" do
        "#{scope}: "
      else
        ""
      end

    base_changelog_entry = "* #{scope_text}#{message}#{body_text}#{footer_text}"

    author = format_author(author_name, author_email, github_user_data)
    author_text = if author != "", do: " by #{author}", else: ""
    pr_link = if pr_info, do: " [(##{pr_info.number})](#{pr_info.url})", else: ""

    base_changelog_entry <> author_text <> pr_link
  end

  @doc """
  Formats the author information as a GitHub username.
  If a GitHub username is provided, uses that with @ prefix.
  If the email is a GitHub noreply email, extracts the username.
  Otherwise, just uses the author name.
  """
  def format_author(_name, _email, %{username: username, url: url})
      when is_binary(username) and is_binary(url) do
    "[@#{username}](#{url})"
  end

  def format_author(_name, _email, %{username: username}) when is_binary(username) do
    "@#{username}"
  end

  def format_author(nil, _, _), do: ""
  def format_author(_, nil, _), do: ""
  def format_author(name, email, _), do: format_author_fallback(name, email)

  # Fallback to existing logic for handling author information
  defp format_author_fallback(name, email) do
    cond do
      # Match GitHub noreply emails like 12345678+username@users.noreply.github.com
      String.match?(email, ~r/\d+\+(.+)@users\.noreply\.github\.com/) ->
        captures =
          Regex.named_captures(~r/\d+\+(?<username>.+)@users\.noreply\.github\.com/, email)

        "#{captures["username"]}"

      # Match standard GitHub emails like username@users.noreply.github.com
      String.match?(email, ~r/(.+)@users\.noreply\.github\.com/) ->
        captures = Regex.named_captures(~r/(?<username>.+)@users\.noreply\.github\.com/, email)
        "#{captures["username"]}"

      # For other emails, just use the author name
      true ->
        "#{name}"
    end
  end

  def parse(%{text: text, author_info: author_info, hash: hash} = commit_opts)
      when is_map(commit_opts) do
    lines = String.split(text, "\n")
    first_line = lines |> List.first("") |> String.trim()
    rest_lines = Enum.drop(lines, 1)

    case try_parse_line(first_line) do
      :error ->
        :error

      {:ok, first_parsed} ->
        commits_with_bodies = partition_lines(first_parsed, rest_lines)

        commits =
          Enum.map(commits_with_bodies, fn {parsed, body_lines} ->
            build_commit(parsed, body_lines, author_info, hash)
          end)

        {:ok, commits}
    end
  rescue
    _ ->
      :error
  end

  def parse(text, author_info \\ nil) when is_binary(text) do
    parse(%{text: text, author_info: author_info, hash: nil})
  end

  def breaking?(%GitOps.Commit{breaking?: breaking?}), do: breaking?

  def feature?(%GitOps.Commit{type: type}) do
    String.downcase(type) == "feat"
  end

  def fix?(%GitOps.Commit{type: type}) do
    String.downcase(type) == "fix" || String.downcase(type) == "improvement"
  end

  defp try_parse_line(line) do
    case commits(line) do
      {:ok, [{:commit, result} | _], _, _, _, _} -> {:ok, result}
      _ -> :error
    end
  end

  defp partition_lines(first_parsed, lines) do
    {completed, current_parsed, current_body} =
      Enum.reduce(lines, {[], first_parsed, []}, fn line,
                                                    {completed, current_parsed, current_body} ->
        case try_parse_line(String.trim(line)) do
          {:ok, new_parsed} ->
            finalized = {current_parsed, Enum.reverse(current_body)}
            {[finalized | completed], new_parsed, []}

          :error ->
            {completed, current_parsed, [line | current_body]}
        end
      end)

    final = {current_parsed, Enum.reverse(current_body)}
    Enum.reverse([final | completed])
  end

  defp build_commit(parsed, body_lines, author_info, hash) do
    body =
      body_lines
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")
      |> case do
        "" -> nil
        text -> text
      end

    {author_name, author_email} = author_info || {nil, nil}

    %__MODULE__{
      type: Enum.at(parsed[:type], 0),
      scope: scopes(parsed[:scope]),
      message: Enum.at(parsed[:message], 0),
      body: body,
      footer: nil,
      breaking?: breaking?(parsed[:breaking?], body, nil),
      author_name: author_name,
      author_email: author_email,
      hash: hash
    }
  end

  defp scopes([value]) when is_bitstring(value), do: String.split(value, ",")
  defp scopes(_), do: nil

  defp breaking?(breaking, _, _) when not is_nil(breaking), do: true
  defp breaking?(_, "BREAKING CHANGE:" <> _, _), do: true
  defp breaking?(_, _, _), do: false
end
