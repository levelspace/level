defmodule Bridge.Web.AuthTest do
  use Bridge.Web.ConnCase
  alias Bridge.Web.Auth

  setup %{conn: conn} do
    conn =
      conn
      |> put_launch_host()
      |> bypass_through(Bridge.Web.Router, :browser)
      |> get("/")

    {:ok, %{conn: conn}}
  end

  describe "fetch_team/2" do
    test "assigns the team to the connection if found", %{conn: conn} do
      {:ok, %{team: team}} = insert_signup()

      team_conn =
        conn
        |> assign(:subdomain, team.slug)
        |> Auth.fetch_team(repo: Repo)

      assert team_conn.assigns.team.id == team.id
    end

    test "raise a 404 if team is not found", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        conn
        |> assign(:subdomain, "doesnotexist")
        |> Auth.fetch_team(repo: Repo)
      end
    end
  end

  describe "fetch_current_user/2" do
    test "does not attach a current user when team is not specified",
      %{conn: conn} do

      conn =
        conn
        |> assign(:team, nil)
        |> Auth.fetch_current_user(repo: Repo)

      assert conn.assigns.current_user == nil
    end

    test "sets the current user to nil if there is no session", %{conn: conn} do
      conn = Auth.fetch_current_user(conn, repo: Repo)
      assert conn.assigns.current_user == nil
    end

    test "sets the current user to nil if a team is assigned but no sessions",
      %{conn: conn} do

      conn =
        conn
        |> assign(:team, "team")
        |> put_session(:sessions, nil)
        |> Auth.fetch_current_user(repo: Repo)

      assert conn.assigns.current_user == nil
    end

    test "sets the current user if logged in", %{conn: conn} do
      {:ok, %{team: team, user: user}} = insert_signup()

      conn =
        conn
        |> assign(:team, team)
        |> put_session(:sessions, to_user_session(team, user))
        |> Auth.fetch_current_user(repo: Repo)

      assert conn.assigns.current_user.id == user.id
    end
  end

  describe "sign_in/3" do
    setup %{conn: conn} do
      {:ok, %{team: team, user: user}} = insert_signup()

      conn =
        conn
        |> Auth.sign_in(team, user)

      {:ok, %{conn: conn, team: team, user: user}}
    end

    test "sets the current user", %{conn: conn, user: user} do
      assert conn.assigns.current_user.id == user.id
    end

    test "sets the user session", %{conn: conn, team: team, user: user} do
      team_id = Integer.to_string(team.id)

      %{^team_id => [user_id | _]} =
        conn
        |> get_session(:sessions)
        |> Poison.decode!

      assert user_id == user.id
    end
  end

  describe "sign_out/2" do
    test "signs out of the given team only", %{conn: conn} do
      team1 = %Bridge.Team{id: 1}
      team2 = %Bridge.Team{id: 2}

      user1 = %Bridge.User{id: 1}
      user2 = %Bridge.User{id: 2}

      conn =
        conn
        |> Auth.sign_in(team1, user1)
        |> Auth.sign_in(team2, user2)
        |> Auth.sign_out(team1)

      sessions =
        conn
        |> get_session(:sessions)
        |> Poison.decode!

      refute Map.has_key?(sessions, "1")
      assert Map.has_key?(sessions, "2")
    end
  end

  describe "sign_in_with_credentials/5" do
    setup %{conn: conn} do
      password = "$ecret$"
      {:ok, %{team: team, user: user}} = insert_signup(%{password: password})
      {:ok, %{conn: conn, team: team, user: user, password: password}}
    end

    test "signs in user with username credentials",
      %{conn: conn, team: team, user: user, password: password} do

      {:ok, conn} =
        Auth.sign_in_with_credentials(conn, team, user.username, password, repo: Repo)

      assert conn.assigns.current_user.id == user.id
    end

    test "signs in user with email credentials",
      %{conn: conn, team: team, user: user, password: password} do

      {:ok, conn} =
        Auth.sign_in_with_credentials(conn, team, user.email, password, repo: Repo)

      assert conn.assigns.current_user.id == user.id
    end

    test "returns unauthorized if password does not match",
      %{conn: conn, team: team, user: user} do

      {:error, :unauthorized, _conn} =
        Auth.sign_in_with_credentials(conn, team, user.email, "wrongo", repo: Repo)
    end

    test "returns unauthorized if user is not found",
      %{conn: conn, team: team} do

      {:error, :not_found, _conn} =
        Auth.sign_in_with_credentials(conn, team, "foo@bar.co", "wrongo", repo: Repo)
    end
  end

  defp to_user_session(team, user, ts \\ 123) do
    Poison.encode!(%{Integer.to_string(team.id) => [user.id, ts]})
  end
end