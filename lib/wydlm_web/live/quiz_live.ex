defmodule WydlmWeb.QuizLive do
  use WydlmWeb, :live_view

  alias Wydlm.Quiz
  alias Wydlm.Quiz.Session

  @impl true
  def mount(_params, session, socket) do
    bank = Quiz.bank!()
    visitor_id = session["visitor_id"]

    {:ok,
     socket
     |> assign(
       page_title: "Wyoming Driver License Practice Test",
       phase: :start,
       bank: bank,
       total: Quiz.question_count(bank),
       mode: :practice,
       practice_length: Session.default_practice_length(),
       questions: [],
       answers: [],
       chosen: nil,
       exit_armed: false,
       attempt: nil,
       visitor_id: visitor_id,
       recent: Quiz.recent_attempts(visitor_id)
     )}
  end

  @impl true
  def handle_event("set-mode", %{"mode" => mode}, socket) do
    case mode do
      "practice" -> {:noreply, assign(socket, :mode, :practice)}
      "test" -> {:noreply, assign(socket, :mode, :test)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("set-length", %{"length" => length}, socket) do
    case Integer.parse(length) do
      {n, ""} -> {:noreply, assign(socket, :practice_length, n)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("start", _params, socket) do
    length = Session.session_length(socket.assigns.mode, socket.assigns.practice_length)

    {:ok, %{attempt: attempt, questions: questions}} =
      Quiz.start_attempt(
        socket.assigns.bank,
        socket.assigns.visitor_id,
        socket.assigns.mode,
        length
      )

    socket =
      socket
      |> assign(
        phase: :question,
        attempt: attempt,
        questions: questions,
        answers: [],
        chosen: nil,
        exit_armed: false
      )
      |> track("quiz_started", %{
        bank_id: socket.assigns.bank.slug,
        mode: mode_string(socket.assigns.mode),
        question_count: length
      })

    {:noreply, socket}
  end

  def handle_event("choose", %{"option-id" => id}, socket) do
    with nil <- socket.assigns.chosen,
         {option_id, ""} <- Integer.parse(id),
         %{question: question} <- current_question(socket.assigns),
         true <- Enum.any?(question.answer_options, &(&1.id == option_id)) do
      {:noreply, assign(socket, :chosen, option_id)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("next", _params, socket) do
    case {socket.assigns.chosen, current_question(socket.assigns)} do
      {chosen_id, attempt_question} when is_integer(chosen_id) ->
        case Enum.find(attempt_question.question.answer_options, &(&1.id == chosen_id)) do
          nil ->
            {:noreply, socket}

          chosen_option ->
            {:ok, answer} = Quiz.record_answer(attempt_question, chosen_option)
            answers = socket.assigns.answers ++ [answer]

            socket =
              socket
              |> assign(answers: answers, chosen: nil, exit_armed: false)
              |> track(
                "quiz_answer_submitted",
                answer_properties(socket.assigns, answers, attempt_question, answer)
              )

            mode = socket.assigns.mode
            questions = socket.assigns.questions

            if Session.finished?(mode, questions, answers) do
              status = if Session.failed?(mode, answers), do: :failed, else: :completed
              {:ok, _attempt} = Quiz.finish_attempt(socket.assigns.attempt, status)

              socket =
                socket
                |> assign(phase: :results)
                |> track("quiz_completed", completion_properties(socket.assigns))

              {:noreply, socket}
            else
              {:noreply, socket}
            end
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("arm-exit", _params, socket) do
    {:noreply, assign(socket, :exit_armed, true)}
  end

  def handle_event("cancel-exit", _params, socket) do
    {:noreply, assign(socket, :exit_armed, false)}
  end

  def handle_event("exit", _params, socket) do
    if socket.assigns.phase == :question do
      _ = Quiz.abandon_attempt(socket.assigns.attempt)

      socket =
        track(socket, "quiz_abandoned", %{
          bank_id: socket.assigns.bank.slug,
          mode: mode_string(socket.assigns.mode),
          questions_answered: length(socket.assigns.answers),
          question_count: length(socket.assigns.questions)
        })

      {:noreply, back_to_start(socket)}
    else
      {:noreply, back_to_start(socket)}
    end
  end

  def handle_event("restart", _params, socket) do
    {:noreply, back_to_start(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div :if={@total == 0}>
        <div class="card card-border bg-base-100">
          <div class="card-body">
            <h1 class="card-title">{@bank.title}</h1>
            <p class="text-neutral">No questions have been loaded yet.</p>
          </div>
        </div>
      </div>

      <div :if={@total > 0}>
        <%= case @phase do %>
          <% :start -> %>
            <.start_screen
              total={@total}
              bank={@bank}
              mode={@mode}
              practice_length={@practice_length}
              recent={@recent}
            />
          <% :question -> %>
            <.question_screen
              question={current_question(assigns)}
              answers_count={length(@answers)}
              total={length(@questions)}
              chosen={@chosen}
              exit_armed={@exit_armed}
              mode={@mode}
            />
          <% :results -> %>
            <.results_screen mode={@mode} answers={@answers} questions={@questions} bank={@bank} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  ## Start screen

  defp start_screen(assigns) do
    ~H"""
    <div>
      <div class="card card-border bg-base-100 mb-4">
        <div class="card-body">
          <h1 class="card-title">{@bank.title}</h1>
          <p class="text-neutral">{@bank.subtitle}</p>

          <fieldset class="mb-5">
            <legend class="mb-2 text-sm text-neutral">Mode</legend>
            <div class="flex flex-wrap gap-2">
              <button
                type="button"
                class={length_button_class(@mode == :practice)}
                phx-click="set-mode"
                phx-value-mode="practice"
              >
                Practice
              </button>
              <button
                type="button"
                class={length_button_class(@mode == :test)}
                phx-click="set-mode"
                phx-value-mode="test"
              >
                Test
              </button>
            </div>
          </fieldset>

          <fieldset :if={@mode == :practice} class="mb-5">
            <legend class="mb-2 text-sm text-neutral">Questions per session</legend>
            <div class="flex flex-wrap gap-2">
              <button
                :for={length <- Session.length_options(@total)}
                type="button"
                class={length_button_class(@practice_length == length)}
                phx-click="set-length"
                phx-value-length={length}
              >
                {length_label(@total, length)}
              </button>
            </div>
          </fieldset>

          <p
            :if={@mode == :test}
            class="mb-4 rounded-lg border border-base-300 bg-base-200 px-3.5 py-3 text-sm text-neutral"
          >
            {Session.test_question_count()} questions. You need {Session.test_pass_mark()} correct to pass, and the test ends as soon as {Session.allowed_misses() +
              1} answers are wrong.
          </p>

          <button type="button" class="btn btn-primary btn-block" phx-click="start">
            {if @mode == :practice, do: "Start", else: "Begin test"}
          </button>
        </div>
      </div>

      <section :if={@recent != []} class="mb-4">
        <h2 class="mb-3 text-lg font-semibold">Recent attempts</h2>
        <div class="space-y-2">
          <div :for={attempt <- @recent} class="card card-border bg-base-100">
            <div class="card-body py-3">
              <div class="flex items-center justify-between gap-4">
                <span class="text-sm font-medium capitalize">{attempt.mode}</span>
                <span class={[
                  "text-sm font-semibold",
                  if(attempt.status == "failed", do: "text-error", else: "text-success")
                ]}>
                  {attempt.correct_count} / {attempt.question_count}
                </span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <.footer_screen />
    </div>
    """
  end

  ## Question screen

  defp question_screen(assigns) do
    ~H"""
    <div>
      <%= if @exit_armed do %>
        <div class="mb-3 rounded-lg border border-error bg-[var(--wrong-bg)] px-3.5 py-3">
          <p class="mb-2.5 text-sm text-error">Your progress will be lost.</p>
          <div class="flex flex-wrap gap-2">
            <button type="button" class="btn btn-soft btn-sm" phx-click="cancel-exit">Keep going</button>
            <button type="button" class="btn btn-error btn-sm" phx-click="exit">
              Yes, leave the {mode_noun(@mode)}
            </button>
          </div>
        </div>
      <% else %>
        <button
          type="button"
          class="mb-3 text-sm text-neutral underline decoration-neutral"
          phx-click="arm-exit"
        >
          Leave the {mode_noun(@mode)}
        </button>
      <% end %>

      <div class="mb-3">
        <p class="mb-1 text-sm text-neutral">
          Question {@answers_count + 1} of {@total}
        </p>
        <progress class="progress progress-primary w-full" value={@answers_count + 1} max={@total}></progress>
      </div>

      <div class="card card-border bg-base-100">
        <div class="card-body">
          <p class="mb-2 text-xs font-semibold uppercase tracking-wider text-neutral">
            {@question.question.category}
          </p>
          <h1 class="mb-4 text-xl leading-snug">{@question.question.prompt}</h1>

          <div class="grid gap-2">
            <.option_button
              :for={option <- @question.question.answer_options}
              option={option}
              chosen={@chosen}
              letter={letter(option.position)}
            />
          </div>

          <.feedback
            :if={@chosen}
            question={@question.question}
            chosen={@chosen}
            last={@answers_count + 1 == @total}
          />
        </div>
      </div>
    </div>
    """
  end

  defp option_button(assigns) do
    assigns = assign(assigns, :revealed, assigns.chosen != nil)

    ~H"""
    <button
      type="button"
      disabled={@revealed}
      class={[
        "flex w-full items-start gap-3 rounded-lg border border-base-300 bg-base-100 px-3 py-3 text-left transition-colors",
        if(@revealed, do: "cursor-default", else: "hover:border-primary"),
        option_state_class(@option, @chosen, @revealed)
      ]}
      phx-click="choose"
      phx-value-option-id={@option.id}
    >
      <span class="flex-none font-bold text-neutral" aria-hidden="true">{@letter}</span>
      <span>{@option.text}</span>
    </button>
    """
  end

  defp feedback(assigns) do
    chosen_option = Enum.find(assigns.question.answer_options, &(&1.id == assigns.chosen))
    assigns = assign(assigns, :correct, chosen_option.correct)

    ~H"""
    <div class="mt-5 border-t border-base-300 pt-4">
      <p class={["mb-2 font-bold", if(@correct, do: "text-success", else: "text-error")]}>
        {if @correct, do: "Correct.", else: "Not quite."}
      </p>
      <p :if={!@correct} class="mb-2">
        <strong>Correct answer: </strong>
        {correct_answer(@question)}
      </p>
      <p class="mb-4 text-[0.95rem] text-neutral">{@question.explanation}</p>
      <button type="button" class="btn btn-primary btn-block" phx-click="next">
        {if @last, do: "See results", else: "Next"}
      </button>
    </div>
    """
  end

  ## Results screen

  defp results_screen(assigns) do
    ~H"""
    <div>
      <div class="card card-border bg-base-100 mb-4">
        <div class="card-body">
          <%= if @mode == :practice do %>
            <h1 class="card-title">Session complete</h1>
            <p class="text-5xl font-bold leading-none">{score_percent(@answers)}%</p>
            <p class="text-neutral">
              {Session.correct_count(@answers)} of {length(@answers)} correct
            </p>
            <div class="mt-2">
              <button type="button" class="btn btn-primary btn-block" phx-click="restart">
                Start a new session
              </button>
            </div>
          <% else %>
            <h1 class={[
              "card-title",
              if(Session.failed?(:test, @answers), do: "text-error", else: "text-success")
            ]}>
              {if Session.failed?(:test, @answers), do: "Not passed", else: "Passed"}
            </h1>
            <p class="text-5xl font-bold leading-none">
              {Session.correct_count(@answers)} / {Session.test_question_count()}
            </p>
            <p class="text-neutral">{test_result_text(@answers)}</p>
            <div class="mt-2">
              <button type="button" class="btn btn-primary btn-block" phx-click="restart">
                Take the test again
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <.review_screen mode={@mode} answers={@answers} questions={@questions} />
      <.footer_screen />
    </div>
    """
  end

  defp review_screen(assigns) do
    missed =
      assigns.answers
      |> Enum.with_index()
      |> Enum.filter(fn {answer, _index} -> not answer.correct end)

    assigns = assign(assigns, :missed, missed)

    ~H"""
    <%= if @missed == [] do %>
      <p class="text-center text-neutral">
        {if @mode == :test,
          do: "Nothing missed.",
          else: "Nothing missed. Come back later and try a longer session."}
      </p>
    <% else %>
      <section>
        <h2 class="mb-3 text-lg font-semibold">
          Review — {length(@missed)} missed
        </h2>
        <div class="space-y-2">
          <.missed_item
            :for={{answer, index} <- @missed}
            answer={answer}
            question={Enum.at(@questions, index)}
          />
        </div>
      </section>
    <% end %>
    """
  end

  defp missed_item(assigns) do
    ~H"""
    <details class="card card-border bg-base-100">
      <summary class="card-body py-3 font-semibold cursor-pointer">
        {@question.question.prompt}
      </summary>
      <div class="card-body pt-0">
        <p class="text-xs font-semibold uppercase tracking-wider text-neutral">
          {@question.question.category}
        </p>
        <p>
          <strong>Correct answer: </strong>
          {correct_answer(@question.question)}
        </p>
        <p>You chose: {chosen_answer(@question.question, @answer.chosen_option_id)}</p>
        <p class="text-[0.95rem] text-neutral">{@question.question.explanation}</p>
      </div>
    </details>
    """
  end

  defp footer_screen(assigns) do
    ~H"""
    <footer class="mt-8 border-t border-base-300 pt-4 text-center">
      <p class="mb-3 text-xs text-neutral">
        Study aid — not affiliated with any DMV. Questions drawn from official state driver manuals.
      </p>
      <p class="mb-3 text-sm text-neutral">
        This tool is free to use. If it helped you, consider buying me a coffee.
      </p>
      <div class="flex min-h-14 items-center justify-center">
        <a
          class="coffee-btn"
          href="https://www.buymeacoffee.com/jhammock"
          target="_blank"
          rel="noopener"
        >
          ☕ Buy me a coffee
        </a>
      </div>
    </footer>
    """
  end

  ## Helpers

  defp current_question(assigns) do
    Enum.at(assigns.questions, length(assigns.answers))
  end

  defp option_state_class(option, chosen, revealed) do
    cond do
      not revealed -> ""
      option.correct -> "option-right"
      option.id == chosen -> "option-wrong"
      true -> "opacity-50"
    end
  end

  defp correct_answer(question) do
    case Enum.find(question.answer_options, & &1.correct) do
      nil -> ""
      option -> option.text
    end
  end

  defp chosen_answer(question, chosen_option_id) do
    case Enum.find(question.answer_options, &(&1.id == chosen_option_id)) do
      nil -> ""
      option -> option.text
    end
  end

  defp length_label(total, length) do
    if length == total, do: "All", else: Integer.to_string(length)
  end

  defp length_button_class(selected) do
    [
      "flex-1 basis-[4.5rem] rounded-lg border px-2 py-2 text-sm transition-colors",
      if(selected,
        do: "border-primary bg-primary font-semibold text-primary-content",
        else: "border-base-300 bg-base-100 text-base-content"
      )
    ]
  end

  defp letter(position), do: Enum.at(~w(A B C D E F), position, "?")

  defp mode_noun(:practice), do: "practice session"
  defp mode_noun(:test), do: "test"

  defp mode_string(:practice), do: "practice"
  defp mode_string(:test), do: "test"

  defp score_percent(answers) do
    total = length(answers)

    if total == 0 do
      0
    else
      round(Session.correct_count(answers) / total * 100)
    end
  end

  defp test_result_text(answers) do
    correct = Session.correct_count(answers)

    if Session.failed?(:test, answers) do
      "You needed #{Session.test_pass_mark()} of #{Session.test_question_count()} correct. After #{Session.allowed_misses() + 1} wrong answers that was out of reach, so the test stopped at question #{length(answers)}."
    else
      "#{correct} of #{Session.test_question_count()} correct. You needed #{Session.test_pass_mark()}."
    end
  end

  defp back_to_start(socket) do
    assign(socket,
      phase: :start,
      questions: [],
      answers: [],
      chosen: nil,
      exit_armed: false,
      attempt: nil,
      recent: Quiz.recent_attempts(socket.assigns.visitor_id)
    )
  end

  defp track(socket, event, properties) do
    push_event(socket, "track", %{event: event, properties: properties})
  end

  defp answer_properties(assigns, answers, attempt_question, answer) do
    %{
      bank_id: assigns.bank.slug,
      mode: mode_string(assigns.mode),
      question_category: attempt_question.question.category,
      question_number: length(answers),
      is_correct: answer.correct
    }
  end

  defp completion_properties(assigns) do
    answered = length(assigns.answers)
    correct = Session.correct_count(assigns.answers)

    %{
      bank_id: assigns.bank.slug,
      mode: mode_string(assigns.mode),
      questions_answered: answered,
      correct_answers: correct,
      score_percent: if(answered == 0, do: 0, else: round(correct / answered * 100)),
      outcome: outcome(assigns.mode, assigns.answers)
    }
  end

  defp outcome(:practice, _answers), do: "completed"

  defp outcome(:test, answers),
    do: if(Session.failed?(:test, answers), do: "failed", else: "passed")
end
