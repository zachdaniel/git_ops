defmodule GitOps.GitHub do
  @moduledoc """
  GitHub API integration for looking up user information.
  """

  # alias GitOps.Config

  @cache_key_prefix "git_ops:github_user:"

  @doc """
  Find a GitHub user by their email address.
  Returns {:ok, user} if found, where user contains :username, :id, and :url.
  Returns {:error, reason} if not found or if there's an error.

  Results are cached in persistent_term to avoid repeated API calls.
  """
  def find_user_by_email(email) do
    cache_key = @cache_key_prefix <> email

    case :persistent_term.get(cache_key, :not_found) do
      :not_found ->
        # Not in cache, fetch from API
        case fetch_user_from_api(email) do
          {:ok, _user} = result ->
            :persistent_term.put(cache_key, result)
            result

          error ->
            error
        end

      cached_result ->
        cached_result
    end
  end

  @doc """
  Find a GitHub user by their email address.
  Returns {:ok, user} if found, where user contains :username, :id, and :url.
  Returns {:error, reason} if not found or if there's an error.
  """
  def fetch_user_from_api(email) do
    url = ~c"https://api.github.com/search/users?q=#{email}%20in:email&per_page=2"

    headers = [
      {~c"accept", 'application/vnd.github.v3+json'},
      {~c"user-agent", ~c"Elixir.GitOps"},
      {~c"X-GitHub-Api-Version", ~c"2022-11-28"}
    ]

    case :httpc.request(:get, {url, headers}, [], body_format: :binary) do
      {:ok, {{_, 200, _}, _response_headers, body}} ->
        case Jason.decode(body) do
          {:ok, %{"items" => [first_user | _]}} ->
            {:ok,
             %{
               username: first_user["login"],
               id: first_user["id"],
               url: first_user["html_url"]
             }}

          {:ok, %{"items" => []}} ->
            {:error, "No user found with email #{email}"}

          {:error, decode_error} ->
            {:error, "Failed to decode GitHub API response: #{inspect(decode_error)}"}
        end

      {:ok, {{_, status, _}, _response_headers, body}} ->
        {:error, "GitHub API request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Error making GitHub API request: #{inspect(reason)}"}
    end
  rescue
    error ->
      {:error, "Error making GitHub API request: #{inspect(error)}"}
  end

  @doc """
  Clear all cached GitHub user information.
  """
  def clear_cache do
    :persistent_term.get()
    |> Enum.filter(fn {key, _} ->
      is_binary(key) and String.starts_with?(key, @cache_key_prefix)
    end)
    |> Enum.each(fn {key, _} -> :persistent_term.erase(key) end)
  end
end
