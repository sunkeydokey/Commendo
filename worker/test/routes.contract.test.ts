import assert from "node:assert/strict";
import { afterEach, test } from "node:test";

import type { Env } from "../src/env";
import { routeRequest } from "../src/router";

const originalCaches = Object.getOwnPropertyDescriptor(globalThis, "caches");
const originalFetch = globalThis.fetch;

afterEach(() => {
  if (originalCaches) {
    Object.defineProperty(globalThis, "caches", originalCaches);
  } else {
    Reflect.deleteProperty(globalThis, "caches");
  }

  globalThis.fetch = originalFetch;
});

test("GET /books/search hashes normalized query in cache key and normalizes provider books", async () => {
  const cache = installMockCache();
  const fetchCalls = installMockFetch({
    totalResults: 1,
    item: [{
      title: "Search Result",
      author: "Search Author",
      publisher: "Search Publisher",
      pubdate: "2024-05-03",
      isbn: "8960000000",
      isbn13: "9791190000001",
      cover: "http://image.example/cover.jpg",
      categoryName: "국내도서>문학",
      description: "Provider description",
      priceStandard: 15000,
      priceSales: 12000,
      link: "http://book.example/detail"
    }]
  });
  const ctx = new MockExecutionContext();

  const response = await routeRequest(
    new Request("https://commendo.example/books/search?q=%20han%20&page=2&pageSize=3"),
    makeEnv(),
    ctx as unknown as ExecutionContext
  );
  await ctx.drain();

  assert.equal(response.status, 200);
  const body = await response.json() as {
    query: string;
    page: number;
    pageSize: number;
    totalResults: number;
    items: Array<{
      title: string;
      publishedDate: string;
      coverURL: string;
      link: string;
      priceStandard: number;
      priceSales: number;
    }>;
  };

  assert.equal(body.query, "han");
  assert.equal(body.page, 2);
  assert.equal(body.pageSize, 3);
  assert.equal(body.totalResults, 1);
  assert.equal(body.items[0].title, "Search Result");
  assert.equal(body.items[0].publishedDate, "2024-05-03");
  assert.equal(body.items[0].coverURL, "https://image.example/cover.jpg");
  assert.equal(body.items[0].link, "https://book.example/detail");
  assert.equal(body.items[0].priceStandard, 15000);
  assert.equal(body.items[0].priceSales, 12000);

  assert.equal(fetchCalls.length, 1);
  assert.equal(fetchCalls[0].searchParams.get("Query"), "han");
  assert.equal(fetchCalls[0].searchParams.get("Start"), "2");
  assert.equal(fetchCalls[0].searchParams.get("MaxResults"), "3");

  const expectedHash = await sha256("han");
  assert.equal(cache.matches.length, 1);
  assert.equal(cache.matches[0].url, `https://commendo.example/books/search?query=${expectedHash}&page=2&pageSize=3`);
  assert.equal(cache.puts.length, 1);
  assert.equal(cache.puts[0].request.url, cache.matches[0].url);
});

test("GET /books/trending lazily snapshots normalized provider books and keys cache by snapshot", async () => {
  const cache = installMockCache();
  const fetchCalls = installMockFetch({
    item: [{
      title: "Trending Result",
      author: "Trend Author",
      publisher: "Trend Publisher",
      pubdate: "2023-11-01",
      isbn: "9791190000002",
      cover: "http://image.example/trending.jpg",
      link: "http://book.example/trending",
      bestRank: "7"
    }]
  });
  const db = new FakeD1Database(42);
  const ctx = new MockExecutionContext();

  const response = await routeRequest(
    new Request("https://commendo.example/books/trending?page=1&pageSize=1"),
    makeEnv(db as unknown as D1Database),
    ctx as unknown as ExecutionContext
  );
  await ctx.drain();

  assert.equal(response.status, 200);
  const body = await response.json() as {
    page: number;
    pageSize: number;
    totalResults: number;
    items: Array<{
      rank: number;
      title: string;
      authors: string;
      publisher: string;
      publicationYear: string;
      isbn13: string;
      coverURL: string;
      detailURL: string;
      loanCount: number;
    }>;
  };

  assert.equal(body.page, 1);
  assert.equal(body.pageSize, 1);
  assert.equal(body.totalResults, 1);
  assert.deepEqual(body.items[0], {
    rank: 7,
    title: "Trending Result",
    authors: "Trend Author",
    publisher: "Trend Publisher",
    publicationYear: "2023",
    isbn13: "9791190000002",
    coverURL: "https://image.example/trending.jpg",
    detailURL: "http://book.example/trending",
    loanCount: 0
  });

  assert.equal(fetchCalls.length, 1);
  assert.equal(fetchCalls[0].pathname, "/api/ItemList.aspx");
  assert.equal(fetchCalls[0].searchParams.get("QueryType"), "Bestseller");
  assert.equal(fetchCalls[0].searchParams.get("MaxResults"), "20");

  assert.equal(cache.matches.length, 1);
  assert.equal(cache.matches[0].url, "https://commendo.example/books/trending?snapshot=42&page=1&pageSize=1");
  assert.equal(cache.puts.length, 1);
  assert.equal(cache.puts[0].request.url, cache.matches[0].url);
});

function makeEnv(db: D1Database = new FakeD1Database() as unknown as D1Database): Env {
  return {
    ALADIN_API_BASE_URL: "https://provider.example/api/",
    ALADIN_API_KEY: "test-aladin-key",
    DATA4LIBRARY_API_BASE_URL: "https://data4library.example/api/",
    DATA4LIBRARY_API_KEY: "test-data4library-key",
    DB: db
  };
}

function installMockCache(): MockCache {
  const cache = new MockCache();
  Object.defineProperty(globalThis, "caches", {
    configurable: true,
    value: { default: cache }
  });
  return cache;
}

function installMockFetch(payload: unknown): URL[] {
  const calls: URL[] = [];
  globalThis.fetch = async (input: RequestInfo | URL) => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    calls.push(url);
    return Response.json(payload);
  };
  return calls;
}

class MockCache {
  readonly matches: Request[] = [];
  readonly puts: Array<{ request: Request; response: Response }> = [];

  async match(request: Request): Promise<Response | undefined> {
    this.matches.push(request);
    return undefined;
  }

  async put(request: Request, response: Response): Promise<void> {
    this.puts.push({ request, response });
  }
}

class MockExecutionContext {
  private readonly promises: Array<Promise<unknown>> = [];

  waitUntil(promise: Promise<unknown>): void {
    this.promises.push(promise);
  }

  passThroughOnException(): void {}

  async drain(): Promise<void> {
    await Promise.all(this.promises);
  }
}

interface SnapshotRow {
  id: number;
  period_start: string;
  period_end: string;
  fetched_at: string;
  item_count: number;
  content_hash: string;
  status: string;
}

interface BookRow {
  snapshot_id: number;
  rank: number;
  title: string;
  authors: string;
  publisher: string;
  publication_year: string;
  isbn13: string;
  cover_url: string;
  detail_url: string;
}

class FakeD1Database {
  readonly snapshots: SnapshotRow[] = [];
  readonly books: BookRow[] = [];

  constructor(private readonly firstSnapshotID = 1) {}

  prepare(query: string): FakeD1Statement {
    return new FakeD1Statement(this, query);
  }

  async batch(statements: FakeD1Statement[]): Promise<unknown[]> {
    return Promise.all(statements.map((statement) => statement.run()));
  }

  nextSnapshotID(): number {
    return this.firstSnapshotID + this.snapshots.length;
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

  async first<T>(): Promise<T | null> {
    if (this.query.includes("SELECT id, period_start, period_end, fetched_at, item_count, content_hash")) {
      return (this.db.snapshots.find((snapshot) => snapshot.status === "complete") ?? null) as T | null;
    }

    if (this.query.includes("INSERT INTO bestseller_snapshots")) {
      const [periodStart, periodEnd, fetchedAt, itemCount, contentHash] = this.values;
      const snapshot = {
        id: this.db.nextSnapshotID(),
        period_start: String(periodStart),
        period_end: String(periodEnd),
        fetched_at: String(fetchedAt),
        item_count: Number(itemCount),
        content_hash: String(contentHash),
        status: "pending"
      };
      this.db.snapshots.push(snapshot);
      return { id: snapshot.id } as T;
    }

    return null;
  }

  async all<T>(): Promise<{ results: T[] }> {
    if (this.query.includes("FROM bestseller_books")) {
      const [snapshotID, limit, offset] = this.values.map(Number);
      const results = this.db.books
        .filter((book) => book.snapshot_id === snapshotID)
        .sort((left, right) => left.rank - right.rank)
        .slice(offset, offset + limit)
        .map(({ snapshot_id: _snapshotID, ...book }) => book as T);
      return { results };
    }

    return { results: [] };
  }

  async run(): Promise<unknown> {
    if (this.query.includes("INSERT INTO bestseller_books")) {
      const [
        snapshotID,
        rank,
        title,
        authors,
        publisher,
        publicationYear,
        isbn13,
        coverURL,
        detailURL
      ] = this.values;

      this.db.books.push({
        snapshot_id: Number(snapshotID),
        rank: Number(rank),
        title: String(title),
        authors: String(authors),
        publisher: String(publisher),
        publication_year: String(publicationYear),
        isbn13: String(isbn13),
        cover_url: String(coverURL),
        detail_url: String(detailURL)
      });
    }

    if (this.query.includes("UPDATE bestseller_snapshots")) {
      const [snapshotID] = this.values.map(Number);
      const snapshot = this.db.snapshots.find((candidate) => candidate.id === snapshotID);
      if (snapshot) {
        snapshot.status = "complete";
      }
    }

    return { success: true };
  }
}

async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}
