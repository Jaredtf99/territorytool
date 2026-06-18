#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const SQLITE_PATH = process.env.SQLITE_PATH ?? "TerritoryTool.db-2";
const TEMP_PASSWORD = process.env.TEMP_PASSWORD ?? `Temp-${crypto.randomUUID().slice(0, 8)}!`;
const IMAGE_BASE_DIR = process.env.IMAGE_BASE_DIR;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  throw new Error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before running this script.");
}

function sqliteJson(sql) {
  const output = execFileSync("sqlite3", ["-json", SQLITE_PATH, sql], { encoding: "utf8" }).trim();
  return output ? JSON.parse(output) : [];
}

async function supabaseFetch(pathname, options = {}) {
  const response = await fetch(`${SUPABASE_URL}${pathname}`, {
    ...options,
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      ...(options.headers ?? {}),
    },
  });

  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`${options.method ?? "GET"} ${pathname} failed: ${response.status} ${text}`);
  }
  return body;
}

async function restUpsert(table, rows, onConflict) {
  if (rows.length === 0) return;
  const query = new URLSearchParams({
    on_conflict: onConflict,
  });
  await supabaseFetch(`/rest/v1/${table}?${query}`, {
    method: "POST",
    headers: {
      Prefer: "resolution=merge-duplicates",
    },
    body: JSON.stringify(rows),
  });
}

async function restInsert(table, rows) {
  if (rows.length === 0) return;
  await supabaseFetch(`/rest/v1/${table}`, {
    method: "POST",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify(rows),
  });
}

async function createAuthUser(oldUser) {
  const existing = await supabaseFetch(`/rest/v1/profiles?username=eq.${encodeURIComponent(oldUser.UserName)}&select=id,auth_email`);
  if (existing.length > 0) {
    return { newAuthId: existing[0].id, authEmail: existing[0].auth_email };
  }

  const provisionalEmail = `u_${oldUser.Id.replaceAll("-", "")}@users.territorytool.invalid`;
  const user = await supabaseFetch("/auth/v1/admin/users", {
    method: "POST",
    body: JSON.stringify({
      email: provisionalEmail,
      password: TEMP_PASSWORD,
      email_confirm: true,
      user_metadata: {
        legacy_aspnet_id: oldUser.Id,
        username: oldUser.UserName,
      },
    }),
  });

  const finalEmail = `u_${user.id.replaceAll("-", "")}@users.territorytool.invalid`;
  if (finalEmail !== provisionalEmail) {
    await supabaseFetch(`/auth/v1/admin/users/${user.id}`, {
      method: "PUT",
      body: JSON.stringify({
        email: finalEmail,
        email_confirm: true,
      }),
    });
  }

  return { newAuthId: user.id, authEmail: finalEmail };
}

async function uploadImageIfPresent(territoryId, imgUrl) {
  if (!IMAGE_BASE_DIR || !imgUrl) return null;
  const normalized = imgUrl.replaceAll("\\", "/");
  const fileName = normalized.split("/").pop();
  if (!fileName) return null;
  const filePath = path.join(IMAGE_BASE_DIR, fileName);
  if (!existsSync(filePath)) return null;

  const objectPath = `${territoryId}/${fileName}`;
  const bytes = readFileSync(filePath);
  const response = await fetch(`${SUPABASE_URL}/storage/v1/object/territory-images/${objectPath}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "image/png",
      "x-upsert": "true",
    },
    body: bytes,
  });

  if (!response.ok) {
    const message = await response.text();
    console.warn(`Could not upload image for territory ${territoryId}: ${message}`);
    return null;
  }

  return objectPath;
}

async function main() {
  console.log(`Migrating ${SQLITE_PATH} to ${SUPABASE_URL}`);
  console.log(`Temporary password for migrated users: ${TEMP_PASSWORD}`);

  const roles = sqliteJson(`
    select ur.UserId, r.Name as Role
    from AspNetUserRoles ur
    join AspNetRoles r on r.Id = ur.RoleId
  `);
  const roleByUserId = new Map(roles.map((row) => [row.UserId, row.Role]));

  const users = sqliteJson(`select Id, UserName from AspNetUsers order by UserName`);
  const userMap = new Map();
  for (const user of users) {
    const created = await createAuthUser(user);
    userMap.set(user.Id, created.newAuthId);
    await restUpsert("profiles", [{
      id: created.newAuthId,
      username: user.UserName,
      auth_email: created.authEmail,
      role: roleByUserId.get(user.Id) ?? "USER",
      must_change_password: true,
    }], "id");
    await restUpsert("migration_user_map", [{
      old_aspnet_id: user.Id,
      new_auth_id: created.newAuthId,
    }], "old_aspnet_id");
  }

  const persons = sqliteJson(`select Id, Name, Enabled from Person order by Id`)
    .map((row) => ({
      id: row.Id,
      name: row.Name,
      enabled: Boolean(row.Enabled),
    }));
  await restUpsert("persons", persons, "id");

  const territoriesSource = sqliteJson(`select Id, Code, Name, MapUrl, ImgUrl from Territory order by Id`);
  const territories = [];
  for (const row of territoriesSource) {
    territories.push({
      id: row.Id,
      code: row.Code,
      name: row.Name,
      map_url: row.MapUrl,
      image_path: await uploadImageIfPresent(row.Id, row.ImgUrl),
      archived: false,
    });
  }
  await restUpsert("territories", territories, "id");

  const transactions = sqliteJson(`
    select Id, TerritoryId, PersonId, GivenBy, GivenDateUtc, IsAutomaticGivenDate,
           PickedBy, PickedDateUTC, IsAutomaticPickedDate
    from "Transaction"
    order by Id
  `).map((row) => ({
    id: row.Id,
    territory_id: row.TerritoryId,
    person_id: row.PersonId,
    given_by: userMap.get(row.GivenBy),
    given_at: new Date(row.GivenDateUtc).toISOString(),
    is_automatic_given_date: Boolean(row.IsAutomaticGivenDate),
    picked_by: row.PickedBy ? userMap.get(row.PickedBy) : null,
    picked_at: row.PickedDateUTC ? new Date(row.PickedDateUTC).toISOString() : null,
    is_automatic_picked_date: row.IsAutomaticPickedDate === null ? null : Boolean(row.IsAutomaticPickedDate),
  }));
  await restUpsert("territory_transactions", transactions, "id");

  const logs = sqliteJson(`
    select Id, UserId, DateTimeUTC, Message, ActionType, Successful
    from ActionLog
    order by Id
  `).map((row) => ({
    id: row.Id,
    user_id: userMap.get(row.UserId),
    created_at: new Date(row.DateTimeUTC).toISOString(),
    message: row.Message,
    action_type: row.ActionType,
    successful: Boolean(row.Successful),
  }));
  await restUpsert("action_logs", logs, "id");

  await supabaseFetch("/rest/v1/rpc/reset_migration_sequences", { method: "POST", body: "{}" });

  console.log("Migration finished.");
  console.log("Run scripts/validate-supabase-migration.mjs next.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
