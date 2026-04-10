# Recruit: AI-Powered Resume Screening with Journey Durable Workflows

This is a Phoenix LiveView application that uses AI to screen job applications. Candidates upload resumes, and the system validates them, summarizes qualifications, and computes a match score against the job description.

This application uses [Journey](https://hexdocs.pm/journey) durable workflows for orchestrating AI-powered computations with reactive dependencies and persistence.

Here is the blog post that goes with this repo: [Recruiting with AI and Elixir](https://dev.to/markmark/recruiting-with-ai-and-elixir-4cc5)

## The Candidate Workflow Graph

The core of the application's logic is implemented in the candidate workflow graph [./lib/resume_screener/candidate_graph.ex](./lib/resume_screener/candidate_graph.ex).

The graph takes a resume and a job description (and the time of submission) as its inputs, and determines if the resume looks OK, and, if so, summarizes and scores it against the job description.

To make this determination, it uses `facebook/bart-large-mnli` running in `bumblebee` to determine if the resume looks valid (a cheap computation), and it then uses `gemma3:4b` running in a local instance of Ollama for summarization and scoring (which are significantly more expensive computations).

## Prerequisites

- **Elixir** 1.18+ / OTP 27+
- **PostgreSQL** (can run in a container)
- **Ollama** running locally with the `gemma3:4b` model

## Hardware and Performance

On an **Apple M1 Max (32GB RAM)**, a full candidate analysis (validation, scoring, and summarization) typically completes in **under 30 seconds** using `gemma3:4b`.

Performance on other hardware will vary based on GPU/Neural Engine capabilities and available memory.

## Running Postgres in Docker

Start Postgres (if using Docker):
```
$ docker run --rm --name postgres -p 5432:5432 -e POSTGRES_PASSWORD=postgres -d postgres:16
```

## Running Ollama

Install and run Ollama with the required model:
```
$ ollama pull gemma3:4b
$ ollama serve  # may fail if Ollama is already listening
```

Verify Ollama is working:
```
$ curl -s http://localhost:11434/api/generate \
    -d '{"model":"gemma3:4b","prompt":"Capital of Argentina? Just the city name.","stream":false}'
{..., "response": "Buenos Aires", ...}
```

A note on Ollama concurrency:

In the [candidate Journey graph](./lib/resume_screener/candidate_graph.ex), the scoring and summarization nodes (`:match_score` and `:resume_summary`) are independent and are computed in parallel. However, you may still see them complete "sequentially" because, by default, **Ollama serializes processing** of heavy inference requests.

For configuring Ollama to process requests in parallel, please reference Ollama documentation (hint: `OLLAMA_NUM_PARALLEL`).

## Setup

```
$ mix deps.get
$ mix ecto.create
$ mix ecto.migrate
$ cd assets && npm install && cd ..
```

## Run the Web Application

```
$ mix phx.server
```

Visit [localhost:4000](http://localhost:4000). The application is pre-seeded with a default job description. Click "Apply", upload a resume, and submit to watch the workflow execute. The employer page shows the list of submissions, and allows you to change the job description.

## Try It in IEx

```elixir
$ iex -S mix

iex(1)> candidate = ResumeScreener.Candidate.Graph.new() |> Journey.start(); :ok
iex(2)> Journey.set(candidate, :job_description, File.read!("example_job_description.txt")); :ok
iex(3)> Journey.set(candidate, :resume, File.read!("example_resume1.txt")); :ok
iex(4)> Journey.set(candidate, :submitted, System.os_time(:second)); :ok
iex(5)> {:ok, resume_valid?, _revision} = Journey.get(candidate, :resume_valid, wait: :any); resume_valid?
false
iex(6)> {:ok, resume, _revision} = Journey.get(candidate, :resume, wait: :any); resume
"zap barometer zap zap\n"
```

Oh sorry, this is not a real resume! Try `example_resume2.txt` or `example_resume3.txt`!

Also check out the blog for a walkthrough.

## Tests

Run the fast tests (no Ollama required):
```
$ mix test
```

Run the full integration suite (requires Ollama running with `gemma3:4b`, on http://localhost:11434):
```
$ mix test --include integration
```

The integration tests run 6 parameterized candidates against the job description and verify match scores fall within expected ranges.

## References

- Blog: [Recruiting with AI and Elixir](https://dev.to/markmark/recruiting-with-ai-and-elixir-4cc5)
- Journey on Hex: https://hexdocs.pm/journey
- Journey on GitHub: https://github.com/shipworthy/journey
- Journey website: https://gojourney.dev
