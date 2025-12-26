defmodule ShareWeb.Components do
  use Phoenix.Component

  def icon(assigns) do
    ~H"""
    <div class="w-[66px] h-[66px] rounded-full bg-[#0f172a] flex items-center justify-center p-5">
      <svg
        width="26"
        height="32"
        viewBox="0 0 26 32"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M10 1V13L14.5 8.5L19 13V1M1 27.25V4.75C1 3.75544 1.39509 2.80161 2.09835 2.09835C2.80161 1.39509 3.75544 1 4.75 1H23.5C23.8978 1 24.2794 1.15804 24.5607 1.43934C24.842 1.72064 25 2.10218 25 2.5V29.5C25 29.8978 24.842 30.2794 24.5607 30.5607C24.2794 30.842 23.8978 31 23.5 31H4.75C3.75544 31 2.80161 30.6049 2.09835 29.9017C1.39509 29.1984 1 28.2446 1 27.25ZM1 27.25C1 26.2554 1.39509 25.3016 2.09835 24.5983C2.80161 23.8951 3.75544 23.5 4.75 23.5H25"
          stroke="white"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </div>
    """
  end
end
