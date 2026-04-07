defmodule ResumeScreener.ResumeAnalysis do
  require Logger

  @resume_label "a professional resume describing a person's professional background and experiences"

  @summarize_system """
  You are a very concise hiring assistant. You just say the thing, you keep your total response under 300 words. No preamble or closing remarks.

  Given a resume and job description, provide:
  1. General overview of the candidate's profile.
  2. Most impressive skills, experiences, and deliverables.
  3. Skills and experiences relevant to this job description.
  4. Important skills and experiences the candidate is missing.
  5. Things worth asking the candidate about.
  """

  @score_system """
  You are a hiring assistant.
  You are looking at a candidate's resume, and a job description.
  You need to rate the match between the candidate and the job.

  Respond with only an integer number, from 0 to 100.

  0 = not a fit, 100 = perfect fit. No other text.
  """

  def classifier_serving do
    Logger.info("Loading classifier model...")

    {:ok, model} = Bumblebee.load_model({:hf, "facebook/bart-large-mnli"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "facebook/bart-large-mnli"})

    serving =
      Bumblebee.Text.zero_shot_classification(model, tokenizer, [
        @resume_label,
        "not a resume"
      ])

    Logger.info("Classifier model loaded")
    serving
  end

  def is_resume_valid(resume_text) do
    Logger.info("checking resume for validity")
    truncated = sanitize_and_truncate(resume_text)

    result = Nx.Serving.batched_run(ResumeScreener.ResumeClassifier, truncated)

    resume_score =
      Enum.find(result.predictions, fn p -> p.label == @resume_label end)

    {:ok, resume_score.score > 0.8}
  end

  def summarize_resume(resume_text, job_description) do
    summarize_resume(resume_text, "candidate", job_description)
  end

  def summarize_resume(resume_text, name, job_description) do
    Logger.info("summarizing resume for #{name}")
    decoded = sanitize_text(resume_text)

    prompt = """
    Resume:
    #{decoded}

    Job description:
    #{job_description}
    """

    summary = ollama_generate(prompt, @summarize_system) |> String.trim()
    Logger.info("resume summary composed for #{name}")
    {:ok, summary}
  end

  def compute_match_score(resume_text, job_description) do
    compute_match_score(resume_text, "candidate", job_description)
  end

  def compute_match_score(resume_text, name, job_description) do
    Logger.info("computing match score for #{name}")
    decoded = sanitize_text(resume_text)

    prompt = """
    Resume:
    #{decoded}

    Job description:
    #{job_description}
    """

    text = ollama_generate(prompt, @score_system) |> String.trim()
    score = parse_score(text)
    Logger.info("match score computed for #{name}, #{score}")
    {:ok, score}
  end

  defp ollama_generate(prompt, system) do
    Req.post!("http://localhost:11434/api/generate",
      json: %{
        model: "gemma3:4b",
        prompt: prompt,
        system: system,
        stream: false
      },
      receive_timeout: 120_000
    ).body["response"]
  end

  defp parse_score(text) do
    case Regex.run(~r/\d+/, text) do
      [num] -> num |> String.to_integer() |> min(100) |> max(0)
      _ -> 50
    end
  end

  defp sanitize_text(text) do
    text
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.chunk(:valid)
    |> Enum.filter(&String.valid?/1)
    |> Enum.join()
  end

  defp sanitize_and_truncate(text) do
    sanitize_text(text)
    |> String.slice(0, 1500)
  end
end
