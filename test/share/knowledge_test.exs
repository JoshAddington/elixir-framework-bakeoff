defmodule Share.KnowledgeTest do
  use Share.DataCase

  alias Share.Knowledge
  alias Share.Knowledge.Resource
  alias Share.Knowledge.Tag

  import Share.AccountsFixtures
  import Share.KnowledgeFixtures

  describe "resources" do
    @invalid_attrs %{type: nil, description: nil, title: nil, url: nil}

    test "list_resources/0 returns all resources" do
      resource = resource_fixture()
      assert Enum.map(Knowledge.list_resources(), & &1.id) == [resource.id]
    end

    test "get_resource!/1 returns the resource" do
      resource = resource_fixture()
      assert Knowledge.get_resource!(resource.id).id == resource.id
    end

    test "create_resource/1 creates a resource" do
      user = user_fixture()

      attrs = %{
        type: "article",
        title: "T",
        description: "D",
        url: "http://x.com",
        user_id: user.id
      }

      assert {:ok, %Resource{} = r} = Knowledge.create_resource(attrs)
      assert r.title == "T"
    end

    test "create_resource/1 with invalid data" do
      assert {:error, %Ecto.Changeset{}} = Knowledge.create_resource(@invalid_attrs)
    end

    test "list_resources/1 filters by type" do
      r1 = resource_fixture(%{type: "article"})
      _r2 = resource_fixture(%{type: "snippet"})
      assert Enum.map(Knowledge.list_resources(%{"types" => ["article"]}), & &1.id) == [r1.id]
    end

    test "list_resources/1 filters by tag" do
      tag = tag_fixture(name: "elixir")
      r1 = resource_fixture()
      Knowledge.update_resource(r1, %{}, [tag])
      _r2 = resource_fixture()
      assert Enum.map(Knowledge.list_resources(%{"tag" => "elixir"}), & &1.id) == [r1.id]
    end

    test "list_resources/1 filters by query" do
      r1 = resource_fixture(%{title: "Elixir"})
      _r2 = resource_fixture(%{title: "Java"})
      assert Enum.map(Knowledge.list_resources(%{"q" => "elixir"}), & &1.id) == [r1.id]
    end

    test "list_resources/1 filters by user" do
      user = user_fixture()
      r1 = resource_fixture(user: user)
      _r2 = resource_fixture()
      assert Enum.map(Knowledge.list_resources(%{"user_id" => user.id}), & &1.id) == [r1.id]
    end

    test "update_resource/2 updates resource" do
      resource = resource_fixture()
      assert {:ok, %Resource{} = updated} = Knowledge.update_resource(resource, %{title: "New"})
      assert updated.title == "New"
    end

    test "update_resource/2 with invalid data" do
      resource = resource_fixture()
      assert {:error, %Ecto.Changeset{}} = Knowledge.update_resource(resource, %{title: nil})
    end

    test "delete_resource/1 deletes resource" do
      resource = resource_fixture()
      assert {:ok, _} = Knowledge.delete_resource(resource)
      assert_raise Ecto.NoResultsError, fn -> Knowledge.get_resource!(resource.id) end
    end

    test "change_resource/1" do
      resource = resource_fixture()
      assert %Ecto.Changeset{} = Knowledge.change_resource(resource)
    end
  end

  describe "tags" do
    test "list_tags/0 returns all tags" do
      tag = tag_fixture()
      assert Enum.map(Knowledge.list_tags(), & &1.id) == [tag.id]
    end

    test "create_tag/1" do
      assert {:ok, %Tag{} = tag} = Knowledge.create_tag(%{name: "newtag"})
      assert tag.name == "newtag"
    end

    test "get_tags_by_names/1" do
      t1 = tag_fixture(name: "A")
      _t2 = tag_fixture(name: "B")
      tags = Knowledge.get_tags_by_names(["A"])
      assert Enum.map(tags, & &1.id) == [t1.id]
    end
  end
end
