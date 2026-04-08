defmodule ResumeScreenerWeb.Live.Employer.Index do
  @moduledoc false
  use ResumeScreenerWeb, :live_view

  require Logger

  def mount(params, _session, socket) do
    socket = assign(socket, :page_title, "Employer")
    graph = ResumeScreener.Employer.Graph.new()
    execution = Journey.find_or_start(graph)
    ResumeScreenerWeb.Seeds.seed_job_description_if_needed(execution)

    candidate_id = params["c"]
    Logger.info("Employer Index mount, execution: #{execution.id}, candidate_id: #{inspect(candidate_id)}")

    socket =
      socket
      |> assign(:execution_id, execution.id)
      |> assign(:candidate_id, candidate_id)
      |> assign(:values, Journey.values(execution))
      |> assign(:introspect, Journey.Tools.introspect(execution.id))
      |> assign(:candidates, load_candidates())
      |> assign(:archived, MapSet.new())

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_tab="employer" candidate_id={@candidate_id}>
      <div class="flex flex-col gap-6 max-w-2xl mx-auto px-6 py-8">
        <h1 class="text-3xl font-bold text-zinc-900">Welcome, Hiring Manager!</h1>
        <div class="w-full">
          <label for="job-description" class="block text-sm font-medium text-zinc-700 mb-1">
            Job Description
          </label>
          <textarea
            id="job-description"
            name="job_description"
            phx-blur="set-job-description"
            placeholder="Describe the role you're hiring for..."
            rows="6"
            class="w-full rounded-lg border border-zinc-300 px-4 py-2 text-sm text-zinc-900 shadow-sm outline-none transition-colors focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500"
          >{@values[:job_description]}</textarea>
        </div>
        <div class="w-full">
          <h2 class="text-xl font-bold text-zinc-900 mb-4">Candidates</h2>
          <p :if={@candidates == []} class="text-sm text-zinc-500">No active candidates.</p>
          <div :if={@candidates != []} class="flex flex-col gap-4">
            <div
              :for={candidate <- @candidates}
              class="rounded-lg border border-zinc-300 p-4"
            >
              <%= if MapSet.member?(@archived, candidate.execution_id) do %>
                <p class="text-sm text-zinc-400 italic">Archived</p>
              <% else %>
                <div class="flex items-center justify-between mb-2">
                  <.link
                    navigate={~p"/candidate/#{candidate.execution_id}"}
                    class="text-sm font-semibold text-blue-600 hover:underline"
                  >
                    {candidate.execution_id}
                  </.link>
                  <span
                    :if={candidate.match_score}
                    class="text-sm font-medium text-zinc-600"
                  >
                    Match score: {candidate.match_score}
                  </span>
                </div>
                <div class="mb-1 text-xs text-zinc-400">
                  {format_submitted(candidate.submitted)}
                </div>
                <p :if={candidate.resume_summary} class="text-sm text-zinc-600 whitespace-pre-line">
                  {candidate.resume_summary}
                </p>
                <div class="flex items-center gap-3 mt-3">
                  <a
                    href={~p"/candidate/#{candidate.execution_id}/resume"}
                    class="inline-block rounded-lg border border-zinc-300 px-4 py-1.5 text-sm font-semibold text-zinc-700 shadow-sm hover:bg-zinc-100 active:bg-zinc-200 transition-colors"
                  >
                    Download Resume
                  </a>
                </div>
                <form class="mt-3 flex items-center gap-2" phx-change="set-decision">
                  <span class="text-sm font-medium text-zinc-700">Next steps:</span>
                  <input type="hidden" name="execution_id" value={candidate.execution_id} />
                  <select
                    name="decision"
                    class="rounded-lg border border-zinc-300 px-3 py-1.5 text-sm text-zinc-900 shadow-sm outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500"
                  >
                    <option value="" selected={is_nil(candidate.decision)}>—</option>
                    <option value="Employer review" selected={candidate.decision == "Employer review"}>
                      Employer review
                    </option>
                    <option value="Schedule screen" selected={candidate.decision == "Schedule screen"}>
                      Schedule screen
                    </option>
                    <option value="None" selected={candidate.decision == "None"}>
                      None
                    </option>
                  </select>
                </form>
                <button
                  type="button"
                  phx-click="archive-candidate"
                  phx-value-execution-id={candidate.execution_id}
                  class="mt-3 rounded-lg border border-zinc-300 px-4 py-1.5 text-sm font-semibold text-zinc-700 shadow-sm hover:bg-zinc-100 active:bg-zinc-200 transition-colors"
                >
                  Archive
                </button>
              <% end %>
            </div>
          </div>
        </div>
        <pre
          :if={@introspect}
          id="introspect"
          class="mt-8 w-full rounded-lg border border-zinc-300 bg-zinc-100 p-4 text-xs text-zinc-700 overflow-x-auto"
        ><span class="text-zinc-400">iex&gt; Journey.Tools.introspect("{@execution_id}")
    </span>{@introspect}</pre>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("set-job-description", %{"value" => value}, socket) do
    value = String.trim(value)

    if value != "" do
      Journey.set(socket.assigns.execution_id, :job_description, value)
      Logger.info("set-job-description: #{String.slice(value, 0, 50)}...")
    else
      Journey.unset(socket.assigns.execution_id, :job_description)
      Logger.info("set-job-description: cleared")
    end

    {:noreply, refresh_execution_state(socket)}
  end

  def handle_event("archive-candidate", %{"execution-id" => execution_id}, socket) do
    Journey.archive(execution_id)
    Logger.info("archive-candidate: #{execution_id}")
    {:noreply, assign(socket, :archived, MapSet.put(socket.assigns.archived, execution_id))}
  end

  def handle_event("set-decision", %{"execution_id" => execution_id, "decision" => decision}, socket) do
    if decision != "" do
      Journey.set(execution_id, :decision, decision)
      Logger.info("set-decision: #{execution_id} -> #{decision}")
    else
      Journey.unset(execution_id, :decision)
      Logger.info("set-decision: #{execution_id} -> cleared")
    end

    {:noreply, assign(socket, :candidates, load_candidates())}
  end

  def handle_info({:refresh, step_name, _value}, socket) do
    Logger.info("Received refresh for step: #{step_name}")
    {:noreply, refresh_execution_state(socket)}
  end

  defp refresh_execution_state(socket) do
    execution = Journey.load(socket.assigns.execution_id)

    if execution do
      socket
      |> assign(:values, Journey.values(execution))
      |> assign(:introspect, Journey.Tools.introspect(socket.assigns.execution_id))
      |> assign(:candidates, load_candidates())
    else
      socket
    end
  end

  defp load_candidates do
    Journey.list_executions(
      graph_name: "candidate",
      filter_by: [{:resume_valid, :eq, true}],
      sort_by: [{:submitted, :desc}]
    )
    |> Enum.map(fn execution ->
      values = Journey.values(execution, reload: false)

      %{
        execution_id: execution.id,
        resume_summary: values[:resume_summary],
        match_score: values[:match_score],
        decision: values[:decision],
        submitted: values[:submitted]
      }
    end)
  end

  defp format_submitted(nil), do: "—"

  defp format_submitted(unix) when is_integer(unix) do
    DateTime.from_unix!(unix)
    |> DateTime.shift_zone!("America/Los_Angeles")
    |> Calendar.strftime("%b %d, %Y at %I:%M %p %Z")
  end

  defp format_submitted(_), do: "—"
end
