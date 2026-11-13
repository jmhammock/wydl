defmodule WydlmWeb.Layouts do
  @moduledoc """
  Layouts for the whole application.
  """
  use WydlmWeb, :html

  embed_templates "layouts/*"

  def posthog_key do
    get_in(Application.get_env(:wydlm, :posthog), [:key]) || ""
  end

  def posthog_host do
    get_in(Application.get_env(:wydlm, :posthog), [:host]) || ""
  end

  @doc """
  Renders the app shell: a slim header, a centered content column, and the
  analytics hook element.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="mx-auto w-full max-w-[34rem] px-4 pt-[calc(1rem+env(safe-area-inset-top))] pb-2">
      <p class="m-0 text-xs font-semibold uppercase tracking-wider text-neutral">
        Driver Test
      </p>
    </header>

    <main class="mx-auto w-full max-w-[34rem] px-4 pb-[calc(2rem+env(safe-area-inset-bottom))]">
      {render_slot(@inner_block)}
    </main>

    <div id="posthog" phx-hook="PostHog" class="hidden"></div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
