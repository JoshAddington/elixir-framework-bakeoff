defmodule ShareWeb.HubBanner do
  use Phoenix.Component
  use Gettext, backend: ShareWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: ShareWeb.Endpoint,
    router: ShareWeb.Router,
    statics: ShareWeb.static_paths()

  alias Phoenix.LiveView.JS
  import ShareWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders a success banner for the Knowledge Hub.
  """
  attr :flash, :map, required: true
  attr :current_user, :any, default: nil

  def hub_banner(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, :info)}
      id="hub-banner"
      phx-mounted={JS.show(to: "#hub-banner")}
      class="mb-8 w-full flex items-center justify-between gap-4 p-6 bg-white rounded-[4px] border border-black/5 shadow-[0px_1px_3px_rgba(0,0,0,0.02),0px_8px_24px_-4px_rgba(15,23,42,0.04)]"
    >
      <div class="flex items-center gap-5">
        <div class="w-11 h-11 rounded-full bg-emerald-500 flex items-center justify-center shrink-0 shadow-lg shadow-emerald-500/20">
          <.icon name="hero-check" class="w-6 h-6 text-white stroke-[3]" />
        </div>
        <p class="text-slate-900 text-lg font-bold tracking-tight">
          {msg}
        </p>
      </div>

      <div class="flex items-center gap-4">
        <.link
          :if={msg == "New resource successfully added!" && @current_user}
          patch={~p"/?user_id=#{@current_user.id}"}
          class="shrink-0 bg-slate-900 text-white px-6 py-2.5 rounded-lg text-sm font-bold shadow-lg shadow-slate-900/10 hover:bg-slate-800 hover:-translate-y-0.5 transition-all"
        >
          View Your Resources
        </.link>

        <button
          type="button"
          phx-click={
            JS.push("lv:clear-flash", value: %{key: :info})
            |> JS.hide(to: "#hub-banner")
          }
          class="p-2 text-slate-400 hover:text-slate-900 transition-colors"
          aria-label={gettext("close")}
        >
          <.icon name="hero-x-mark" class="w-5 h-5" />
        </button>
      </div>
    </div>
    """
  end
end
