defmodule Share.KnowledgeFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Share.Knowledge` context.
  """

  @doc """
  Generate a resource.
  """
  def resource_fixture(attrs \\ %{}) do
    {:ok, resource} =
      attrs
      |> Enum.into(%{
        description: "some description",
        title: "some title",
        type: "some type",
        url: "some url"
      })
      |> Share.Knowledge.create_resource()

    resource
  end
end
