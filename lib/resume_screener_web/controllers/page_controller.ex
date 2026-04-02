defmodule ResumeScreenerWeb.PageController do
  use ResumeScreenerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
