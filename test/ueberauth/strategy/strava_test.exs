defmodule Ueberauth.Strategy.StravaTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Mock
  import Plug.Conn
  import Ueberauth.Strategy.Helpers

  alias Plug.Conn.Query

  setup_with_mocks([
    {OAuth2.Client, [:passthrough],
     [
       get_token: &oauth2_get_token/2,
       get: &oauth2_get/4
     ]}
  ]) do
    # Create a connection with Ueberauth's CSRF cookies so they can be recycled during tests
    routes = Ueberauth.init([])
    csrf_conn = conn(:get, "/auth/strava", %{}) |> Ueberauth.call(routes)
    csrf_state = with_state_param([], csrf_conn) |> Keyword.get(:state)

    {:ok, csrf_conn: csrf_conn, csrf_state: csrf_state}
  end

  test "handle_request! redirects to appropriate auth uri" do
    conn = conn(:get, "/auth/strava", %{})
    routes = Ueberauth.init() |> set_options(conn, default_scope: "read")

    resp = Ueberauth.call(conn, routes)

    assert resp.status == 302
    assert [location] = get_resp_header(resp, "location")

    redirect_uri = URI.parse(location)
    assert redirect_uri.host == "www.strava.com"
    assert redirect_uri.path == "/oauth/authorize"

    assert %{
             "client_id" => "client_id",
             "redirect_uri" => "http://www.example.com/auth/strava/callback",
             "response_type" => "code",
             "scope" => "read"
           } = Query.decode(redirect_uri.query)
  end

  test "handle_callback! assigns required fields on successful auth", %{
    csrf_state: csrf_state,
    csrf_conn: csrf_conn
  } do
    conn =
      conn(:get, "/auth/strava/callback", %{code: "success_code", state: csrf_state})
      |> set_csrf_cookies(csrf_conn)

    routes = Ueberauth.init([])
    assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
    assert auth.credentials.token == "success_token"
    assert auth.info.name == "Fred Jones"
    assert auth.info.first_name == "Fred"
    assert auth.uid == "123123123"
  end

  def set_options(routes, conn, opt) do
    case Enum.find_index(routes, &(elem(&1, 0) == {conn.request_path, conn.method})) do
      nil ->
        routes

      idx ->
        update_in(routes, [Access.at(idx), Access.elem(1), Access.elem(2)], &%{&1 | options: opt})
    end
  end

  defp token(client, opts), do: {:ok, %{client | token: OAuth2.AccessToken.new(opts)}}
  defp response(body, code \\ 200), do: {:ok, %OAuth2.Response{status_code: code, body: body}}
  defp oauth2_get_token(client, code: "success_code"), do: token(client, "success_token")

  defp oauth2_get(%{token: %{access_token: "success_token"}}, _url, _, _),
    do:
      response(%{
        "token_type" => "Bearer",
        "expires_at" => 1_647_040_821,
        "expires_in" => 17_062,
        "refresh_token" => "some_refresh_token",
        "access_token" => "some_access_token",
        "athlete" => %{
          "id" => 123_123_123,
          "resource_state" => 2,
          "firstname" => "Fred",
          "lastname" => "Jones"
        }
      })

  defp set_csrf_cookies(conn, csrf_conn) do
    conn
    |> init_test_session(%{})
    |> recycle_cookies(csrf_conn)
    |> fetch_cookies()
  end
end
