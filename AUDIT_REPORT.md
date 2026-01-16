# Elixir/Phoenix Codebase Audit Report

Generated: 2026-01-15

## Executive Summary

This is a **small-to-medium knowledge-sharing application** built with Phoenix 1.8, Ecto, and LiveView. The codebase demonstrates reasonable fundamentals but suffers from **critical security vulnerabilities**, several architectural deficiencies, and incomplete testing.

**Overall Assessment: C+ (Needs Significant Improvement)**

The application works for basic scenarios, but the security issues alone make this unsuitable for production deployment without immediate remediation. Authentication is fundamentally broken, database integrity is at risk from cascading deletes, and there are multiple areas where best practices are violated.

**Critical Priority:** Fix authentication security issues and database referential integrity problems before any production deployment.

---

## Critical Issues

### 1. AUTHENTICATION IS COMPLETELY BROKEN - NO AUTHORIZATION WHATSOEVER

**Location:** `/lib/share_web/router.ex:32-36`, `/lib/share_web/live/resource_live/index.ex:60`, `/lib/share_web/live/resource_live/form_component.ex:314`

**Issue:** Authentication routes (login, register, logout) are placed INSIDE the `live_session` block but are regular controller actions, not LiveView routes. This means:
- Users must navigate to login/register through standard HTTP GET/POST
- The `on_mount` hook runs for every LiveView, including `/new` and `/edit`
- **ANY UNAUTHENTICATED USER CAN ACCESS THE ROOT ROUTE** and view all resources
- The app crashes when unauthenticated users try to create resources (line 60: `socket.assigns.current_user.id` will fail with nil)
- There is NO authorization checking if users can edit/delete resources they don't own

**Impact:**
- **Critical Security Vulnerability**: Anyone can view all content
- **Application Crashes**: Unauthenticated users cause runtime errors
- **Data Integrity Risk**: No protection against unauthorized edits/deletes if the crash is bypassed

**Recommendation:**
```elixir
# In router.ex - SEPARATE authenticated and public routes

scope "/", ShareWeb do
  pipe_through :browser

  # Public routes
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

You need to implement `require_authenticated_user` plug and `ensure_authenticated` on_mount hook that actually redirect unauthenticated users.

### 2. Database Cascading Delete Will Destroy User Data

**Location:** `/priv/repo/migrations/20251226165731_create_resources.exs:10`

**Issue:** User foreign key has `on_delete: :nothing`, which will **prevent user deletion** if they have any resources. This is a terrible user experience and creates orphaned accounts.

**Impact:**
- Users cannot delete their accounts if they've created any resources
- No data cleanup strategy for user departures
- Violates GDPR "right to be forgotten" requirements

**Recommendation:**
```elixir
# Create a migration to fix this
add :user_id, references(:users, on_delete: :delete_all), null: false
# OR better yet:
add :user_id, references(:users, on_delete: :nilify_set)
add :deleted_user_name, :string  # Store name for historical context
```

The `:delete_all` approach is simpler but loses data. The `:nilify_set` approach preserves resources but requires updating your schema and queries to handle nil users.

### 3. Timing Attack Vulnerability in Authentication

**Location:** `/lib/share/accounts.ex:46-54`

**Issue:** The `authenticate_user/2` function has different execution paths depending on whether the user exists:
```elixir
def authenticate_user(email, password) do
  user = get_user_by_email(email)

  if user && Bcrypt.verify_pass(password, user.password_hash) do
    {:ok, user}
  else
    {:error, :invalid_credentials}
  end
end
```

If the user doesn't exist, `Bcrypt.verify_pass` is never called. If the user exists but password is wrong, bcrypt verification runs. This timing difference can be used to enumerate valid email addresses.

**Impact:**
- Attackers can determine which emails are registered
- Facilitates targeted phishing and credential stuffing attacks

**Recommendation:**
```elixir
def authenticate_user(email, password) do
  user = get_user_by_email(email)

  cond do
    user && Bcrypt.verify_pass(password, user.password_hash) ->
      {:ok, user}

    user ->
      {:error, :invalid_credentials}

    true ->
      # Run dummy bcrypt to maintain consistent timing
      Bcrypt.no_user_verify()
      {:error, :invalid_credentials}
  end
end
```

### 4. Hardcoded Database Credentials in Version Control

**Location:** `/config/dev.exs:6`

**Issue:** Database password `"tinker12"` is committed to git. While this is dev config, it demonstrates poor security hygiene.

**Impact:**
- Sets bad precedent
- Could be copied to production configs
- Credentials leak in git history

**Recommendation:**
```elixir
# Use environment variables even in dev
config :share, Share.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: "share_dev"
```

### 5. Session Salt and Secret Keys Exposed in Repository

**Location:** `/config/dev.exs:26`, `/config/config.exs:23`, `/lib/share_web/endpoint.ex:10`

**Issue:** Secret key base and signing salts are hardcoded:
- `secret_key_base: "jrNuYypf2K1plric+6KXoXZ/gf2QaU10YU3LvED7ofTDm7eOJ4XRg1HDqBs6QLsp"`
- `signing_salt: "+NWC4Riz"`
- `live_view: [signing_salt: "BQZnfG1W"]`

**Impact:**
- Session hijacking if these keys are used in any shared environment
- Cookie tampering possible with known signing salts
- Complete compromise of session security

**Recommendation:**
While dev keys can be hardcoded, ensure they're NEVER copied to production. Add checks in runtime.exs to validate production secrets aren't default values.

---

## Major Concerns

### 6. No Authorization on Resource Operations

**Location:** `/lib/share_web/live/resource_live/index.ex:75-79`, `form_component.ex:341-371`

**Issue:** While users must be logged in (after fixing #1), there's no check that they own a resource before editing/deleting it. User A can edit User B's resources by simply knowing the ID.

**Impact:**
- Complete lack of data ownership protection
- Users can modify/delete each other's content

**Recommendation:**
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
```

Add similar checks for delete operations.

### 7. Potential N+1 Query in Resource Listing

**Location:** `/lib/share/knowledge.ex:27-39`

**Issue:** The `filter_by_query` function joins tags for search but then the main query also preloads tags. This could cause duplicate queries:
```elixir
Resource
|> preload([:user, :tags])  # <-- Preloads tags
|> filter_by_query(filters["q"])  # <-- May join tags again
```

If the filter includes a search term with tag matches, you're loading tags twice.

**Impact:**
- Performance degradation with large datasets
- Unnecessary database load

**Recommendation:**
Refactor to conditionally preload or use a single join:
```elixir
def list_resources(filters \\ %{}) do
  query =
    Resource
    |> filter_by_type(filters["types"])
    |> filter_by_tag(filters["tag"])
    |> filter_by_user(filters["user_id"])
    |> filter_by_query(filters["q"])
    |> order_by([r], desc: r.inserted_at)

  # Preload associations after all filters applied
  query
  |> preload([:user, :tags])
  |> Repo.all()
end
```

### 8. Missing Database Indexes

**Location:** `/priv/repo/migrations/20251226153448_create_users.exs`, other migrations

**Issue:** Several columns that are frequently queried lack indexes:
- `resources.inserted_at` (used in ORDER BY)
- `tags.name` (case-insensitive search with `fragment("lower(?)")`)
- Potentially `resources.title` and `resources.description` if full-text search grows

**Impact:**
- Slow queries as data grows
- Linear scans instead of index lookups

**Recommendation:**
```elixir
# New migration
create index(:resources, [:inserted_at])
create index(:tags, ["lower(name)"])  # For case-insensitive lookups

# Consider GIN indexes for full-text search on title/description
execute "CREATE INDEX resources_title_gin ON resources USING gin(to_tsvector('english', title))"
execute "CREATE INDEX resources_description_gin ON resources USING gin(to_tsvector('english', description))"
```

### 9. Inconsistent Error Handling Pattern

**Location:** `/lib/share/accounts.ex:46-54`

**Issue:** `authenticate_user` returns `{:error, :invalid_credentials}` but other functions return `{:error, %Ecto.Changeset{}}`. This inconsistency makes error handling unpredictable.

**Impact:**
- Difficult to write consistent error handlers
- Easy to miss error cases

**Recommendation:**
Standardize on using changesets for validation errors and atoms for business logic errors, but document this clearly or create custom error types:
```elixir
defmodule Share.Accounts.AuthenticationError do
  defexception [:message]
end

def authenticate_user(email, password) do
  # ... validation logic ...
  {:error, %AuthenticationError{message: "Invalid credentials"}}
end
```

### 10. Tag Creation Doesn't Handle Race Conditions

**Location:** `/lib/share_web/live/resource_live/form_component.ex:373-385`

**Issue:** `resolve_tags` creates new tags if they don't exist, but uses case-insensitive matching. If two users simultaneously create a resource with the same new tag (different case), both will try to insert it:

```elixir
new_tags =
  tag_names
  |> Enum.reject(fn name -> String.downcase(name) in existing_names_down end)
  |> Enum.map(fn name ->
    with {:ok, tag} <- Knowledge.create_tag(%{name: name}), do: tag
  end)
```

The `create_tag` will fail due to unique constraint, and the `with` will return `{:error, changeset}`, which then gets filtered out. This silently drops tags.

**Impact:**
- Tags get silently dropped under concurrent creation
- Users see "Resource created" but some tags are missing

**Recommendation:**
```elixir
defp resolve_tags(existing_tags, tag_names) do
  existing_names_down = Enum.map(existing_tags, &String.downcase(&1.name))

  new_tags =
    tag_names
    |> Enum.reject(fn name -> String.downcase(name) in existing_names_down end)
    |> Enum.map(fn name ->
      case Knowledge.create_tag(%{name: name}) do
        {:ok, tag} ->
          tag
        {:error, %{errors: [name: {"has already been taken", _}]}} ->
          # Tag was created by another process, fetch it
          Repo.get_by!(Tag, name: name)
        {:error, changeset} ->
          # Actual error, should bubble up
          raise "Failed to create tag: #{inspect(changeset)}"
      end
    end)

  existing_tags ++ new_tags
end
```

### 11. LiveView Not Using Streams for Resource List

**Location:** `/lib/share_web/live/resource_live/index.ex:6-22`

**Issue:** Resources are loaded as a full list into assigns. For large datasets, this loads all data into memory and sends it to the client on every update.

**Impact:**
- Memory usage grows linearly with resource count
- Slow initial page loads with many resources
- Full re-render on filter changes

**Recommendation:**
Use Phoenix.LiveView.Streams:
```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:tags, Knowledge.list_tags())
   |> stream(:resources, [])}
end

def handle_params(params, _url, socket) do
  resources = Knowledge.list_resources(build_filters(params))
  {:noreply, stream(socket, :resources, resources, reset: true)}
end
```

---

## Best Practices Violations

### Structure & Organization

**12. Contexts Are Well-Defined (Good)**

The `Accounts` and `Knowledge` contexts are cleanly separated. This is done correctly.

**13. Missing Documentation for Public Functions**

**Location:** Throughout `/lib/share/knowledge.ex` and `/lib/share/accounts.ex`

Most functions have `@doc` annotations, but some private helpers don't explain their logic. For example, `filter_by_query` has complex join logic that deserves explanation.

### Code Quality

**14. Magic Strings for Resource Types**

**Location:** `/lib/share/knowledge/resource.ex:9`, `/lib/share/knowledge.ex:54`

Resource types are hardcoded strings `"article"`, `"snippet"`, `"resource"`. This should be an enum or module constant.

**Recommendation:**
```elixir
defmodule Share.Knowledge.Resource do
  @type_article "article"
  @type_snippet "snippet"
  @type_resource "resource"

  @types [@type_article, @type_snippet, @type_resource]

  def types, do: @types
  def valid_type?(type), do: type in @types
end
```

**15. Excessive Assign Usage in LiveView**

**Location:** `/lib/share_web/live/resource_live/index.ex:10-21`

The LiveView assigns 11 different values in mount. Some of these (`pending_types`, `pending_tag`, `show_mobile_filters`) are only for UI state and could be tracked differently.

**16. Missing Function Typespecs**

**Location:** Throughout codebase

No `@spec` annotations anywhere. While not required, they greatly improve documentation and enable Dialyzer for static analysis.

**Recommendation:**
```elixir
@spec authenticate_user(String.t(), String.t()) :: {:ok, User.t()} | {:error, :invalid_credentials}
def authenticate_user(email, password) do
  # ...
end
```

### Phoenix Patterns

**17. Controller Actions Mixed with LiveView Routes (Critical - Already Covered)**

See issue #1.

**18. Flash Messages in LiveComponent**

**Location:** `/lib/share_web/live/resource_live/form_component.ex:349, 365`

LiveComponents shouldn't set flash messages directly. They should send events to the parent LiveView.

**Recommendation:**
```elixir
# In form_component
{:noreply, send(self(), {:resource_saved, resource})}

# In parent live view
def handle_info({:resource_saved, resource}, socket) do
  {:noreply,
   socket
   |> put_flash(:info, "Resource updated!")
   |> push_navigate(to: ~p"/")}
end
```

### Database & Data Layer

**19. Missing Database Constraints**

**Location:** `/priv/repo/migrations/20251226165731_create_resources.exs`

The `type` field should have a CHECK constraint to ensure only valid values:
```elixir
create constraint(:resources, :type_must_be_valid,
  check: "type IN ('article', 'snippet', 'resource')")
```

**20. No Soft Delete Strategy**

Users and resources are hard-deleted. For a knowledge-sharing app, you probably want to preserve content even if users leave.

**21. Missing Timestamps on Join Table**

**Location:** `/priv/repo/migrations/20251226165734_create_tags_and_resource_tags.exs:12-15`

The `resources_tags` join table has no timestamps. You can't track when tag associations were created.

### Testing

**22. Test Failures in Session Tests**

**Location:** `/test/share_web/user_auth_test.exs`

Four tests fail because they don't properly set up the session plug. This indicates tests were written but not maintained.

**23. Release.seed Test Failure**

**Location:** `/test/share/release_test.exs:10`

The test expects `Release.seed()` to return `:ok` but it returns a complex tuple. This test is broken and never passes.

**24. Low Test Coverage on LiveView**

LiveView tests exist but don't cover authorization scenarios, error cases, or edge conditions. They're mostly happy-path tests.

**25. No Tests for Authentication Security**

There are no tests verifying:
- Unauthenticated users are blocked from protected routes
- Users can't access resources they don't own
- Timing attack protections

### Performance

**26. No Database Connection Pooling Configuration**

Pool size is set to 10 in dev, but there's no discussion of whether this is appropriate for production load.

**27. No Caching Strategy**

Tag list is fetched on every LiveView mount and form render. With stable tag data, this should be cached.

**Recommendation:**
```elixir
defp cached_tags do
  Cachex.fetch!(:app_cache, "all_tags", fn ->
    {:commit, Knowledge.list_tags(), ttl: :timer.minutes(5)}
  end)
end
```

### Security

**28. No Rate Limiting on Authentication**

**Location:** `/lib/share_web/controllers/auth_controller.ex`

Login attempts aren't rate-limited. Brute force attacks are trivial.

**Recommendation:**
Add `plug :rate_limit` using a library like `hammer` or `ex_rated`.

**29. No HTTPS Enforcement in Production Config**

**Location:** `/config/runtime.exs`

The production config has commented-out SSL and force_ssl configuration. This should be active.

**30. Session Configuration Could Be Stronger**

**Location:** `/lib/share_web/endpoint.ex:7-12`

Session uses `same_site: "Lax"` but doesn't set `http_only: true` or `secure: true` explicitly. While these may be defaults, they should be explicit.

### Configuration

**31. No Environment-Specific Error Handling**

Error pages show the same level of detail in all environments. Production should hide implementation details.

---

## Positive Observations

Despite the issues, there are several things done well:

1. **Clean Context Boundaries**: The separation between `Accounts` and `Knowledge` is clear and appropriate. No god objects or context bleeding.

2. **Good Migration Hygiene**: Migrations are properly named, sequential, and use appropriate Ecto conventions. The incremental approach (adding `snippet`, then `language`) shows proper schema evolution.

3. **Proper Use of Changesets**: Validation logic is in the schema modules where it belongs, using changesets appropriately.

4. **LiveView Component Organization**: The form component is separated from the index view, which is the right pattern for complex forms.

5. **Good SQL Practices**: Queries use parameterized inputs, avoiding SQL injection. The use of `preload` and `join` shows understanding of N+1 issues.

6. **Reasonable UI/UX Considerations**: The mobile filters, tag autocomplete, and search functionality show attention to user experience.

7. **Test Fixtures Exist**: There's a fixture pattern in place, making it easy to create test data. This is better than many codebases.

8. **Password Hashing Done Right**: Bcrypt with proper salt is used. Passwords aren't stored in plaintext (obvious, but worth noting given other security issues).

9. **Release Module for Production**: The presence of `Share.Release` shows planning for production deployment and migrations.

10. **Proper Git Hygiene**: `.gitignore` is comprehensive and appropriate. No build artifacts or vendor dependencies in the repo.

---

## Technical Debt Assessment

**Overall Debt Level: Moderate to High**

The application has accumulated technical debt in several areas:

### Immediate Debt (Prevents Production Use)
- Authentication/authorization system (3-5 days to fix properly)
- Database referential integrity (1 day)
- Failing tests (1 day)

### Short-Term Debt (Should Fix Soon)
- Security vulnerabilities (timing attacks, secrets management) (2 days)
- Missing authorization checks (2 days)
- N+1 queries and missing indexes (1 day)

### Long-Term Debt (Can Defer)
- Lack of typespecs (ongoing)
- Stream-based LiveView (1 day when needed)
- Caching strategy (1 day)
- Soft delete implementation (2 days if needed)

**Estimated Effort to Production-Ready:** 10-15 days of focused development work.

The codebase shows signs of being a learning project or quick prototype that evolved without proper security review. The bones are good, but it needs significant hardening before production deployment.
