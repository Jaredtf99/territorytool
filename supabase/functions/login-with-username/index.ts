import { adminClient, anonClient, corsHeaders, jsonResponse, readJson } from "../_shared/http.ts";

type LoginRequest = {
  username?: string;
  password?: string;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  try {
    const { username, password } = await readJson<LoginRequest>(req);
    if (!username || !password) {
      return jsonResponse({ error: "WRONG_USERNAME_PASSWORD" }, 400);
    }

    const admin = adminClient();
    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("id, username, auth_email, role, must_change_password, is_superadmin, active_congregation_id")
      .ilike("username", username.trim())
      .single();

    if (profileError || !profile?.auth_email) {
      return jsonResponse({ error: "WRONG_USERNAME_PASSWORD" }, 400);
    }

    const auth = anonClient();
    const { data, error } = await auth.auth.signInWithPassword({
      email: profile.auth_email,
      password,
    });

    if (error || !data.session) {
      return jsonResponse({ error: "WRONG_USERNAME_PASSWORD" }, 400);
    }

    // Congregations the user can operate in (all of them for superadmins).
    let congregations: Array<{ id: string; name: string; role: string; is_active: boolean }> = [];
    if (profile.is_superadmin) {
      const { data: all } = await admin.from("congregations").select("id, name").order("name");
      congregations = (all ?? []).map((c) => ({
        id: c.id,
        name: c.name,
        role: "SUPERADMIN",
        is_active: c.id === profile.active_congregation_id,
      }));
    } else {
      const { data: memberships } = await admin
        .from("congregation_members")
        .select("role, congregations!inner(id, name)")
        .eq("user_id", profile.id);
      congregations = (memberships ?? [])
        .map((row) => {
          const c = row.congregations as unknown as { id: string; name: string };
          return {
            id: c.id,
            name: c.name,
            role: row.role as string,
            is_active: c.id === profile.active_congregation_id,
          };
        })
        .sort((a, b) => a.name.localeCompare(b.name));
    }

    return jsonResponse({
      session: data.session,
      user: data.user,
      profile: {
        id: profile.id,
        username: profile.username,
        role: profile.role,
        is_superadmin: profile.is_superadmin,
        must_change_password: profile.must_change_password,
        active_congregation_id: profile.active_congregation_id,
      },
      congregations,
      token: data.session.access_token,
    });
  } catch (error) {
    if (error instanceof Response) {
      return error;
    }

    console.error("login-with-username failed", error);
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
