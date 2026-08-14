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
      case Req.get("#{GitOps.Config.github_api_base_url()}/search/users",
             headers: github_headers(),
             params: [q: "#{email} in:email type:user", per_page: 2]
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
           "#{GitOps.Config.github_api_base_url()}/repos/#{repo_owner_and_name()}/commits/#{hash}/pulls",
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

  @doc """
  Create or update the open pull request for `branch`, returning its URL and
  number.

  `labels` are applied when the pull request is first created.
  """
  @spec upsert_pull_request(String.t(), String.t(), String.t(), String.t(), [String.t()]) ::
          {:ok, %{url: String.t(), number: pos_integer()}} | {:error, String.t()}
  def upsert_pull_request(branch, base, title, body, labels \\ []) do
    Application.ensure_all_started(:req)
    repo = repo_owner_and_name()
    owner = repo |> String.split("/") |> hd()

    with {:ok, existing} <- find_open_pull_request(repo, owner, branch) do
      case existing do
        nil ->
          create_pull_request(repo, %{base: base, head: branch, title: title, body: body}, labels)

        number ->
          with {:ok, url} <- patch("/repos/#{repo}/pulls/#{number}", %{title: title, body: body}) do
            {:ok, %{url: url, number: number}}
          end
      end
    end
  end

  defp create_pull_request(repo, payload, labels) do
    case request(:post, "/repos/#{repo}/pulls", json: payload) do
      {:ok, %Req.Response{status: 201, body: body}} ->
        if labels != [] do
          request(:post, "/repos/#{repo}/issues/#{body["number"]}/labels",
            json: %{labels: labels}
          )
        end

        {:ok, %{url: body["html_url"], number: body["number"]}}

      other ->
        request_error(other)
    end
  end

  @doc """
  Replace the body of pull request `number`, returning its URL.
  """
  @spec update_pull_request_body(pos_integer(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def update_pull_request_body(number, body) do
    Application.ensure_all_started(:req)

    patch("/repos/#{repo_owner_and_name()}/pulls/#{number}", %{body: body})
  end

  @doc """
  The number of the open pull request for `branch`, or `nil` when there is none.
  """
  @spec open_pull_request_number(String.t()) ::
          {:ok, pos_integer() | nil} | {:error, String.t()}
  def open_pull_request_number(branch) do
    Application.ensure_all_started(:req)
    repo = repo_owner_and_name()

    find_open_pull_request(repo, repo |> String.split("/") |> hd(), branch)
  end

  @doc """
  Close the open pull request numbered `number`, commenting `comment` on it
  first when one is given.
  """
  @spec close_pull_request(pos_integer(), String.t() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  def close_pull_request(number, comment \\ nil) do
    Application.ensure_all_started(:req)
    repo = repo_owner_and_name()

    if comment do
      request(:post, "/repos/#{repo}/issues/#{number}/comments", json: %{body: comment})
    end

    patch("/repos/#{repo}/pulls/#{number}", %{state: "closed"})
  end

  @doc """
  Create a GitHub release for an existing tag, returning its URL.
  """
  @spec create_release(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def create_release(tag, name, notes) do
    Application.ensure_all_started(:req)

    post("/repos/#{repo_owner_and_name()}/releases", %{tag_name: tag, name: name, body: notes})
  end

  defp find_open_pull_request(repo, owner, branch) do
    case request(:get, "/repos/#{repo}/pulls",
           params: [head: "#{owner}:#{branch}", state: "open", per_page: 1]
         ) do
      {:ok, %Req.Response{status: 200, body: [pr | _]}} -> {:ok, pr["number"]}
      {:ok, %Req.Response{status: 200, body: []}} -> {:ok, nil}
      other -> request_error(other)
    end
  end

  defp post(path, payload) do
    case request(:post, path, json: payload) do
      {:ok, %Req.Response{status: status, body: body}} when status in [200, 201] ->
        {:ok, body["html_url"]}

      other ->
        request_error(other)
    end
  end

  defp patch(path, payload) do
    case request(:patch, path, json: payload) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body["html_url"]}
      other -> request_error(other)
    end
  end

  defp request(method, path, opts) do
    Req.request(
      [
        method: method,
        url: GitOps.Config.github_api_base_url() <> path,
        headers: github_headers()
      ] ++
        opts ++ Application.get_env(:git_ops, :req_options, [])
    )
  end

  defp request_error({:ok, %Req.Response{status: status, body: body}}),
    do: {:error, "GitHub API request failed with status #{status}: #{inspect(body)}"}

  defp request_error({:error, reason}),
    do: {:error, "Error making GitHub API request: #{inspect(reason)}"}

  defp repo_owner_and_name() do
    GitOps.Config.repository_url()
    |> String.split("/")
    |> Enum.take(-2)
    |> Enum.join("/")
  end

  defp github_headers do
    headers = %{
      "accept" => "application/vnd.github.v3+json",
      "user-agent" => "Elixir.GitOps",
      "X-GitHub-Api-Version" => "2022-11-28"
    }

    case System.get_env("GITHUB_TOKEN") do
      nil -> headers
      token -> Map.put(headers, "authorization", "Bearer #{token}")
    end
  end
end
