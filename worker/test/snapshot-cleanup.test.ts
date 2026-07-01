import assert from "node:assert/strict";
import { test } from "node:test";

import type { Env } from "../src/env";
import { cleanupIncompleteSnapshots } from "../src/snapshot-cleanup";

test("cleanupIncompleteSnapshots removes pending snapshots from worker snapshot tables", async () => {
  const db = new FakeD1Database({
    new_arrival_snapshots: [
      { id: 1, status: "pending", fetched_at: "2026-06-30T00:00:00.000Z" },
      { id: 2, status: "complete", fetched_at: "2026-06-30T00:00:00.000Z" },
      { id: 8, status: "pending", fetched_at: "2026-07-01T00:30:00.000Z" }
    ],
    bestseller_snapshots: [
      { id: 3, status: "pending", fetched_at: "2026-06-30T00:00:00.000Z" },
      { id: 7, status: "pending", fetched_at: "2026-06-30T00:00:00.000Z" },
      { id: 4, status: "complete", fetched_at: "2026-06-30T00:00:00.000Z" }
    ],
    popular_loan_snapshots: [
      { id: 5, status: "pending", fetched_at: "2026-06-30T00:00:00.000Z" },
      { id: 6, status: "complete", fetched_at: "2026-06-30T00:00:00.000Z" }
    ]
  });
  db.addBook("new_arrival_books", 1);
  db.addBook("new_arrival_books", 8);
  db.addBook("bestseller_books", 7);
  db.addBook("bestseller_books", 4);

  await cleanupIncompleteSnapshots(
    makeEnv(db as unknown as D1Database),
    new Date("2026-07-01T00:00:00.000Z")
  );

  assert.deepEqual(db.snapshotIDs("new_arrival_snapshots"), [2, 8]);
  assert.deepEqual(db.snapshotIDs("bestseller_snapshots"), [4]);
  assert.deepEqual(db.snapshotIDs("popular_loan_snapshots"), [6]);
  assert.deepEqual(db.bookSnapshotIDs("new_arrival_books"), [8]);
  assert.deepEqual(db.bookSnapshotIDs("bestseller_books"), [4]);
});

test("cleanupIncompleteSnapshots keeps complete snapshots with and without books", async () => {
  const db = new FakeD1Database({
    new_arrival_snapshots: [
      { id: 10, status: "complete", fetched_at: "2026-06-30T00:00:00.000Z" },
      { id: 11, status: "complete", fetched_at: "2026-06-30T00:00:00.000Z" }
    ],
    bestseller_snapshots: [
      { id: 20, status: "complete", fetched_at: "2026-06-30T00:00:00.000Z" }
    ],
    popular_loan_snapshots: [
      { id: 30, status: "complete", fetched_at: "2026-06-30T00:00:00.000Z" }
    ]
  });

  db.addBook("new_arrival_books", 10);
  db.addBook("bestseller_books", 20);

  await cleanupIncompleteSnapshots(
    makeEnv(db as unknown as D1Database),
    new Date("2026-07-01T00:00:00.000Z")
  );

  assert.deepEqual(db.snapshotIDs("new_arrival_snapshots"), [10, 11]);
  assert.deepEqual(db.snapshotIDs("bestseller_snapshots"), [20]);
  assert.deepEqual(db.snapshotIDs("popular_loan_snapshots"), [30]);
  assert.deepEqual(db.bookSnapshotIDs("new_arrival_books"), [10]);
  assert.deepEqual(db.bookSnapshotIDs("bestseller_books"), [20]);
});

function makeEnv(db: D1Database): Env {
  return {
    ALADIN_API_BASE_URL: "https://provider.example/api/",
    ALADIN_API_KEY: "test-aladin-key",
    DATA4LIBRARY_API_BASE_URL: "https://data4library.example/api/",
    DATA4LIBRARY_API_KEY: "test-data4library-key",
    DB: db
  };
}

interface SnapshotRow {
  id: number;
  status: string;
  fetched_at: string;
}

interface BookRow {
  snapshot_id: number;
}

class FakeD1Database {
  private readonly snapshots: Record<string, SnapshotRow[]>;
  private readonly books: Record<string, BookRow[]> = {
    new_arrival_books: [],
    bestseller_books: [],
    popular_loan_books: []
  };

  constructor(snapshots: Record<string, SnapshotRow[]>) {
    this.snapshots = snapshots;
  }

  prepare(query: string): FakeD1Statement {
    return new FakeD1Statement(this, query);
  }

  deleteIncompleteSnapshots(tableName: string, staleBeforeISOString: string): void {
    this.snapshots[tableName] = this.snapshots[tableName]
      .filter((snapshot) =>
        snapshot.status === "complete" || snapshot.fetched_at >= staleBeforeISOString
      );
  }

  deleteBooksForIncompleteSnapshots(
    bookTableName: string,
    snapshotTableName: string,
    staleBeforeISOString: string
  ): void {
    const incompleteSnapshotIDs = new Set(
      this.snapshots[snapshotTableName]
        .filter((snapshot) =>
          snapshot.status !== "complete" && snapshot.fetched_at < staleBeforeISOString
        )
        .map((snapshot) => snapshot.id)
    );
    this.books[bookTableName] = this.books[bookTableName]
      .filter((book) => !incompleteSnapshotIDs.has(book.snapshot_id));
  }

  snapshotIDs(tableName: string): number[] {
    return this.snapshots[tableName].map((snapshot) => snapshot.id);
  }

  addBook(tableName: string, snapshotID: number): void {
    this.books[tableName].push({ snapshot_id: snapshotID });
  }

  bookSnapshotIDs(tableName: string): number[] {
    return this.books[tableName].map((book) => book.snapshot_id);
  }
}

class FakeD1Statement {
  private values: unknown[] = [];

  constructor(
    private readonly db: FakeD1Database,
    private readonly query: string
  ) {}

  bind(...values: unknown[]): FakeD1Statement {
    this.values = values;
    return this;
  }

  async run(): Promise<unknown> {
    const tableName = this.query.match(/DELETE FROM (\w+)/)?.[1];

    if (!tableName) {
      throw new Error(`unexpected_query: ${this.query}`);
    }

    const snapshotTableName = this.query.match(/SELECT id\s+FROM (\w+)/)?.[1];
    const [staleBeforeISOString] = this.values.map(String);

    if (snapshotTableName) {
      this.db.deleteBooksForIncompleteSnapshots(tableName, snapshotTableName, staleBeforeISOString);
    } else {
      this.db.deleteIncompleteSnapshots(tableName, staleBeforeISOString);
    }

    return { success: true };
  }
}
