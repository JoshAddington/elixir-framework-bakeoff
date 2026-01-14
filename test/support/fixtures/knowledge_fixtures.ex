defmodule Share.KnowledgeFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Share.Knowledge` context.
  """

  import Share.AccountsFixtures

  @doc """
  Generate a resource.
  """
  def resource_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()

    {:ok, resource} =
      attrs
      |> Enum.into(%{
        description: "some description",
        title: "some title",
        type: "article",
        url: "https://example.com",
        snippet: nil,
        user_id: user.id
      })
      |> (fn attrs ->
            if attrs[:type] == "snippet",
              do:
                Map.merge(attrs, %{snippet: attrs[:snippet] || "main = putStrLn \"hi\"", url: nil}),
              else: attrs
          end).()
      |> Share.Knowledge.create_resource()

    resource |> Share.Repo.preload([:user, :tags])
  end

  @doc """
  Generate a tag.
  """
  def tag_fixture(attrs \\ %{}) do
    {:ok, tag} =
      attrs
      |> Enum.into(%{
        name: "tag#{System.unique_integer([:positive])}"
      })
      |> Share.Knowledge.create_tag()

    tag
  end
end
