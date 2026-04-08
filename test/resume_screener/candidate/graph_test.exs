defmodule ResumeScreener.Candidate.GraphTest do
  @candidates [
    %{name: "morgan", min_score: 82, max_score: 100},
    %{name: "alex", min_score: 25, max_score: 45},
    %{name: "jordan", min_score: 35, max_score: 55},
    %{name: "casey", min_score: 25, max_score: 45},
    %{name: "priya", min_score: 25, max_score: 45},
    %{name: "taylor", min_score: 25, max_score: 45}
  ]

  use ExUnit.Case, parameterize: @candidates

  @moduletag :integration
  @moduletag timeout: 120_000

  @job_description File.read!("test/resume_screener/candidate/jds/radiatorlabs.txt")

  setup %{name: name} do
    candidate = ResumeScreener.Candidate.Graph.new() |> Journey.start()

    on_exit(fn ->
      Journey.archive(candidate)
    end)

    IO.puts("\n--- #{name}: starting execution #{candidate.id}")
    %{candidate: candidate}
  end

  @resumes_dir "test/resume_screener/candidate/test_resumes"

  test "match score within expected range",
       %{candidate: candidate, name: name, min_score: min_score, max_score: max_score} do
    resume = File.read!(Path.join(@resumes_dir, "#{name}.txt"))
    Journey.set(candidate, :job_description, @job_description)
    Journey.set(candidate, :resume, resume)
    Journey.set(candidate, :submitted, System.os_time(:second))

    assert {:ok, true, _} = Journey.get(candidate, :resume_valid, wait: :any)
    IO.puts("--- #{name}: resume_valid: true")

    assert {:ok, summary, _} = Journey.get(candidate, :resume_summary, wait: :any)
    assert is_binary(summary)
    assert String.length(summary) > 100
    IO.puts("--- #{name}: resume_summary (#{String.length(summary)} chars):\n#{summary}")

    assert {:ok, score, _} = Journey.get(candidate, :match_score, wait: :any)
    assert is_integer(score)
    IO.puts("--- #{name}: match_score: #{score} (expected #{min_score}..#{max_score})")
    assert score >= min_score, "#{name}: score #{score} below minimum #{min_score}"
    assert score <= max_score, "#{name}: score #{score} above maximum #{max_score}"
  end
end
