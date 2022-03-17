import Config
config :oauth2, debug: true

config :ueberauth, Ueberauth,
  providers: [
    strava: {Ueberauth.Strategy.Strava, []}
  ]

config :ueberauth, Ueberauth.Strategy.Strava.OAuth,
  client_id: "client_id",
  client_secret: "client_secret",
  token_url: "token_url"
