defmodule Ueberauth.Strategy.Strava do
  @moduledoc """
  Strava Strategy for Überauth.
  """

  use Ueberauth.Strategy, default_scope: "read"

  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra
  alias Ueberauth.Auth.Info
  alias Ueberauth.Strategy.Strava.OAuth

  @doc """
  Handles initial request for Strava authentication.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)

    opts =
      [redirect_uri: callback_url(conn), scope: scopes]
      |> with_state_param(conn)

    url = OAuth.authorize_url!(opts)
    redirect!(conn, url)
  end

  @doc """
  Handles the callback from Strava.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => _code} = params} = conn) do
    opts = [grant_type: "authorization_code", redirect_uri: callback_url(conn)]

    case OAuth.get_token(params, opts) do
      {:ok, token} ->
        fetch_athlete(conn, token)

      {:error, {error_code, error_description}} ->
        set_errors!(conn, [error(error_code, error_description)])
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc false
  def handle_cleanup!(conn) do
    conn
    |> put_private(:strava_athlete, nil)
    |> put_private(:strava_token, nil)
  end

  @doc """
  Fetches the uid field from the response.
  """
  def uid(conn) do
    conn.private
    |> Map.fetch!(:strava_athlete)
    |> Map.fetch!("id")
    |> to_string
  end

  @doc """
  Includes the credentials from the Strava response.
  """
  def credentials(conn) do
    token = conn.private.strava_token
    scopes = token.other_params["scope"] || ""
    scopes = String.split(scopes, ",")

    %Credentials{
      expires: !!token.expires_at,
      expires_at: token.expires_at,
      scopes: scopes,
      token: token.access_token,
      refresh_token: token.refresh_token
    }
  end

  @doc """
  Fetches the fields to populate the info section of the
  `Ueberauth.Auth` struct.
  """
  def info(conn) do
    athlete =
      conn
      |> Map.get(:private)
      |> Map.get(:strava_athlete)

    %Info{
      nickname: athlete["username"],
      name: athlete["username"],
      first_name: athlete["firstname"],
      last_name: athlete["lastname"],
      description: athlete["bio"],
      image: athlete["profile"]
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from
  the Strava callback.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.strava_token,
        athlete: conn.private.strava_athlete
      }
    }
  end

  defp fetch_athlete(conn, token) do
    conn = put_private(conn, :strava_token, token)
    path = "/api/v3/athlete"

    case OAuth.get(token, path) do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: athlete}}
      when status_code in 200..399 ->
        put_private(conn, :strava_athlete, athlete)

      {:error, %OAuth2.Response{status_code: status_code}} ->
        set_errors!(conn, [error("OAuth2", status_code)])

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp option(conn, key) do
    default = Keyword.get(default_options(), key)

    conn
    |> options
    |> Keyword.get(key, default)
  end
end
