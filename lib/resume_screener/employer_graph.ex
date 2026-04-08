defmodule ResumeScreener.Employer.Graph do
  import Journey.Node

  def new() do
    Journey.new_graph(
      "employer",
      "1.0",
      [
        input(:job_description)
      ],
      singleton: true,
      execution_id_prefix: "e"
    )
  end
end
