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
        email: "user#{System.unique_integer([:positive])}@example.com",
        full_name: "some full_name",
        password: "password1234"
      })
      |> Share.Accounts.create_user()

    user
  end
end
