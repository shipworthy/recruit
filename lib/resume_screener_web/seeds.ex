defmodule ResumeScreenerWeb.Seeds do
  require Logger

  @default_job_description File.read!("example_job_description.txt")

  def seed_job_description_if_needed(execution) do
    values = Journey.values(execution)

    unless values[:job_description] do
      Journey.set(execution, :job_description, @default_job_description)
      Logger.info("Seeded job description from example_job_description.txt")
    end
  end
end
