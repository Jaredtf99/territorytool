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
  | { action: "create-undoable"; username: string; password: string; role?: MemberRole }
  | { action: "add-member"; username: string; role?: MemberRole }
  | { action: "update"; userId: string; username: string; role: MemberRole }
  | { action: "update-undoable"; userId: string; username: string; role: MemberRole }
  | { action: "delete"; userId: string }
  | { action: "delete-undoable"; userId: string }
  | { action: "change-password"; userId: string; newPassword: string }
  | { action: "undo"; undoId: string }
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

async function createUndoAction(
  supabase: ReturnType<typeof adminClient>,
  actor: ActorContext,
  actionType: string,
  payload: Record<string, unknown>,
): Promise<{ undoId: string; expiresAt: string }> {
  const { data, error } = await supabase
    .from("undoable_actions")
    .insert({
      action_type: actionType,
      entity_type: "user",
      actor_id: actor.userId,
      congregation_id: actor.congregationId,
      payload,
    })
    .select("id, created_at")
    .single();
  if (error || !data) throw error ?? new Error("UNDO_CREATE_FAILED");
  return {
    undoId: data.id as string,
    expiresAt: new Date(new Date(data.created_at as string).getTime() + 5000).toISOString(),
  };
}

async function markUndoConsumed(
  supabase: ReturnType<typeof adminClient>,
  undoId: string,
): Promise<void> {
  const { error } = await supabase
    .from("undoable_actions")
    .update({ consumed_at: new Date().toISOString() })
    .eq("id", undoId);
  if (error) throw error;
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

    if (body.action === "undo") {
      if (!body.undoId) return jsonResponse({ error: "INVALID_PARAMETERS" }, 400);

      const { data: undo, error: undoError } = await supabase
        .from("undoable_actions")
        .select("*")
        .eq("id", body.undoId)
        .maybeSingle();
      if (undoError) throw undoError;
      if (
        !undo ||
        undo.actor_id !== actor.userId ||
        undo.congregation_id !== congregationId ||
        undo.entity_type !== "user"
      ) {
        return jsonResponse({ error: "UNDO_NOT_FOUND" }, 404);
      }
      if (undo.consumed_at) return jsonResponse({ error: "UNDO_ALREADY_CONSUMED" }, 409);
      if (new Date(undo.expires_at).getTime() <= Date.now()) {
        return jsonResponse({ error: "UNDO_EXPIRED" }, 410);
      }

      const payload = undo.payload as Record<string, unknown>;

      if (undo.action_type === "add_user") {
        const userId = payload.userId as string;
        const { error: memberDeleteError } = await supabase
          .from("congregation_members")
          .delete()
          .eq("user_id", userId)
          .eq("congregation_id", congregationId);
        if (memberDeleteError) return jsonResponse({ error: memberDeleteError.message }, 400);

        const { count } = await supabase
          .from("congregation_members")
          .select("user_id", { count: "exact", head: true })
          .eq("user_id", userId);
        if ((count ?? 0) === 0) {
          const { error: deleteAuthError } = await supabase.auth.admin.deleteUser(userId);
          if (deleteAuthError) return jsonResponse({ error: deleteAuthError.message }, 400);
        } else {
          await supabase
            .from("profiles")
            .update({ active_congregation_id: null })
            .eq("id", userId)
            .eq("active_congregation_id", congregationId);
        }
      } else if (undo.action_type === "update_user") {
        const userId = payload.userId as string;
        const before = payload.before as { username: string; role: MemberRole };
        const after = payload.after as { username: string; role: MemberRole };

        const { data: currentProfile } = await supabase
          .from("profiles")
          .select("username")
          .eq("id", userId)
          .maybeSingle();
        const { data: currentMembership } = await supabase
          .from("congregation_members")
          .select("role")
          .eq("user_id", userId)
          .eq("congregation_id", congregationId)
          .maybeSingle();
        if (
          currentProfile?.username !== after.username ||
          currentMembership?.role !== after.role
        ) {
          return jsonResponse({ error: "UNDO_CONFLICT" }, 409);
        }

        const { error: profileError } = await supabase
          .from("profiles")
          .update({ username: before.username })
          .eq("id", userId);
        if (profileError) return jsonResponse({ error: profileError.message }, 400);

        const { error: memberError } = await supabase
          .from("congregation_members")
          .update({ role: before.role })
          .eq("user_id", userId)
          .eq("congregation_id", congregationId);
        if (memberError) return jsonResponse({ error: memberError.message }, 400);
      } else if (undo.action_type === "delete_user") {
        const userId = payload.userId as string;
        const role = payload.role as MemberRole;
        const previousActiveCongregationId = payload.previousActiveCongregationId as string | null;

        const { error: memberError } = await supabase
          .from("congregation_members")
          .upsert(
            { user_id: userId, congregation_id: congregationId, role },
            { onConflict: "user_id,congregation_id" },
          );
        if (memberError) return jsonResponse({ error: memberError.message }, 400);

        if (previousActiveCongregationId === congregationId) {
          const { error: activeError } = await supabase
            .from("profiles")
            .update({ active_congregation_id: congregationId })
            .eq("id", userId);
          if (activeError) return jsonResponse({ error: activeError.message }, 400);
        }
      } else {
        return jsonResponse({ error: "UNDO_UNSUPPORTED" }, 400);
      }

      await markUndoConsumed(supabase, body.undoId);
      return jsonResponse({ ok: true });
    }

    if (body.action === "create" || body.action === "create-undoable") {
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

      if (body.action === "create-undoable") {
        return jsonResponse(await createUndoAction(supabase, actor, "add_user", {
          userId: created.user.id,
          username: body.username,
          role,
          createdNewUser: true,
        }));
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

    if (body.action === "update" || body.action === "update-undoable") {
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

      const { data: beforeProfile } = await supabase
        .from("profiles")
        .select("username")
        .eq("id", body.userId)
        .single();

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

      if (body.action === "update-undoable") {
        return jsonResponse(await createUndoAction(supabase, actor, "update_user", {
          userId: body.userId,
          before: {
            username: beforeProfile?.username ?? body.username,
            role: target.roleInCongregation,
          },
          after: {
            username: body.username,
            role: body.role,
          },
        }));
      }
      return jsonResponse({ ok: true });
    }

    // Remove a member from the active congregation (does not delete the account).
    if (body.action === "delete" || body.action === "delete-undoable") {
      if (!body.userId) return jsonResponse({ error: "INVALID_PARAMETERS" }, 400);

      const target = await getTarget(body.userId, congregationId);
      if (!target.exists || target.roleInCongregation === null) {
        return jsonResponse({ error: "USER_NOT_FOUND" }, 404);
      }
      if (!canManage(actor, target)) return jsonResponse({ error: "FORBIDDEN" }, 403);

      const { data: beforeProfile } = await supabase
        .from("profiles")
        .select("active_congregation_id")
        .eq("id", body.userId)
        .single();

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

      if (body.action === "delete-undoable") {
        return jsonResponse(await createUndoAction(supabase, actor, "delete_user", {
          userId: body.userId,
          role: target.roleInCongregation,
          previousActiveCongregationId: beforeProfile?.active_congregation_id ?? null,
        }));
      }
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
