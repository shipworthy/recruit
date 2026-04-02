defmodule ResumeScreener.Repo do
  use Ecto.Repo,
    otp_app: :resume_screener,
    adapter: Ecto.Adapters.Postgres
end
