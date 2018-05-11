defmodule SampleAppWeb.PageController do
  use SampleAppWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end

  def about(conn, params) do
    IO.inspect "Got a call inside about in page controller with params"
    IO.inspect params

    render conn, "index.html"
  end
end
