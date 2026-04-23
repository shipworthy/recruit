defmodule ResumeScreenerWeb.Live.Candidate.Index do
  @moduledoc false
  use ResumeScreenerWeb, :live_view

  require Logger

  def mount(%{"execution_id" => execution_id}, _session, socket) do
    Logger.info("Candidate Index mount with execution_id: #{execution_id}")

    socket = assign(socket, :page_title, "Candidate")
    employer_execution = Journey.find_or_start(ResumeScreener.Employer.Graph.new())
    ResumeScreenerWeb.Seeds.seed_job_description_if_needed(employer_execution)
    employer_values = Journey.values(employer_execution)
    execution = Journey.load(execution_id)

    socket =
      if execution do
        :ok = Phoenix.PubSub.subscribe(ResumeScreener.PubSub, "candidate:#{execution_id}")

        values = Journey.values(execution)

        socket
        |> assign(:execution_id, execution_id)
        |> assign(:values, values)
        |> assign(:computation_states, computation_states(execution_id))
        |> assign(:introspect, Journey.Tools.introspect(execution_id))
        |> assign(:graph_mermaid, generate_mermaid_execution(execution_id))
        |> assign(:employer_values, employer_values)
        |> assign(:mermaid_tab, "visual")
        |> allow_upload(:resume,
          accept: ~w(.txt .md),
          max_entries: 1,
          max_file_size: 10_000_000,
          auto_upload: true,
          progress: &handle_progress/3
        )
      else
        Logger.warning("Execution #{execution_id} not found, redirecting to /")

        socket
        |> push_navigate(to: ~p"/")
      end

    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    Logger.info("Candidate Index mount")

    socket = assign(socket, :page_title, "Candidate")
    employer_execution = Journey.find_or_start(ResumeScreener.Employer.Graph.new())
    ResumeScreenerWeb.Seeds.seed_job_description_if_needed(employer_execution)
    employer_values = Journey.values(employer_execution)

    socket =
      socket
      |> assign(:execution_id, nil)
      |> assign(:values, %{})
      |> assign(:computation_states, %{})
      |> assign(:introspect, nil)
      |> assign(:graph_mermaid, nil)
      |> assign(:employer_values, employer_values)
      |> assign(:mermaid_tab, "visual")
      |> allow_upload(:resume,
        accept: ~w(.txt .md),
        max_entries: 1,
        max_file_size: 10_000_000,
        auto_upload: true,
        progress: &handle_progress/3
      )

    {:ok, socket}
  end

  def render(assigns) do
    Logger.info("Candidate Index render")

    ~H"""
    <Layouts.app flash={@flash} current_tab="candidate" candidate_id={@execution_id}>
      <div class="flex flex-col gap-6 max-w-2xl mx-auto px-6 py-8">
        <h1 class="text-3xl font-bold text-zinc-900">Welcome, Candidate!</h1>
        <details
          :if={@employer_values[:job_description]}
          class="group w-full rounded-lg border border-zinc-300"
        >
          <summary class="cursor-pointer flex items-center gap-2 px-4 py-2 list-none [&::-webkit-details-marker]:hidden">
            <.icon name="hero-chevron-down" class="size-4 text-zinc-500 group-open:hidden" />
            <.icon name="hero-chevron-up" class="size-4 text-zinc-500 hidden group-open:block" />
            <span class="text-sm font-medium text-zinc-700">Job Description</span>
            <.icon name="hero-chevron-down" class="size-4 text-zinc-500 group-open:hidden" />
            <.icon name="hero-chevron-up" class="size-4 text-zinc-500 hidden group-open:block" />
          </summary>
          <div
            id="job-description"
            class="px-4 py-2 border-t border-zinc-300 bg-zinc-100 text-sm text-zinc-900 whitespace-pre-line rounded-b-lg"
          >
            {@employer_values[:job_description]}
          </div>
        </details>
        <div class="w-full">
          <form id="upload-form" phx-change="validate-upload">
            <.live_file_input upload={@uploads.resume} disabled={@values[:submitted]} class="hidden" />
            <label
              for={@uploads.resume.ref}
              class={[
                "inline-block rounded-lg px-6 py-3 text-sm font-semibold shadow-sm transition-colors",
                if(@values[:submitted],
                  do: "bg-zinc-300 text-zinc-500 cursor-not-allowed pointer-events-none",
                  else: "cursor-pointer bg-zinc-900 text-white hover:bg-zinc-700 active:bg-zinc-800"
                )
              ]}
            >
              Upload Resume (.txt, .md)
            </label>
            <button
              :if={@values[:resume] && !@values[:submitted]}
              type="button"
              phx-click="clear-resume"
              class="rounded-lg border border-zinc-300 px-6 py-3 text-sm font-semibold text-zinc-700 shadow-sm hover:bg-zinc-100 active:bg-zinc-200 transition-colors"
            >
              Clear
            </button>
            <%= for entry <- @uploads.resume.entries do %>
              <p :for={err <- upload_errors(@uploads.resume, entry)} class="mt-2 text-sm text-red-600">
                {upload_error_to_string(err)}
              </p>
            <% end %>
          </form>
          <textarea
            id="resume-paste"
            phx-blur={if !@values[:submitted], do: "set-resume-text"}
            readonly={@values[:submitted]}
            placeholder="Paste your resume here..."
            rows="8"
            class={[
              "mt-3 w-full rounded-lg border border-zinc-300 px-4 py-2 text-sm shadow-sm outline-none transition-colors",
              if(@values[:submitted],
                do: "bg-zinc-50 text-zinc-500 cursor-not-allowed",
                else: "text-zinc-900 focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500"
              )
            ]}
          >{@values[:resume]}</textarea>
        </div>
        <div :if={@execution_id} class="flex items-center gap-3">
          <button
            id="submit-application-btn"
            phx-click="submit-application"
            disabled={@values[:submitted] || !@values[:resume]}
            class={[
              "rounded-lg px-6 py-3 text-sm font-semibold text-white shadow-sm transition-colors",
              if(@values[:resume] && !@values[:submitted],
                do: "bg-green-700 hover:bg-green-600 active:bg-green-800",
                else: "bg-zinc-300 cursor-not-allowed"
              )
            ]}
          >
            Submit Application
          </button>
          <button
            id="cancel-application-btn"
            phx-click={if(@values[:submitted], do: "new-application", else: "cancel-application")}
            class="rounded-lg border border-zinc-300 px-6 py-3 text-sm font-semibold text-zinc-700 shadow-sm hover:bg-zinc-100 active:bg-zinc-200 transition-colors"
          >
            {if @values[:submitted], do: "New Application", else: "Cancel Application"}
          </button>
        </div>
        <div :if={@graph_mermaid} class="mt-4 w-full rounded-lg border border-zinc-300 overflow-hidden">
          <div class="flex border-b border-zinc-300 bg-zinc-50">
            <button
              type="button"
              phx-click="mermaid-tab"
              phx-value-tab="visual"
              class={[
                "px-4 py-2 text-xs font-semibold transition-colors",
                if(@mermaid_tab == "visual",
                  do: "bg-white text-zinc-900 border-b-2 border-zinc-900",
                  else: "text-zinc-500 hover:text-zinc-700"
                )
              ]}
            >
              Visual
            </button>
            <button
              type="button"
              phx-click="mermaid-tab"
              phx-value-tab="text"
              class={[
                "px-4 py-2 text-xs font-semibold transition-colors",
                if(@mermaid_tab == "text",
                  do: "bg-white text-zinc-900 border-b-2 border-zinc-900",
                  else: "text-zinc-500 hover:text-zinc-700"
                )
              ]}
            >
              Text
            </button>
          </div>
          <div
            :if={@mermaid_tab == "visual"}
            id={"mermaid-#{:erlang.phash2(@graph_mermaid)}"}
            phx-hook=".Mermaid"
            phx-update="ignore"
            data-graph={@graph_mermaid}
            class="bg-white p-4 overflow-x-auto"
          >
          </div>
          <pre
            :if={@mermaid_tab == "text"}
            id="mermaid-graph"
            class="bg-zinc-100 p-4 text-xs text-zinc-700 overflow-x-auto"
          ><span class="text-zinc-400">iex&gt; Journey.Tools.generate_mermaid_execution("{@execution_id}") |&gt; IO.puts()
        </span>{@graph_mermaid}</pre>
        </div>
        <p :if={@values[:submitted]} class="text-sm font-semibold text-green-700">
          Application submitted
        </p>
        <div :if={@values[:submitted]} class="w-full rounded-lg border border-zinc-300 px-4 py-3">
          <span class="text-sm text-zinc-500">resume_valid: </span>
          <%= case @computation_states[:resume_valid] do %>
            <% :success -> %>
              <span class="text-sm font-medium text-zinc-900">
                ✅ :success | {inspect(@values[:resume_valid])}
              </span>
            <% :failed -> %>
              <span class="text-sm text-zinc-500">❌ :failed</span>
              <button
                type="button"
                phx-click="retry-computation"
                phx-value-node="resume_valid"
                class="ml-2 rounded-md border border-zinc-300 px-2 py-1 text-xs font-semibold text-zinc-700 hover:bg-zinc-100 active:bg-zinc-200 transition-colors"
              >
                try again
              </button>
            <% state -> %>
              <span class="text-sm text-zinc-500">
                {Journey.Tools.computation_state_to_text(state)}
              </span>
          <% end %>
        </div>
        <div :if={@values[:submitted]} class="w-full rounded-lg border border-zinc-300 px-4 py-3">
          <span class="text-sm text-zinc-500">match_score: </span>
          <%= case @computation_states[:match_score] do %>
            <% :success -> %>
              <span class="text-sm font-medium text-zinc-900">
                ✅ :success | {@values[:match_score]}
              </span>
            <% :failed -> %>
              <span class="text-sm text-zinc-500">❌ :failed</span>
              <button
                type="button"
                phx-click="retry-computation"
                phx-value-node="match_score"
                class="ml-2 rounded-md border border-zinc-300 px-2 py-1 text-xs font-semibold text-zinc-700 hover:bg-zinc-100 active:bg-zinc-200 transition-colors"
              >
                try again
              </button>
            <% state -> %>
              <span class="text-sm text-zinc-500">
                {Journey.Tools.computation_state_to_text(state)}
              </span>
          <% end %>
        </div>
        <div :if={@values[:submitted]} class="w-full rounded-lg border border-zinc-300 px-4 py-3">
          <span class="text-sm text-zinc-500">resume_summary: </span>
          <%= case @computation_states[:resume_summary] do %>
            <% :success -> %>
              <span class="text-sm font-medium text-zinc-900">
                ✅ :success | &lt;computed&gt;
              </span>
            <% :failed -> %>
              <span class="text-sm text-zinc-500">❌ :failed</span>
              <button
                type="button"
                phx-click="retry-computation"
                phx-value-node="resume_summary"
                class="ml-2 rounded-md border border-zinc-300 px-2 py-1 text-xs font-semibold text-zinc-700 hover:bg-zinc-100 active:bg-zinc-200 transition-colors"
              >
                try again
              </button>
            <% state -> %>
              <span class="text-sm text-zinc-500">
                {Journey.Tools.computation_state_to_text(state)}
              </span>
          <% end %>
        </div>
        <div :if={@values[:resume_summary]} class="w-full rounded-lg border border-zinc-300 px-4 py-3">
          <span class="text-sm text-zinc-500">Next steps: </span>
          <span class="text-sm font-medium text-zinc-900">{@values[:decision]}</span>
        </div>
        <pre
          :if={@introspect}
          id="introspect"
          class="mt-8 w-full rounded-lg border border-zinc-300 bg-zinc-100 p-4 text-xs text-zinc-700 overflow-x-auto"
        ><span class="text-zinc-400">iex&gt; Journey.Tools.introspect("{@execution_id}")
    </span>{@introspect}</pre>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".Mermaid">
          import mermaid from "mermaid"

          mermaid.initialize({ startOnLoad: false, theme: "neutral" })

          export default {
            async mounted() {
              const graph = this.el.dataset.graph
              const { svg } = await mermaid.render("mermaid-svg-" + this.el.id, graph)
              this.el.innerHTML = svg
            }
          }
        </script>
      </div>
    </Layouts.app>
    """
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event("mermaid-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :mermaid_tab, tab)}
  end

  def handle_event("validate-upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("new-application", _params, socket) do
    Logger.info("new-application")
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("cancel-application", _params, socket) do
    Journey.archive(socket.assigns.execution_id)
    Logger.info("cancel-application: #{socket.assigns.execution_id}")
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("submit-application", _params, socket) do
    Journey.set(socket.assigns.execution_id, :submitted, System.os_time(:second))
    Journey.set(socket.assigns.execution_id, :decision, "Employer review")
    Logger.info("submit-application")
    {:noreply, refresh_execution_state(socket)}
  end

  def handle_event("clear-resume", _params, socket) do
    execution_id = socket.assigns.execution_id
    Journey.unset(execution_id, :resume)
    Logger.info("clear-resume")

    socket = refresh_execution_state(socket)

    {:noreply, socket}
  end

  def handle_event("retry-computation", %{"node" => node_name}, socket) do
    node_atom = String.to_existing_atom(node_name)
    Journey.Tools.retry_computation(socket.assigns.execution_id, node_atom)
    Logger.info("retry-computation: #{socket.assigns.execution_id}, #{node_atom}")

    socket =
      socket
      |> refresh_execution_state()
      |> update(:computation_states, &Map.put(&1, node_atom, :computing))

    {:noreply, socket}
  end

  def handle_event("set-resume-text", %{"value" => text}, socket) do
    text = sanitize_text(text)

    if text != "" do
      socket = ensure_candidate_execution(socket)
      Journey.set(socket.assigns.execution_id, :resume, text)
      Logger.info("set-resume-text: #{String.length(text)} chars")

      {:noreply, refresh_execution_state(socket)}
    else
      {:noreply, socket}
    end
  end

  defp handle_progress(:resume, entry, socket) do
    if entry.done? do
      [text] =
        consume_uploaded_entries(socket, :resume, fn %{path: path}, _entry ->
          {:ok, sanitize_text(File.read!(path))}
        end)

      socket = ensure_candidate_execution(socket)
      Journey.set(socket.assigns.execution_id, :resume, text)
      Logger.info("upload-resume: #{entry.client_name}, #{String.length(text)} chars")

      {:noreply, refresh_execution_state(socket)}
    else
      {:noreply, socket}
    end
  end

  defp ensure_candidate_execution(socket) do
    if socket.assigns.execution_id do
      socket
    else
      execution = Journey.start_execution(ResumeScreener.Candidate.Graph.new())

      if socket.assigns.employer_values[:job_description] do
        Journey.set(execution.id, :job_description, socket.assigns.employer_values[:job_description])
      end

      :ok = Phoenix.PubSub.subscribe(ResumeScreener.PubSub, "candidate:#{execution.id}")

      Logger.info("Created candidate execution #{execution.id}")

      socket
      |> assign(:execution_id, execution.id)
      |> push_patch(to: ~p"/candidate/#{execution.id}")
    end
  end

  def handle_info({:refresh, :resume_valid, {:ok, true}}, socket) do
    Logger.info("Received refresh for step: resume_valid (true)")

    socket =
      socket
      |> refresh_execution_state()
      |> update(:computation_states, fn states ->
        states
        |> Map.put(:resume_summary, :computing)
        |> Map.put(:match_score, :computing)
      end)

    {:noreply, socket}
  end

  def handle_info({:refresh, step_name, _value}, socket) do
    Logger.info("Received refresh for step: #{step_name}")
    {:noreply, refresh_execution_state(socket)}
  end

  defp refresh_execution_state(socket) do
    execution = Journey.load(socket.assigns.execution_id)

    if execution do
      eid = socket.assigns.execution_id

      socket
      |> assign(:values, Journey.values(execution))
      |> assign(:computation_states, computation_states(eid))
      |> assign(:introspect, Journey.Tools.introspect(eid))
      |> assign(:graph_mermaid, generate_mermaid_execution(eid))
    else
      socket
    end
  end

  defp computation_states(execution_id) do
    for node <- [:resume_valid, :match_score, :resume_summary],
        into: %{},
        do: {node, Journey.Tools.computation_state(execution_id, node)}
  end

  defp generate_mermaid_execution(execution_id) do
    Journey.Tools.generate_mermaid_execution(execution_id, include_legend: false)
  end

  defp sanitize_text(text) do
    text
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.chunk(:valid)
    |> Enum.filter(&String.valid?/1)
    |> Enum.join()
    |> String.trim()
  end

  defp upload_error_to_string(:too_large), do: "File is too large (max 10 MB)"
  defp upload_error_to_string(:not_accepted), do: "Only .txt and .md files are accepted"
  defp upload_error_to_string(:too_many_files), do: "Only one file allowed"
  defp upload_error_to_string(err), do: "Error: #{inspect(err)}"
end
