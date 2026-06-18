#!/usr/bin/env node

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  throw new Error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before running this script.");
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
  return { body, headers: response.headers };
}

async function countRows(resource, filter = "") {
  const { headers } = await supabaseFetch(`/rest/v1/${resource}?select=*${filter}`, {
    headers: { Prefer: "count=exact", Range: "0-0" },
  });
  const contentRange = headers.get("content-range");
  return Number(contentRange?.split("/").at(1) ?? 0);
}

function expectEqual(name, actual, expected) {
  if (actual !== expected) {
    throw new Error(`${name}: expected ${expected}, got ${actual}`);
  }
  console.log(`ok - ${name}: ${actual}`);
}

async function main() {
  const intentionallyExcludedTransactionIds = [84];

  expectEqual("profiles", await countRows("profiles"), 4);
  expectEqual("persons", await countRows("persons"), 95);
  expectEqual("territories", await countRows("territories"), 125);
  expectEqual("territory_transactions", await countRows("territory_transactions"), 516 - intentionallyExcludedTransactionIds.length);
  expectEqual("action_logs", await countRows("action_logs"), 600);
  expectEqual("open transactions", await countRows("territory_transactions", "&picked_at=is.null"), 55);
  expectEqual("assigned territories from view", await countRows("territory_current_state", "&person_id=not.is.null"), 55);

  for (const id of intentionallyExcludedTransactionIds) {
    expectEqual(`intentionally excluded transaction ${id}`, await countRows("territory_transactions", `&id=eq.${id}`), 0);
  }

  const { body: openTransactions } = await supabaseFetch("/rest/v1/territory_transactions?select=territory_id&picked_at=is.null");
  const counts = new Map();
  for (const row of openTransactions) {
    counts.set(row.territory_id, (counts.get(row.territory_id) ?? 0) + 1);
  }
  const duplicates = [...counts.entries()].filter(([, count]) => count > 1);
  expectEqual("territories with multiple open transactions", duplicates.length, 0);

  console.log("Migration validation passed.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
