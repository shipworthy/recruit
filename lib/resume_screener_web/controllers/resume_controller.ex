defmodule ResumeScreenerWeb.ResumeController do
  use ResumeScreenerWeb, :controller

  require Logger

  def download(conn, %{"execution_id" => execution_id}) do
    Logger.info("Resume download requested for #{execution_id}")
    execution = Journey.load(execution_id)

    if execution do
      values = Journey.values(execution)
      resume_text = values[:resume]

      if resume_text do
        Logger.info("Serving resume (#{String.length(resume_text)} chars) for #{execution_id}")

        conn
        |> put_resp_content_type("text/plain")
        |> put_resp_header("content-disposition", ~s(attachment; filename="resume.txt"))
        |> send_resp(200, resume_text)
      else
        Logger.info("No resume found for #{execution_id}")

        conn
        |> put_status(404)
        |> text("No resume uploaded")
      end
    else
      Logger.info("Execution #{execution_id} not found")

      conn
      |> put_status(404)
      |> text("Execution not found")
    end
  end
end
