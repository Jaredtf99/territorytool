import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.108.2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function textResponse(body: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: { ...corsHeaders, "Content-Type": "text/plain; charset=utf-8" },
  });
}

export function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable ${name}`);
  }
  return value;
}

export function adminClient(): SupabaseClient {
  return createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
}

export function anonClient(): SupabaseClient {
  return createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_ANON_KEY"),
    {
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
}

export async function authenticatedClient(
  req: Request,
): Promise<{ client: SupabaseClient; userId: string }> {
  const authorization = req.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) {
    throw new Response(JSON.stringify({ error: "UNAUTHENTICATED" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const client = createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_ANON_KEY"),
    {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );

  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) {
    throw new Response(JSON.stringify({ error: "UNAUTHENTICATED" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return { client, userId: data.user.id };
}

export async function readJson<T>(req: Request): Promise<T> {
  try {
    return await req.json() as T;
  } catch {
    throw new Response(JSON.stringify({ error: "INVALID_JSON" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

export async function ensureAdmin(
  userId: string,
): Promise<"SUPERADMIN" | "ADMIN"> {
  const supabase = adminClient();
  const { data, error } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .single();

  if (error || !data || !["SUPERADMIN", "ADMIN"].includes(data.role)) {
    throw new Response(JSON.stringify({ error: "FORBIDDEN" }), {
      status: 403,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return data.role as "SUPERADMIN" | "ADMIN";
}

// --- Multi-congregation context helpers ---

export type MemberRole = "ADMIN" | "USER";

export type ActorContext = {
  userId: string;
  isSuperadmin: boolean;
  congregationId: string | null;
  roleInCongregation: MemberRole | null;
};

function forbidden(): Response {
  return new Response(JSON.stringify({ error: "FORBIDDEN" }), {
    status: 403,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Resolves the caller's role within their currently active congregation.
export async function getActorContext(userId: string): Promise<ActorContext> {
  const supabase = adminClient();
  const { data: profile } = await supabase
    .from("profiles")
    .select("is_superadmin, active_congregation_id")
    .eq("id", userId)
    .single();

  const isSuperadmin = profile?.is_superadmin ?? false;
  const congregationId = profile?.active_congregation_id ?? null;

  let roleInCongregation: MemberRole | null = null;
  if (congregationId) {
    const { data: membership } = await supabase
      .from("congregation_members")
      .select("role")
      .eq("user_id", userId)
      .eq("congregation_id", congregationId)
      .maybeSingle();
    roleInCongregation = (membership?.role as MemberRole | undefined) ?? null;
  }

  return { userId, isSuperadmin, congregationId, roleInCongregation };
}

export function isCongregationAdmin(ctx: ActorContext): boolean {
  return ctx.isSuperadmin || ctx.roleInCongregation === "ADMIN";
}

// Requires the caller to be an admin (superadmin or congregation ADMIN) with an
// active congregation. Returns the resolved context.
export async function ensureCongregationAdmin(
  req: Request,
): Promise<ActorContext> {
  const { userId } = await authenticatedClient(req);
  const ctx = await getActorContext(userId);
  if (!ctx.congregationId || !isCongregationAdmin(ctx)) {
    throw forbidden();
  }
  return ctx;
}

// Requires any member (or superadmin) with an active congregation.
export async function ensureCongregationMember(
  req: Request,
): Promise<ActorContext> {
  const { userId } = await authenticatedClient(req);
  const ctx = await getActorContext(userId);
  if (!ctx.congregationId || (!ctx.isSuperadmin && !ctx.roleInCongregation)) {
    throw forbidden();
  }
  return ctx;
}
