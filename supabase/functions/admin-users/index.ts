import {
  adminClient,
  corsHeaders,
  ensureCongregationAdmin,
  jsonResponse,
  readJson,
  type ActorContext,
  type MemberRole,
} from "../_shared/http.ts";

type RequestBody =
  | { action: "create"; username: string; password: string; role?: MemberRole }
  | { action: "add-member"; username: string; role?: MemberRole }
  | { action: "update"; userId: string; username: string; role: MemberRole }
  | { action: "delete"; userId: string }
  | { action: "change-password"; userId: string; newPassword: string }
  | { action: "list" };

const INTERNAL_DOMAIN = "users.territorytool.invalid";

function internalEmail(userId: string): string {
  return `u_${userId.replaceAll("-", "")}@${INTERNAL_DOMAIN}`;
}

function isMemberRole(value: unknown): value is MemberRole {
  return value === "ADMIN" || value === "USER";
}

type TargetInfo = {
  exists: boolean;
  isSuperadmin: boolean;
  roleInCongregation: MemberRole | null;
};

async function getTarget(userId: string, congregationId: string): Promise<TargetInfo> {
  const supabase = adminClient();
  const { data: profile } = await supabase
    .from("profiles")
    .select("is_superadmin")
    .eq("id", userId)
    .maybeSingle();

  if (!profile) return { exists: false, isSuperadmin: false, roleInCongregation: null };

  const { data: membership } = await supabase
    .from("congregation_members")
    .select("role")
    .eq("user_id", userId)
    .eq("congregation_id", congregationId)
    .maybeSingle();

  return {
    exists: true,
    isSuperadmin: profile.is_superadmin ?? false,
    roleInCongregation: (membership?.role as MemberRole | undefined) ?? null,
  };
}

// Whether the actor may manage the target member within the active congregation.
function canManage(actor: ActorContext, target: TargetInfo): boolean {
  if (target.isSuperadmin) return false; // global superadmins are not managed here
  if (actor.isSuperadmin) return true;
  // Congregation ADMIN may only manage USER members of the congregation.
  return target.roleInCongregation === "USER";
}

// Whether the actor may assign the given role within the active congregation.
function canAssignRole(actor: ActorContext, role: MemberRole): boolean {
  if (role === "ADMIN") return actor.isSuperadmin;
  return true;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const actor = await ensureCongregationAdmin(req);
    const congregationId = actor.congregationId!;
    const supabase = adminClient();
    const body = await readJson<RequestBody>(req);

    if (body.action === "list") {
      const { data, error } = await supabase
        .from("congregation_members")
        .select("role, profiles!inner(id, username, must_change_password)")
        .eq("congregation_id", congregationId);
      if (error) throw error;

      const users = (data ?? []).map((row) => {
        const profile = row.profiles as unknown as {
          id: string;
          username: string;
          must_change_password: boolean;
        };
        return {
          id: profile.id,
          username: profile.username,
          role: row.role,
          must_change_password: profile.must_change_password,
        };
      }).sort((a, b) => a.username.localeCompare(b.username));

      return jsonResponse(users);
    }

    if (body.action === "create") {
      const role: MemberRole = body.role ?? "USER";
      if (!body.username || !body.password || !isMemberRole(role)) {
        return jsonResponse({ error: "INVALID_PARAMETERS" }, 400);
      }
      if (!canAssignRole(actor, role)) {
        return jsonResponse({ error: "FORBIDDEN" }, 403);
      }

      const provisionalId = crypto.randomUUID();
      const authEmail = internalEmail(provisionalId);
      const { data: created, error: createError } = await supabase.auth.admin.createUser({
        email: authEmail,
        password: body.password,
        email_confirm: true,
      });
      if (createError || !created.user) {
        return jsonResponse({ error: createError?.message ?? "CREATE_USER_FAILED" }, 400);
      }

      const finalEmail = internalEmail(created.user.id);
      if (finalEmail !== authEmail) {
        const { error: updateEmailError } = await supabase.auth.admin.updateUserById(created.user.id, {
          email: finalEmail,
          email_confirm: true,
        });
        if (updateEmailError) throw updateEmailError;
      }

      const { error: profileError } = await supabase.from("profiles").insert({
        id: created.user.id,
        username: body.username,
        auth_email: finalEmail,
        role,
        must_change_password: true,
        active_congregation_id: congregationId,
      });
      if (profileError) {
        await supabase.auth.admin.deleteUser(created.user.id);
        return jsonResponse({ error: profileError.message }, 400);
      }

      const { error: memberError } = await supabase.from("congregation_members").insert({
        user_id: created.user.id,
        congregation_id: congregationId,
        role,
      });
      if (memberError) {
        await supabase.auth.admin.deleteUser(created.user.id);
        return jsonResponse({ error: memberError.message }, 400);
      }

      return jsonResponse({ userId: created.user.id });
    }

    // Add an already-existing user (by username) to the active congregation.
    if (body.action === "add-member") {
      const role: MemberRole = body.role ?? "USER";
      if (!body.username || !isMemberRole(role)) {
        return jsonResponse({ error: "INVALID_PARAMETERS" }, 400);
      }
      if (!canAssignRole(actor, role)) {
        return jsonResponse({ error: "FORBIDDEN" }, 403);
      }

      const { data: profile } = await supabase
        .from("profiles")
        .select("id")
        .ilike("username", body.username.trim())
        .maybeSingle();
      if (!profile) return jsonResponse({ error: "USER_NOT_FOUND" }, 404);

      const { error } = await supabase
        .from("congregation_members")
        .upsert(
          { user_id: profile.id, congregation_id: congregationId, role },
          { onConflict: "user_id,congregation_id" },
        );
      if (error) return jsonResponse({ error: error.message }, 400);

      return jsonResponse({ userId: profile.id });
    }

    if (body.action === "update") {
      if (!body.userId || !body.username || !isMemberRole(body.role)) {
        return jsonResponse({ error: "INVALID_PARAMETERS" }, 400);
      }
      if (!canAssignRole(actor, body.role)) {
        return jsonResponse({ error: "FORBIDDEN" }, 403);
      }

      const target = await getTarget(body.userId, congregationId);
      if (!target.exists || target.roleInCongregation === null) {
        return jsonResponse({ error: "USER_NOT_FOUND" }, 404);
      }
      if (!canManage(actor, target)) return jsonResponse({ error: "FORBIDDEN" }, 403);

      const { error: nameError } = await supabase
        .from("profiles")
        .update({ username: body.username })
        .eq("id", body.userId);
      if (nameError) return jsonResponse({ error: nameError.message }, 400);

      const { error: roleError } = await supabase
        .from("congregation_members")
        .update({ role: body.role })
        .eq("user_id", body.userId)
        .eq("congregation_id", congregationId);
      if (roleError) return jsonResponse({ error: roleError.message }, 400);

      return jsonResponse({ ok: true });
    }

    // Remove a member from the active congregation (does not delete the account).
    if (body.action === "delete") {
      if (!body.userId) return jsonResponse({ error: "INVALID_PARAMETERS" }, 400);

      const target = await getTarget(body.userId, congregationId);
      if (!target.exists || target.roleInCongregation === null) {
        return jsonResponse({ error: "USER_NOT_FOUND" }, 404);
      }
      if (!canManage(actor, target)) return jsonResponse({ error: "FORBIDDEN" }, 403);

      const { error } = await supabase
        .from("congregation_members")
        .delete()
        .eq("user_id", body.userId)
        .eq("congregation_id", congregationId);
      if (error) return jsonResponse({ error: error.message }, 400);

      // If the removed user had this congregation active, clear/reassign it.
      const { data: remaining } = await supabase
        .from("congregation_members")
        .select("congregation_id")
        .eq("user_id", body.userId)
        .limit(1)
        .maybeSingle();
      await supabase
        .from("profiles")
        .update({ active_congregation_id: remaining?.congregation_id ?? null })
        .eq("id", body.userId)
        .eq("active_congregation_id", congregationId);

      return jsonResponse({ ok: true });
    }

    if (body.action === "change-password") {
      if (!body.userId || !body.newPassword) {
        return jsonResponse({ error: "INVALID_PARAMETERS" }, 400);
      }

      const target = await getTarget(body.userId, congregationId);
      if (!target.exists || target.roleInCongregation === null) {
        return jsonResponse({ error: "USER_NOT_FOUND" }, 404);
      }
      if (!canManage(actor, target)) return jsonResponse({ error: "FORBIDDEN" }, 403);

      const { error } = await supabase.auth.admin.updateUserById(body.userId, {
        password: body.newPassword,
      });
      if (error) return jsonResponse({ error: error.message }, 400);

      await supabase.from("profiles").update({ must_change_password: true }).eq("id", body.userId);
      return jsonResponse({ ok: true });
    }

    return jsonResponse({ error: "INVALID_ACTION" }, 400);
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("admin-users failed", error);
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
