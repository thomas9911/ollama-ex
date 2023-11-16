defmodule Ollama do
  @moduledoc """
  asdf
  """

  @spec conn :: Req.Request.t()
  def conn do
    [base_url: get_host()]
    |> Req.new()
    |> Req.Request.append_response_steps(decode_ndjson: &decode_ndjson/1)
  end

  def list_models(conn \\ conn()) do
    conn
    |> Req.get(url: "/api/tags")
  end

  def pull_model(model_name, opts \\ [], conn \\ conn()) do
    insecure = Keyword.get(opts, :insecure, false)
    stream = Keyword.get(opts, :stream, false)
    stream_function = Keyword.get(opts, :stream_function, &pull_model_stream_function/1)

    updated_conn =
      if stream do
        Req.update(conn,
          into: fn {:data, data}, {req, resp} ->
            continue_or_halt = stream_function.(Jason.decode!(data))
            {continue_or_halt, {req, resp}}
          end
        )
      else
        conn
      end

    updated_conn
    |> Req.post(url: "/api/pull", json: %{name: model_name, insecure: insecure, stream: stream})
  end

  @doc """
  Default implementation of the stream response function
  """
  def pull_model_stream_function(data) do
    data
    |> Jason.encode!(pretty: true)
    |> IO.puts()

    :cont
  end

  def show_model(model_name, conn \\ conn()) do
    conn
    |> Req.post(url: "/api/show", json: %{name: model_name})
  end

  def generate_completion(model_name, prompt, conn \\ conn()) do
    conn
    |> Req.post(url: "/api/generate", json: %{model: model_name, prompt: prompt})
  end

  def generate_embeddings(model_name, prompt, conn \\ conn()) do
    conn
    |> Req.post(url: "/api/embeddings", json: %{model: model_name, prompt: prompt})
  end

  defp decode_ndjson({request, response}) do
    case response do
      %Req.Response{
        status: 200,
        headers: %{"content-type" => ["application/x-ndjson"]},
        body: body
      } ->
        decoded_body =
          body
          |> String.split("\n")
          |> Enum.flat_map(fn
            "" -> []
            data -> [Jason.decode!(data)]
          end)

        {request, %{response | body: decoded_body}}

      _ ->
        {request, response}
    end
  end

  defp get_host do
    Application.get_env(:ollama, :host, "http://localhost:11434")
  end
end
