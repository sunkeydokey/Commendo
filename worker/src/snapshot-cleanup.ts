import type { Env } from "./env";

interface SnapshotTable {
  snapshotTable: string;
  bookTable: string;
}

const SNAPSHOT_TABLES = [
  { snapshotTable: "new_arrival_snapshots", bookTable: "new_arrival_books" },
  { snapshotTable: "bestseller_snapshots", bookTable: "bestseller_books" },
  { snapshotTable: "popular_loan_snapshots", bookTable: "popular_loan_books" }
];

const STALE_SNAPSHOT_AGE_MS = 60 * 60 * 1000;

export async function cleanupIncompleteSnapshots(
  env: Env,
  staleBefore = new Date(Date.now() - STALE_SNAPSHOT_AGE_MS)
): Promise<void> {
  const staleBeforeISOString = staleBefore.toISOString();

  for (const table of SNAPSHOT_TABLES) {
    await cleanupSnapshotTable(env.DB, table, staleBeforeISOString);
  }
}

async function cleanupSnapshotTable(
  db: D1Database,
  table: SnapshotTable,
  staleBeforeISOString: string
): Promise<void> {
  await db.prepare(
    `DELETE FROM ${table.bookTable}
      WHERE snapshot_id IN (
        SELECT id
          FROM ${table.snapshotTable}
         WHERE status != 'complete'
           AND fetched_at < ?
      )`
  )
    .bind(staleBeforeISOString)
    .run();

  await db.prepare(
    `DELETE FROM ${table.snapshotTable}
      WHERE status != 'complete'
        AND fetched_at < ?`
  )
    .bind(staleBeforeISOString)
    .run();
}
