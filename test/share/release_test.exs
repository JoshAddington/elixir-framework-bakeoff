defmodule Share.ReleaseTest do
  use Share.DataCase
  alias Share.Release

  test "migrate/0" do
    # Just check it returns a list of results (if already migrated it might be empty or have ok)
    assert is_list(Release.migrate())
  end

  test "seed/0" do
    # Should create some initial data
    assert :ok = Release.seed()
  end
end
