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

  @token_ttl 6 * 60 * 60

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
      conn(:get, "/auth/strava/callback", %{
        code: "success_code",
        state: csrf_state,
        scope: "read"
      })
      |> set_csrf_cookies(csrf_conn)

    routes = Ueberauth.init([])
    assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
    assert auth.credentials.token == "success_token"
    assert auth.credentials.refresh_token == "refresh_token"

    assert auth.credentials.expires_at ==
             DateTime.utc_now()
             |> DateTime.truncate(:second)
             |> DateTime.to_unix()
             |> Kernel.+(@token_ttl)

    assert auth.info.first_name == "Fred"
    assert auth.info.last_name == "Jones"
    assert auth.info.name == "Frejones"
    assert auth.info.nickname == "Frejones"
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

  defp response(body, code \\ 200), do: {:ok, %OAuth2.Response{status_code: code, body: body}}

  defp oauth2_get_token(%{client_secret: "client_secret"} = client, code: "success_code") do
    token =
      OAuth2.AccessToken.new(%{
        "access_token" => "success_token",
        "refresh_token" => "refresh_token",
        "expires_in" => @token_ttl
      })

    {:ok, %{client | token: token}}
  end

  defp oauth2_get(%{token: token, params: params}, "/api/v3/athlete", _, _) do
    assert %{access_token: "success_token", refresh_token: "refresh_token"} = token

    assert %{"client_secret" => "client_secret"} = params

    response(%{
      "id" => 123_123_123,
      "resource_state" => 2,
      "firstname" => "Fred",
      "lastname" => "Jones",
      "username" => "Frejones"
    })
  end

  defp set_csrf_cookies(conn, csrf_conn) do
    conn
    |> init_test_session(%{})
    |> recycle_cookies(csrf_conn)
    |> fetch_cookies()
  end
end
