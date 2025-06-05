defmodule GitOps.GitHub do
  @moduledoc """
  GitHub API integration for looking up user information.
  """

  @doc """
  Batch find GitHub users by their email addresses.
  Returns a map of %{email => {:ok, user_info} | {:error, reason}}
  """
  def batch_find_users_by_emails(emails) when is_list(emails) do
    unique_emails = Enum.uniq(emails)

    unique_emails
    |> Task.async_stream(&fetch_user_from_api/1, timeout: 30_000, max_concurrency: 5)
    |> Enum.zip(unique_emails)
    |> Enum.map(fn {{:ok, result}, email} -> {email, result} end)
    |> Map.new()
  end

  @doc """
  Find a GitHub user by their email address.
  Returns {:ok, user} if found, where user contains :username, :id, and :url.
  Returns {:error, reason} if not found or if there's an error.
  """
  def fetch_user_from_api(email) do
    Application.ensure_all_started(:req)

    if email do
      headers = %{
        "accept" => "application/vnd.github.v3+json",
        "user-agent" => "Elixir.GitOps",
        "X-GitHub-Api-Version" => "2022-11-28"
      }

      case Req.get("https://api.github.com/search/users",
             headers: headers,
             params: [q: "#{email} in:email", per_page: 2]
           ) do
        {:ok, %Req.Response{status: 200, body: %{"items" => [first_user | _]}}} ->
          {:ok,
           %{
             username: first_user["login"],
             id: first_user["id"],
             url: first_user["html_url"]
           }}

        {:ok, %Req.Response{status: 200, body: %{"items" => []}}} ->
          {:error, "No user found with email #{email}"}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, "GitHub API request failed with status #{status}: #{inspect(body)}"}

        {:error, reason} ->
          {:error, "Error making GitHub API request: #{inspect(reason)}"}
      end
    end
  rescue
    error ->
      {:error, "Error making GitHub API request: #{inspect(error)}"}
  end
end
