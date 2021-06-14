---
layout: post
title: "Writing a simple API Wrapper in Elixir using GenServer"
---

Recently I've been writing an wrapper for the TD Ameritrade API. I've been learning Elixir as an alternative to Python recently, and I thought that this would be a good use case. I was right.

I've written a few API wrappers, mostly in Python, Golang, or JavaScript. Every time it was pretty painful. Generally, authentication is the most annoying part, followed closely by JSON parsing/processing, especially in static languages. Elixir handles both of these super ergonomically. 

Keeping authentication state is super simple using a GenServer. Just stick the data in a map, set an interval to renew everything, and add some calls and casts. Another benefit of this is that testing specific endpoints is easy using `iex -S mix`, since it gets the auth token on startup.

The code looks roughly like this:

```ex
defmodule TDAPI.TDStorage do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    # get client_id, refresh_token, and auth_token

    store = %{
      client_id: client_id,
      refresh_token: refresh_token,
      auth_token: auth_token
    }

    :timer.send_interval(25 * 60 * 1000, :renew_auth_token)

    {:ok, store}
  end

  @impl true
  def handle_info(:renew_auth_token, store) do
    new_token = get_new_auth_token(store.client_id, store.refresh_token)
    {:noreply, %{store | auth_token: new_token}}
  end

  @impl true
  def handle_call(:get_auth_token, _from, store), do: {:reply, store.auth_token, store}

  defp get_new_auth_token(client_id, refresh_token) do
    url = "..."

    form = [
      ...
      {"refresh_token", refresh_token},
      {"client_id", client_id}
    ]

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    %{body: body} = HTTPoison.post!(url, {:form, form}, headers)
    Jason.decode!(body)["access_token"]
  end

  def get_auth_token(), do: GenServer.call(__MODULE__, :get_auth_token)
end
```

JSON processing is made super ergonomic in Elixir through pattern matching and guards. Being able to write a new function clause for each possible response type is great for cleanly dividing logic. Coupled with Elixir's optional and default argument handling through keyword lists, it's possible to write super flexible function clauses easily.

All in all, It's been a great experience using Elixir for this script. It's not all positives, but my biggest issues are just to do with syntax, and I don't think that that's worth writing about.
