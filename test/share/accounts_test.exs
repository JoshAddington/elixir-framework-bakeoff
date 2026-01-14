defmodule Share.AccountsTest do
  use Share.DataCase

  alias Share.Accounts
  alias Share.Accounts.User

  import Share.AccountsFixtures

  describe "users" do
    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Enum.map(Accounts.list_users(), & &1.id) == [user.id]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id).id == user.id
    end

    test "get_user/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user(user.id).id == user.id
      assert Accounts.get_user(-1) == nil
    end

    test "get_user_by_email/1" do
      user = user_fixture()
      assert Accounts.get_user_by_email(user.email).id == user.id
      assert Accounts.get_user_by_email("unknown") == nil
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{email: "test@example.com", full_name: "Test User", password: "password1234"}

      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.email == "test@example.com"
      assert user.full_name == "Test User"
      assert Bcrypt.verify_pass("password1234", user.password_hash)
    end

    test "create_user/1 with invalid data returns error" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(%{})
    end

    test "update_user/2 with valid data updates user" do
      user = user_fixture()
      assert {:ok, updated} = Accounts.update_user(user, %{full_name: "New Name"})
      assert updated.full_name == "New Name"
    end

    test "update_user/2 with invalid data returns error" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, %{email: nil})
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, _} = Accounts.delete_user(user)
      assert Accounts.get_user(user.id) == nil
    end

    test "change_user/1 returns a changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end

    test "authenticate_user/2 with valid credentials returns user" do
      user = user_fixture()
      assert {:ok, authenticated_user} = Accounts.authenticate_user(user.email, "password1234")
      assert authenticated_user.id == user.id
    end

    test "authenticate_user/2 with invalid credentials returns error" do
      user = user_fixture()
      assert {:error, :invalid_credentials} = Accounts.authenticate_user(user.email, "wrong")

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("nonexistent@example.com", "pass")
    end
  end
end
