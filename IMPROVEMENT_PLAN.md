# Improvement Plan

## Priority 1: Critical (Address Immediately)

These issues prevent production deployment and pose immediate security risks.

---

### 1.1 Fix Authentication and Authorization System

**Rationale:** The application currently allows unauthenticated access to all routes and crashes when unauthenticated users try to create resources. There's no authorization checking for edit/delete operations.

**Estimated Effort:** 5-8 hours

**Files Affected:**
- `/lib/share_web/router.ex`
- `/lib/share_web/user_auth.ex`
- `/lib/share_web/live/resource_live/index.ex`
- `/lib/share_web/live/resource_live/form_component.ex`

**Implementation Steps:**

1. **Separate public and authenticated routes in router:**
```elixir
# Remove auth routes from live_session, create separate scopes
scope "/", ShareWeb do
  pipe_through :browser

  get "/login", AuthController, :login
  post "/login", AuthController, :create_session
  get "/register", AuthController, :signup
  post "/register", AuthController, :create
end

scope "/", ShareWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :authenticated,
    on_mount: [{ShareWeb.UserAuth, :ensure_authenticated}] do
    live "/", ResourceLive.Index, :index
    live "/new", ResourceLive.Index, :new
    live "/resources/:id", ResourceLive.Index, :show
    live "/resources/:id/edit", ResourceLive.Index, :edit
  end

  delete "/logout", AuthController, :logout
end
```

2. **Add authentication plugs to UserAuth module:**
```elixir
def require_authenticated_user(conn, _opts) do
  if conn.assigns[:current_user] do
    conn
  else
    conn
    |> put_flash(:error, "You must log in to access this page.")
    |> redirect(to: ~p"/login")
    |> halt()
  end
end

def on_mount(:ensure_authenticated, _params, session, socket) do
  socket = mount_current_user(socket, session)

  if socket.assigns.current_user do
    {:cont, socket}
  else
    socket =
      socket
      |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
      |> Phoenix.LiveView.redirect(to: ~p"/login")

    {:halt, socket}
  end
end
```

3. **Add resource ownership checks:**
```elixir
# In ResourceLive.Index
defp apply_action(socket, :edit, %{"id" => id}) do
  resource = Knowledge.get_resource!(id)

  if resource.user_id == socket.assigns.current_user.id do
    socket
    |> assign(:page_title, "Edit Resource")
    |> assign(:resource, resource)
  else
    socket
    |> put_flash(:error, "You can only edit your own resources")
    |> push_navigate(to: ~p"/")
  end
end

def handle_event("delete", _params, socket) do
  resource = socket.assigns.deleting_resource

  if resource.user_id == socket.assigns.current_user.id do
    {:ok, _} = Knowledge.delete_resource(resource)
    # ... success handling
  else
    {:noreply,
     socket
     |> assign(:deleting_resource, nil)
     |> put_flash(:error, "You can only delete your own resources")}
  end
end
```

4. **Add authorization helper to Knowledge context:**
```elixir
def can_modify_resource?(%User{id: user_id}, %Resource{user_id: resource_user_id}) do
  user_id == resource_user_id
end
```

**Testing Strategy:**
- Create tests that verify unauthenticated users are redirected to login
- Test that users cannot edit/delete resources they don't own
- Test that authenticated users can only modify their own resources
- Verify no crashes occur for unauthenticated access attempts

**Dependencies:** None

---

### 1.2 Fix Database Referential Integrity

**Rationale:** Current `on_delete: :nothing` prevents users from deleting their accounts if they have resources. This violates user expectations and GDPR requirements.

**Estimated Effort:** 2 hours

**Files Affected:**
- New migration file
- `/lib/share/accounts/user.ex`
- `/lib/share/knowledge/resource.ex`

**Implementation Steps:**

1. **Create migration to change foreign key:**
```elixir
defmodule Share.Repo.Migrations.FixUserResourcesCascade do
  use Ecto.Migration

  def up do
    drop constraint(:resources, "resources_user_id_fkey")

    alter table(:resources) do
      modify :user_id, references(:users, on_delete: :delete_all), null: false
    end
  end

  def down do
    drop constraint(:resources, "resources_user_id_fkey")

    alter table(:resources) do
      modify :user_id, references(:users, on_delete: :nothing), null: false
    end
  end
end
```

2. **Add warning to user deletion:**
```elixir
# In Accounts context
def delete_user(%User{} = user) do
  resource_count = Repo.aggregate(
    from(r in Resource, where: r.user_id == ^user.id),
    :count
  )

  if resource_count > 0 do
    {:error, :has_resources, resource_count}
  else
    Repo.delete(user)
  end
end

# Or for cascade with confirmation:
def delete_user_and_resources(%User{} = user) do
  Repo.delete(user)  # Will cascade to resources
end
```

**Testing Strategy:**
- Test that deleting a user cascades to their resources
- Verify no foreign key errors occur
- Test that other users' resources are unaffected

**Dependencies:** None

---

### 1.3 Fix Timing Attack in Authentication

**Rationale:** Current implementation leaks information about valid email addresses through timing differences.

**Estimated Effort:** 1 hour

**Files Affected:**
- `/lib/share/accounts.ex`

**Implementation Steps:**

1. **Update authenticate_user function:**
```elixir
def authenticate_user(email, password) do
  user = get_user_by_email(email)

  cond do
    user && Bcrypt.verify_pass(password, user.password_hash) ->
      {:ok, user}

    user ->
      {:error, :invalid_credentials}

    true ->
      # Run dummy hash to maintain consistent timing
      Bcrypt.no_user_verify()
      {:error, :invalid_credentials}
  end
end
```

**Testing Strategy:**
- Test with valid user, valid password → success
- Test with valid user, invalid password → error
- Test with invalid user, any password → error
- Verify all error cases take similar time (timing test)

**Dependencies:** None

---

### 1.4 Fix Failing Tests

**Rationale:** Four tests in `user_auth_test.exs` fail due to missing session setup. Broken tests indicate incomplete implementation.

**Estimated Effort:** 2 hours

**Files Affected:**
- `/test/share_web/user_auth_test.exs`
- `/test/support/conn_case.ex`

**Implementation Steps:**

1. **Add session initialization to test setup:**
```elixir
# In user_auth_test.exs
setup %{conn: conn} do
  conn =
    conn
    |> Map.replace!(:secret_key_base, ShareWeb.Endpoint.config(:secret_key_base))
    |> Plug.Test.init_test_session(%{})

  {:ok, conn: conn}
end
```

2. **Or use proper ConnCase helper:**
```elixir
# In conn_case.ex
def setup_session(conn) do
  conn
  |> Plug.Test.init_test_session(%{})
end
```

3. **Fix Release.seed test:**
```elixir
# In release_test.exs
test "seed/0 seeds the database" do
  result = Release.seed()
  # The function returns the result of Ecto.Migrator.with_repo
  assert is_list(result)

  # Verify data was created
  assert Repo.aggregate(User, :count) > 0
  assert Repo.aggregate(Resource, :count) > 0
end
```

**Testing Strategy:**
- Run `mix test` and verify all tests pass
- Check test coverage with `mix test --cover`

**Dependencies:** None

---

## Priority 2: High (Address Soon)

These issues significantly impact security, performance, or maintainability.

---

### 2.1 Remove Secrets from Version Control

**Rationale:** Hardcoded database passwords, secret keys, and signing salts are committed. While these are dev values, it's bad practice.

**Estimated Effort:** 2 hours

**Files Affected:**
- `/config/dev.exs`
- `/config/config.exs`
- `/lib/share_web/endpoint.ex`
- `.env.example` (new)
- `README.md`

**Implementation Steps:**

1. **Create .env.example:**
```bash
DB_USER=postgres
DB_PASSWORD=your_password_here
DB_HOST=localhost
```

2. **Update dev.exs:**
```elixir
config :share, Share.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost")
```

3. **Add .env to .gitignore** (if not already there)

4. **Update README with setup instructions:**
```markdown
## Setup

1. Copy `.env.example` to `.env`
2. Update database credentials in `.env`
3. Run `source .env && mix setup`
```

**Testing Strategy:**
- Verify app still runs after changes
- Test with missing env vars (should use defaults)
- Document setup process clearly

**Dependencies:** None

---

### 2.2 Add Database Indexes

**Rationale:** Missing indexes on frequently queried columns will cause performance issues as data grows.

**Estimated Effort:** 1 hour

**Files Affected:**
- New migration file

**Implementation Steps:**

1. **Create migration:**
```elixir
defmodule Share.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    # For ORDER BY inserted_at
    create index(:resources, [:inserted_at])

    # For case-insensitive tag lookups
    execute "CREATE INDEX tags_name_lower ON tags (lower(name))"

    # For full-text search (optional but recommended)
    execute """
    CREATE INDEX resources_title_search
    ON resources
    USING gin(to_tsvector('english', title))
    """

    execute """
    CREATE INDEX resources_description_search
    ON resources
    USING gin(to_tsvector('english', description))
    """
  end

  def down do
    drop index(:resources, [:inserted_at])
    execute "DROP INDEX tags_name_lower"
    execute "DROP INDEX resources_title_search"
    execute "DROP INDEX resources_description_search"
  end
end
```

2. **Update search query to use indexes:**
```elixir
# In filter_by_query, use tsvector search for better performance
defp filter_by_query(query, search_term) when is_binary(search_term) and search_term != "" do
  search_tsquery = String.replace(search_term, ~r/\s+/, " | ")

  query
  |> where(
    [r],
    fragment(
      "to_tsvector('english', ?) @@ to_tsquery('english', ?)",
      r.title,
      ^search_tsquery
    ) or
    fragment(
      "to_tsvector('english', ?) @@ to_tsquery('english', ?)",
      r.description,
      ^search_tsquery
    )
  )
end
```

**Testing Strategy:**
- Run EXPLAIN ANALYZE on queries before and after
- Verify query plans use indexes
- Benchmark search performance with large dataset

**Dependencies:** None

---

### 2.3 Fix N+1 Query in Resource Listing

**Rationale:** Current implementation may load tags multiple times in search scenarios.

**Estimated Effort:** 1 hour

**Files Affected:**
- `/lib/share/knowledge.ex`

**Implementation Steps:**

1. **Refactor list_resources to preload after filters:**
```elixir
def list_resources(filters \\ %{}) do
  Resource
  |> filter_by_type(filters["types"])
  |> filter_by_tag(filters["tag"])
  |> filter_by_user(filters["user_id"])
  |> filter_by_query(filters["q"])
  |> order_by([r], desc: r.inserted_at)
  |> preload([:user, :tags])
  |> Repo.all()
end
```

2. **Update filter_by_query to use distinct properly:**
```elixir
defp filter_by_query(query, search_term) when is_binary(search_term) and search_term != "" do
  search_term = "%#{search_term}%"

  from(r in query,
    left_join: t in assoc(r, :tags),
    where:
      ilike(r.title, ^search_term) or
      ilike(r.description, ^search_term) or
      ilike(t.name, ^search_term),
    distinct: r.id
  )
end
```

**Testing Strategy:**
- Enable Ecto query logging
- Search for resources and verify only necessary queries run
- Check that tags aren't loaded twice

**Dependencies:** None

---

### 2.4 Add Rate Limiting to Authentication

**Rationale:** Prevents brute force attacks on login endpoint.

**Estimated Effort:** 2 hours

**Files Affected:**
- `mix.exs` (add dependency)
- `/lib/share_web/controllers/auth_controller.ex`
- `/lib/share_web/plugs/rate_limiter.ex` (new)

**Implementation Steps:**

1. **Add hammer to dependencies:**
```elixir
{:hammer, "~> 6.1"}
```

2. **Create rate limiter plug:**
```elixir
defmodule ShareWeb.Plugs.RateLimiter do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, opts) do
    key = opts[:key] || "global"
    scale = opts[:scale] || 60_000  # 1 minute
    limit = opts[:limit] || 5

    identifier = get_identifier(conn)

    case Hammer.check_rate("#{key}:#{identifier}", scale, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> put_flash(:error, "Too many attempts. Please try again later.")
        |> redirect(to: "/login")
        |> halt()
    end
  end

  defp get_identifier(conn) do
    # Use IP address as identifier
    conn.remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end
end
```

3. **Apply to auth routes:**
```elixir
# In router.ex
pipeline :auth_limited do
  plug :browser
  plug ShareWeb.Plugs.RateLimiter, key: "auth", scale: 60_000, limit: 5
end

scope "/", ShareWeb do
  pipe_through :auth_limited

  post "/login", AuthController, :create_session
  post "/register", AuthController, :create
end
```

**Testing Strategy:**
- Test normal login flow works
- Test that 6th attempt in 1 minute is blocked
- Test that rate limit resets after time window

**Dependencies:** Add `hammer` dependency first

---

### 2.5 Add Authorization Helper Module

**Rationale:** Centralize authorization logic rather than scattering ownership checks throughout LiveViews.

**Estimated Effort:** 2 hours

**Files Affected:**
- `/lib/share/authorization.ex` (new)
- `/lib/share_web/live/resource_live/index.ex`
- `/lib/share_web/live/resource_live/form_component.ex`

**Implementation Steps:**

1. **Create authorization module:**
```elixir
defmodule Share.Authorization do
  @moduledoc """
  Authorization policies for the Share application.
  """

  alias Share.Accounts.User
  alias Share.Knowledge.Resource

  @doc """
  Checks if a user can modify (edit/delete) a resource.
  """
  def can_modify?(resource, user)
  def can_modify?(%Resource{user_id: uid}, %User{id: uid}), do: true
  def can_modify?(_resource, _user), do: false

  @doc """
  Same as can_modify?/2 but raises on authorization failure.
  """
  def authorize_modify!(resource, user) do
    if can_modify?(resource, user) do
      :ok
    else
      raise Share.Authorization.Error, "User not authorized to modify this resource"
    end
  end
end

defmodule Share.Authorization.Error do
  defexception [:message]
end
```

2. **Use in LiveViews:**
```elixir
# In ResourceLive.Index
alias Share.Authorization

defp apply_action(socket, :edit, %{"id" => id}) do
  resource = Knowledge.get_resource!(id)

  if Authorization.can_modify?(resource, socket.assigns.current_user) do
    socket
    |> assign(:page_title, "Edit Resource")
    |> assign(:resource, resource)
  else
    socket
    |> put_flash(:error, "Not authorized")
    |> push_navigate(to: ~p"/")
  end
end
```

**Testing Strategy:**
- Test authorization for resource owner (should pass)
- Test authorization for different user (should fail)
- Test with nil user (should fail)
- Add tests for Authorization module itself

**Dependencies:** None

---

## Priority 3: Medium (Plan for Next Sprint)

These improve code quality and maintainability but aren't urgent.

---

### 3.1 Add Type Specifications

**Rationale:** Typespecs improve documentation and enable static analysis with Dialyzer.

**Estimated Effort:** 4 hours (ongoing)

**Files Affected:**
- All modules in `/lib/share/` and `/lib/share_web/`

**Implementation Steps:**

1. **Add Dialyzer to dev dependencies:**
```elixir
{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
```

2. **Add @spec annotations to public functions:**
```elixir
# Example for Accounts
@spec list_users() :: [User.t()]
def list_users do
  Repo.all(User)
end

@spec get_user(integer()) :: User.t() | nil
def get_user(id), do: Repo.get(User, id)

@spec authenticate_user(String.t(), String.t()) ::
  {:ok, User.t()} | {:error, :invalid_credentials}
def authenticate_user(email, password) do
  # ...
end
```

3. **Run Dialyzer and fix issues:**
```bash
mix dialyzer
```

**Testing Strategy:**
- Run `mix dialyzer` and verify no errors
- Add specs incrementally, module by module
- Check that specs match actual behavior

**Dependencies:** None

---

### 3.2 Replace Magic Strings with Constants

**Rationale:** Resource types and other magic strings should be centralized.

**Estimated Effort:** 2 hours

**Files Affected:**
- `/lib/share/knowledge/resource.ex`
- `/lib/share/knowledge.ex`
- `/lib/share_web/live/resource_live/form_component.ex`

**Implementation Steps:**

1. **Define constants in Resource schema:**
```elixir
defmodule Share.Knowledge.Resource do
  use Ecto.Schema
  import Ecto.Changeset

  @type_article "article"
  @type_snippet "snippet"
  @type_resource "resource"

  @types [@type_article, @type_snippet, @type_resource]

  def type_article, do: @type_article
  def type_snippet, do: @type_snippet
  def type_resource, do: @type_resource
  def types, do: @types

  schema "resources" do
    field :type, :string
    # ...
  end

  def changeset(resource, attrs, tags \\ []) do
    resource
    |> cast(attrs, [:title, :description, :url, :type, :user_id, :snippet, :language])
    |> validate_required([:title, :description, :type, :user_id])
    |> validate_inclusion(:type, @types)
    |> validate_conditional_fields()
    |> put_assoc(:tags, tags)
  end
end
```

2. **Use constants in queries:**
```elixir
# In Knowledge context
alias Share.Knowledge.Resource

defp filter_by_type(query, type) when type in [
  Resource.type_article(),
  Resource.type_snippet(),
  Resource.type_resource()
] do
  where(query, [r], r.type == ^type)
end
```

3. **Update form component:**
```elixir
# In form_component.ex render
<.input
  field={@form[:type]}
  type="select"
  options={[
    {"Article", Resource.type_article()},
    {"Code Snippet", Resource.type_snippet()},
    {"Learning Resource", Resource.type_resource()}
  ]}
  prompt="Select Resource Type"
/>
```

**Testing Strategy:**
- Run existing tests to verify behavior unchanged
- Test that only valid types can be created
- Verify form still renders correctly

**Dependencies:** None

---

### 3.3 Implement Tag Caching

**Rationale:** Tag list is fetched repeatedly but changes infrequently.

**Estimated Effort:** 2 hours

**Files Affected:**
- `mix.exs` (add cachex)
- `/lib/share/application.ex`
- `/lib/share/knowledge.ex`

**Implementation Steps:**

1. **Add Cachex to dependencies:**
```elixir
{:cachex, "~> 4.0"}
```

2. **Add cache to supervision tree:**
```elixir
# In application.ex
children = [
  ShareWeb.Telemetry,
  Share.Repo,
  {Cachex, name: :share_cache},
  # ...
]
```

3. **Add cached tag fetching:**
```elixir
# In Knowledge context
def list_tags(opts \\ []) do
  use_cache = Keyword.get(opts, :cache, true)

  if use_cache do
    Cachex.fetch!(:share_cache, "all_tags", fn ->
      {:commit, Repo.all(Tag), ttl: :timer.minutes(5)}
    end)
  else
    Repo.all(Tag)
  end
end

def invalidate_tag_cache do
  Cachex.del(:share_cache, "all_tags")
end

# Call invalidate_tag_cache after creating new tags
def create_tag(attrs) do
  with {:ok, tag} <- %Tag{} |> Tag.changeset(attrs) |> Repo.insert() do
    invalidate_tag_cache()
    {:ok, tag}
  end
end
```

**Testing Strategy:**
- Test that tags are cached after first fetch
- Test that cache is invalidated when new tag created
- Benchmark tag fetching with and without cache

**Dependencies:** Add `cachex` dependency first

---

### 3.4 Add Database Constraints

**Rationale:** Database-level validation prevents invalid data even if app code is bypassed.

**Estimated Effort:** 1 hour

**Files Affected:**
- New migration file

**Implementation Steps:**

1. **Create constraint migration:**
```elixir
defmodule Share.Repo.Migrations.AddDataConstraints do
  use Ecto.Migration

  def change do
    # Ensure resource type is valid
    create constraint(:resources, :type_must_be_valid,
      check: "type IN ('article', 'snippet', 'resource')"
    )

    # Ensure URLs are not empty strings
    create constraint(:resources, :url_not_empty,
      check: "url IS NULL OR length(trim(url)) > 0"
    )

    # Ensure emails contain @
    create constraint(:users, :email_format,
      check: "email ~* '^[^@]+@[^@]+$'"
    )
  end
end
```

**Testing Strategy:**
- Test that invalid types are rejected at DB level
- Test that empty URLs are rejected
- Verify constraints work as expected

**Dependencies:** None

---

### 3.5 Migrate LiveView to Streams

**Rationale:** Improves performance and memory usage for large resource lists.

**Estimated Effort:** 3 hours

**Files Affected:**
- `/lib/share_web/live/resource_live/index.ex`
- `/lib/share_web/live/resource_live/index.html.heex`

**Implementation Steps:**

1. **Update mount to use streams:**
```elixir
def mount(_params, _session, socket) do
  tags = Knowledge.list_tags()

  {:ok,
   socket
   |> assign(:tags, tags)
   |> assign(:active_types, [])
   |> assign(:active_tag, nil)
   |> assign(:active_user_id, nil)
   |> assign(:search_query, nil)
   |> assign(:show_mobile_filters, false)
   |> assign(:pending_types, [])
   |> assign(:pending_tag, nil)
   |> assign(:deleting_resource, nil)
   |> stream(:resources, [])}
end
```

2. **Update handle_params to stream resources:**
```elixir
def handle_params(params, _url, socket) do
  socket = apply_action(socket, socket.assigns.live_action, params)

  types = normalize_types(params["types"])
  filters = build_filters(params)
  resources = Knowledge.list_resources(filters)

  {:noreply,
   socket
   |> stream(:resources, resources, reset: true)
   |> assign(:active_types, types)
   |> assign(:active_tag, params["tag"])
   |> assign(:active_user_id, params["user_id"])
   |> assign(:search_query, params["q"])
   |> assign(:current_filters, filters)}
end
```

3. **Update template to use streams:**
```heex
<div id="resources" phx-update="stream">
  <div
    :for={{dom_id, resource} <- @streams.resources}
    id={dom_id}
    class="resource-card"
  >
    <!-- resource content -->
  </div>
</div>
```

**Testing Strategy:**
- Test that all filtering still works
- Verify resource list renders correctly
- Test that new resources appear properly
- Benchmark memory usage and rendering speed

**Dependencies:** None

---

## Priority 4: Low (Address When Convenient)

Nice-to-have improvements that don't significantly impact functionality.

---

### 4.1 Add Credo Configuration and Fix Warnings

**Rationale:** Credo is already a dependency but may not be fully configured. Clean code analysis output.

**Estimated Effort:** 2 hours

**Files Affected:**
- `.credo.exs` (new)
- Various files to fix warnings

**Implementation Steps:**

1. **Generate Credo config:**
```bash
mix credo gen.config
```

2. **Run Credo and review warnings:**
```bash
mix credo --strict
```

3. **Fix high-priority issues:**
- Remove unused imports (like in `resource_live_test.exs`)
- Add missing documentation
- Fix complexity warnings

**Testing Strategy:**
- Run `mix credo` and ensure no critical issues
- Verify code still works after refactoring

**Dependencies:** None

---

### 4.2 Add Soft Delete for Users

**Rationale:** Preserves data and allows for account restoration.

**Estimated Effort:** 4 hours

**Files Affected:**
- New migration
- `/lib/share/accounts/user.ex`
- `/lib/share/accounts.ex`
- `/lib/share/knowledge/resource.ex`

**Implementation Steps:**

1. **Add deleted_at to users:**
```elixir
alter table(:users) do
  add :deleted_at, :utc_datetime
end

create index(:users, [:deleted_at])
```

2. **Update schema:**
```elixir
schema "users" do
  field :deleted_at, :utc_datetime
  # ...
end
```

3. **Add soft delete functions:**
```elixir
def soft_delete_user(%User{} = user) do
  user
  |> Ecto.Changeset.change(%{deleted_at: DateTime.utc_now()})
  |> Repo.update()
end

def restore_user(%User{} = user) do
  user
  |> Ecto.Changeset.change(%{deleted_at: nil})
  |> Repo.update()
end
```

4. **Filter deleted users in queries:**
```elixir
def list_users do
  from(u in User, where: is_nil(u.deleted_at))
  |> Repo.all()
end
```

**Testing Strategy:**
- Test soft delete removes user from queries
- Test restore brings user back
- Verify user's resources remain accessible

**Dependencies:** None

---

### 4.3 Add Telemetry Events for Business Metrics

**Rationale:** Track application usage and performance beyond default Phoenix metrics.

**Estimated Effort:** 2 hours

**Files Affected:**
- `/lib/share/knowledge.ex`
- `/lib/share/accounts.ex`
- `/lib/share_web/telemetry.ex`

**Implementation Steps:**

1. **Add telemetry events:**
```elixir
# In Knowledge.create_resource
def create_resource(attrs, tags \\ []) do
  :telemetry.execute(
    [:share, :resource, :create, :start],
    %{system_time: System.system_time()},
    %{type: attrs["type"]}
  )

  result = %Resource{}
  |> Resource.changeset(attrs, tags)
  |> Repo.insert()

  case result do
    {:ok, resource} ->
      :telemetry.execute(
        [:share, :resource, :create, :stop],
        %{duration: 0},
        %{type: resource.type}
      )

    {:error, _} ->
      :telemetry.execute(
        [:share, :resource, :create, :error],
        %{},
        %{type: attrs["type"]}
      )
  end

  result
end
```

2. **Add metric definitions:**
```elixir
# In telemetry.ex
defp metrics do
  [
    # Existing metrics...

    # Business metrics
    counter("share.resource.create.stop"),
    counter("share.resource.create.error"),
    counter("share.user.create.stop"),

    distribution("share.resource.create.duration",
      unit: {:native, :millisecond}
    )
  ]
end
```

**Testing Strategy:**
- Verify metrics appear in LiveDashboard
- Test that events fire on resource creation
- Check metric values are accurate

**Dependencies:** None

---

### 4.4 Add Email Validation Service

**Rationale:** Current regex is basic. More sophisticated validation prevents typos and disposable emails.

**Estimated Effort:** 3 hours

**Files Affected:**
- `mix.exs` (add email_checker or similar)
- `/lib/share/accounts/user.ex`

**Implementation Steps:**

1. **Add email validation library:**
```elixir
{:email_checker, "~> 0.2"}
```

2. **Enhance email validation:**
```elixir
def changeset(user, attrs) do
  user
  |> cast(attrs, [:full_name, :email])
  |> validate_required([:full_name, :email])
  |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
  |> validate_email_deliverability()
  |> unique_constraint(:email)
end

defp validate_email_deliverability(changeset) do
  validate_change(changeset, :email, fn :email, email ->
    case EmailChecker.valid?(email) do
      true -> []
      false -> [email: "appears to be invalid or from a disposable email provider"]
    end
  end)
end
```

**Testing Strategy:**
- Test with valid emails (should pass)
- Test with invalid domains (should fail)
- Test with disposable email providers (should fail)

**Dependencies:** Add email validation library first

---

### 4.5 Improve Error Pages

**Rationale:** Production error pages should be user-friendly and not leak implementation details.

**Estimated Effort:** 2 hours

**Files Affected:**
- `/lib/share_web/controllers/error_html.ex`
- `/lib/share_web/controllers/error_html/*.html.heex` templates

**Implementation Steps:**

1. **Create custom error templates:**
```heex
<!-- error_html/404.html.heex -->
<div class="min-h-screen flex items-center justify-center bg-gray-50">
  <div class="max-w-md w-full text-center">
    <h1 class="text-6xl font-bold text-gray-900">404</h1>
    <p class="mt-4 text-xl text-gray-600">Page not found</p>
    <p class="mt-2 text-gray-500">
      The page you're looking for doesn't exist or has been moved.
    </p>
    <a href="/" class="mt-6 inline-block px-6 py-3 bg-blue-600 text-white rounded-lg">
      Go Home
    </a>
  </div>
</div>
```

2. **Add similar templates for 500 errors**

3. **Configure production to use custom errors:**
```elixir
# Already configured properly, just verify templates exist
```

**Testing Strategy:**
- Test 404 pages in dev and prod modes
- Test 500 errors show friendly messages
- Verify no stack traces leak in production

**Dependencies:** None

---

## Summary

**Total Estimated Effort:** 45-55 hours of focused development

**Critical Path:**
1. Fix authentication (8h)
2. Fix database integrity (2h)
3. Fix timing attack (1h)
4. Fix failing tests (2h)
5. Add rate limiting (2h)
6. Add indexes (1h)

**After completing Priority 1 and 2 items (approximately 20-25 hours), the application will be production-ready from a security and stability standpoint.**

Priority 3 and 4 items can be scheduled into future sprints as time allows. They improve code quality and user experience but aren't blockers for deployment.
