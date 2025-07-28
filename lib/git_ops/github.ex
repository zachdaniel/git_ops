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

  def batch_pull_requests_from_commits(hashes) when is_list(hashes) do
    hashes
    |> Task.async_stream(&get_pull_request_from_commit/1,
      timeout: 30_000,
      max_concurrency: 5
    )
    |> Enum.zip(hashes)
    |> Enum.map(fn {{:ok, result}, hash} -> {hash, result} end)
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
      case Req.get("https://api.github.com/search/users",
             headers: github_headers(),
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

  @spec get_pull_request_from_commit(String.t()) ::
          {:ok, %{number: integer(), url: String.t()} | nil} | {:error, String.t()}

  def get_pull_request_from_commit(hash) do
    case Req.get(
           "https://api.github.com/repos/#{repo_owner_and_name()}/commits/#{hash}/pulls",
           headers: github_headers()
         ) do
      {:ok, %Req.Response{status: 200, body: [first_pr | _]}} ->
        {:ok, %{number: first_pr["number"], url: first_pr["html_url"]}}

      {:ok, %Req.Response{status: 200, body: []}} ->
        {:ok, nil}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "GitHub API request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Error making GitHub API request: #{inspect(reason)}"}
    end
  end

  defp repo_owner_and_name() do
    GitOps.Config.repository_url()
    |> String.split("/")
    |> Enum.take(-2)
    |> Enum.join("/")
  end

  defp github_headers do
    %{
      "accept" => "application/vnd.github.v3+json",
      "user-agent" => "Elixir.GitOps",
      "X-GitHub-Api-Version" => "2022-11-28"
    }
  end
end
