defmodule ResumeScreener.Candidate.Graph do
  import Journey.Node
  import Journey.Node.Conditions
  import Journey.Node.UpstreamDependencies
  require Logger

  def new() do
    Journey.new_graph(
      "candidate",
      "1.0",
      [
        input(:job_description),
        input(:resume),
        input(:submitted),
        compute(
          :resume_valid,
          unblocked_when(
            :and,
            [
              {:resume, &provided?/1},
              {:submitted, &provided?/1}
            ]
          ),
          &is_resume_valid/1
        ),
        compute(
          :resume_summary,
          unblocked_when(
            :and,
            [
              {:resume_valid, &true?/1},
              {:job_description, &provided?/1}
            ]
          ),
          &summarize_resume/1,
          abandon_after_seconds: 300
        ),
        compute(
          :match_score,
          unblocked_when(
            :and,
            [
              {:resume_valid, &true?/1},
              {:job_description, &provided?/1}
            ]
          ),
          &compute_match_score/1,
          abandon_after_seconds: 300
        ),
        input(:decision)
      ],
      execution_id_prefix: "c",
      f_on_save: fn execution_id, node_name, result ->
        Logger.info("f_on_save[#{execution_id}]: candidate updated, #{node_name}, #{inspect(result)}")

        Phoenix.PubSub.broadcast(
          ResumeScreener.PubSub,
          "candidate:#{execution_id}",
          {:refresh, node_name, result}
        )

        :ok
      end
    )
  end

  def is_resume_valid(%{resume: resume}) do
    Logger.info("checking resume validity.")
    ResumeScreener.ResumeAnalysis.is_resume_valid(resume)
  end

  def summarize_resume(%{resume: resume, job_description: job_description}) do
    ResumeScreener.ResumeAnalysis.summarize_resume(resume, job_description)
  end

  def compute_match_score(%{resume: resume, job_description: job_description}) do
    ResumeScreener.ResumeAnalysis.compute_match_score(resume, job_description)
  end
end
