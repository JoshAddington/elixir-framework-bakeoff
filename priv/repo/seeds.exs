alias Share.Repo
alias Share.Accounts.User
alias Share.Knowledge
alias Share.Knowledge.Tag

# Create a system user if none exists
user =
  Repo.all(User) |> List.first() ||
    (
      {:ok, user} =
        Share.Accounts.create_user(%{
          full_name: "John Doe",
          email: "john@example.com",
          password: "password1234"
        })

      user
    )

# Create tags
tags_data = ["Elixir", "Phoenix", "React", "Tailwind", "Design", "DevOps"]

tags =
  Enum.map(tags_data, fn name ->
    case Knowledge.create_tag(%{name: name}) do
      {:ok, tag} -> tag
      {:error, _} -> Repo.get_by!(Tag, name: name)
    end
  end)

# Helper to get random tags
get_random_tags = fn count ->
  tags |> Enum.shuffle() |> Enum.take(count)
end

# Resources data
resources = [
  %{
    title: "Mastering Phoenix LiveView Streams",
    description:
      "Learn how to efficiently manage large collections of data in your Phoenix LiveView applications using the new Streams API.",
    url: "https://example.com/liveview-streams",
    type: "article",
    user_id: user.id,
    tags: get_random_tags.(2)
  },
  %{
    title: "Custom Tailwind Configuration for Dark Mode",
    description:
      "A comprehensive guide on setting up a robust dark mode system using Tailwind CSS and CSS variables.",
    url: "https://example.com/tailwind-dark-mode",
    type: "article",
    user_id: user.id,
    tags: get_random_tags.(3)
  },
  %{
    title: "Elixir Pattern Matching Snippet",
    description:
      "A quick reference for advanced pattern matching techniques in Elixir function heads and case statements.",
    url: "https://example.com/elixir-snippets",
    type: "snippet",
    user_id: user.id,
    tags: get_random_tags.(1)
  },
  %{
    title: "Architecting Scalable Real-time Systems",
    description:
      "Deep dive into the architecture of real-time systems using Phoenix Channels and PubSub for massive concurrency.",
    url: "https://example.com/scalable-realtime",
    type: "resource",
    user_id: user.id,
    tags: get_random_tags.(2)
  }
]

Enum.each(resources, fn attrs ->
  {tags, attrs} = Map.pop(attrs, :tags)
  Knowledge.create_resource(attrs, tags)
end)

IO.puts("Seeded #{Enum.count(resources)} resources and #{Enum.count(tags)} tags.")
