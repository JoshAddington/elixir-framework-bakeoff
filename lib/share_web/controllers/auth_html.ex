defmodule ShareWeb.AuthHTML do
  @moduledoc """
  This module contains pages rendered by AuthController.
  """
  use ShareWeb, :html

  embed_templates "auth_html/*"
end
