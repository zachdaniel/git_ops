defmodule GitOps.GitHub do
  @moduledoc """
  GitHub API integration for looking up user information.
  """

  alias GitOps.Config

  @doc """
  Find a GitHub user by their email address.
  Returns {:ok, user} if found, where user contains :username, :id, and :url.
  Returns {:error, reason} if not found or if there's an error.
  """
  def find_user_by_email(email) do
    response =
      Req.get!(
        "https://api.github.com/search/users",
        params: [
          q: "#{email} in:email",
          per_page: 100
        ],
        headers: [
          accept: "application/vnd.github.v3+json"
          # authorization: "Bearer #{token}"
        ]
      )

    case response do
      %Req.Response{status: 200, body: %{"items" => [first_user | _]}} ->
        {:ok,
         %{
           username: first_user["login"],
           id: first_user["id"],
           url: first_user["html_url"]
         }}

      %Req.Response{status: 200, body: %{"items" => []}} ->
        {:error, "No user found with email #{email}"}

      %Req.Response{status: status, body: body} ->
        {:error, "GitHub API request failed with status #{status}: #{inspect(body)}"}

      _ ->
        {:error, "Unexpected response from GitHub API"}
    end
  rescue
    error ->
      {:error, "Error making GitHub API request: #{inspect(error)}"}
  end
end
