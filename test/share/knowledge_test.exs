defmodule Share.KnowledgeTest do
  use Share.DataCase

  alias Share.Knowledge

  describe "resources" do
    alias Share.Knowledge.Resource

    import Share.KnowledgeFixtures

    @invalid_attrs %{type: nil, description: nil, title: nil, url: nil}

    test "list_resources/0 returns all resources" do
      resource = resource_fixture()
      assert Knowledge.list_resources() == [resource]
    end

    test "get_resource!/1 returns the resource with given id" do
      resource = resource_fixture()
      assert Knowledge.get_resource!(resource.id) == resource
    end

    test "create_resource/1 with valid data creates a resource" do
      valid_attrs = %{type: "some type", description: "some description", title: "some title", url: "some url"}

      assert {:ok, %Resource{} = resource} = Knowledge.create_resource(valid_attrs)
      assert resource.type == "some type"
      assert resource.description == "some description"
      assert resource.title == "some title"
      assert resource.url == "some url"
    end

    test "create_resource/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Knowledge.create_resource(@invalid_attrs)
    end

    test "update_resource/2 with valid data updates the resource" do
      resource = resource_fixture()
      update_attrs = %{type: "some updated type", description: "some updated description", title: "some updated title", url: "some updated url"}

      assert {:ok, %Resource{} = resource} = Knowledge.update_resource(resource, update_attrs)
      assert resource.type == "some updated type"
      assert resource.description == "some updated description"
      assert resource.title == "some updated title"
      assert resource.url == "some updated url"
    end

    test "update_resource/2 with invalid data returns error changeset" do
      resource = resource_fixture()
      assert {:error, %Ecto.Changeset{}} = Knowledge.update_resource(resource, @invalid_attrs)
      assert resource == Knowledge.get_resource!(resource.id)
    end

    test "delete_resource/1 deletes the resource" do
      resource = resource_fixture()
      assert {:ok, %Resource{}} = Knowledge.delete_resource(resource)
      assert_raise Ecto.NoResultsError, fn -> Knowledge.get_resource!(resource.id) end
    end

    test "change_resource/1 returns a resource changeset" do
      resource = resource_fixture()
      assert %Ecto.Changeset{} = Knowledge.change_resource(resource)
    end
  end
end
