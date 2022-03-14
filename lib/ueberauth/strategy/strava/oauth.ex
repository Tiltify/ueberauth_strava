defmodule Ueberauth.Strategy.Strava.OAuth do
  @moduledoc """
  OAuth2 for Strava.

  Add `client_id` and `client_secret` to your configuration:

  config :ueberauth, Ueberauth.Strategy.Strava.OAuth,
    client_id: System.get_env("Strava_APP_ID"),
    client_secret: System.get_env("Strava_APP_SECRET")
  """
  use OAuth2.Strategy
  alias OAuth2.Strategy.AuthCode

  @defaults [
    strategy: __MODULE__,
    site: "https://www.strava.com/",
    authorize_url: "https://www.strava.com/oauth/authorize",
    token_url: "https://www.strava.com/oauth/token"
  ]

  @doc """
  Construct a client for requests to Strava.

  This will be setup automatically for you in `Ueberauth.Strategy.Strava`.
  These options are only useful for usage outside the normal callback phase
  of Ueberauth.
  """
  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Strava.OAuth, [])
    opts = @defaults |> Keyword.merge(config) |> Keyword.merge(opts)
    json_library = Ueberauth.json_library()

    opts
    |> OAuth2.Client.new()
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth.
  No need to call this usually.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    client = client(opts)
    OAuth2.Client.authorize_url!(client, params)
  end

  def get(token, url, headers \\ [], opts \\ []) do
    [token: token]
    |> client()
    |> put_param("client_secret", client().client_secret)
    |> OAuth2.Client.get(url, headers, opts)
  end

  def get_token(params \\ [], opts \\ []) do
    client = client(opts)
    code = Map.get(params, "code")

    case OAuth2.Client.get_token(client, code: code) do
      {:error, %{body: %{"errors" => errors, "message" => description}}} ->
        {:error, {errors, description}}

      {:ok, %{token: %{access_token: nil} = token}} ->
        %{"errors" => errors, "message" => description} = token.other_params
        {:error, {errors, description}}

      {:ok, %{token: token}} ->
        {:ok, token}
    end
  end

  # Strategy Callbacks
  def authorize_url(client, params), do: AuthCode.authorize_url(client, params)
  def get_token(client, params, headers), do: AuthCode.get_token(client, params, headers)
end
