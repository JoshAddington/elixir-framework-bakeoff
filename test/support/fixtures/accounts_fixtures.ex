defmodule Share.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Share.Accounts` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "some email",
        full_name: "some full_name",
        password_hash: "some password_hash"
      })
      |> Share.Accounts.create_user()

    user
  end
end
