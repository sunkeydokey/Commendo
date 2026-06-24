import type { Env } from "../env";
import { json, parsePageQuery, RESPONSE_MAX_AGE_SECONDS } from "../http";

interface AladinListResponse {
  item?: AladinBookItem[];
}

interface AladinBookItem {
  title?: string;
  author?: string;
  publisher?: string;
  pubDate?: string;
  pubdate?: string;
  isbn?: string;
  isbn13?: string;
  cover?: string;
  link?: string;
  bestRank?: number;
}

interface PopularLoanBook {
  rank: number;
  title: string;
  authors: string;
  publisher: string;
  publicationYear: string;
  isbn13: string;
  coverURL: string;
  detailURL: string;
  loanCount: number;
}

interface PopularLoanSnapshotRow {
  id: number;
  period_start: string;
  period_end: string;
  fetched_at: string;
  item_count: number;
  content_hash: string;
}

interface PopularLoanBookRow {
  rank: number;
  title: string;
  authors: string;
  publisher: string;
  publication_year: string;
  isbn13: string;
  cover_url: string;
  detail_url: string;
  loan_count: number;
}

const POPULAR_LOAN_MAX_ITEMS = 20;
const DB_BATCH_SIZE = 50;

export async function handlePopularLoans(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  const url = new URL(request.url);
  const params = parsePageQuery(url.searchParams);

  if ("error" in params) {
    return json({ error: params.error }, 400);
  }

  const snapshot = await getOrCreateSnapshot(env).catch((error) => {
    console.error(JSON.stringify({
      event: "popular_loan_snapshot_lazy_create_failed",
      message: error instanceof Error ? error.message : "unknown_error"
    }));
    return null;
  });

  if (!snapshot) {
    return json({ error: "popular_loan_snapshot_unavailable" }, 503);
  }

  const cacheKey = new Request(buildCacheKey(url, snapshot.id, params.page, params.pageSize), {
    method: "GET"
  });
  const cached = await caches.default.match(cacheKey);

  if (cached) {
    return cached;
  }

  const offset = (params.page - 1) * params.pageSize;
  const rows = await env.DB.prepare(
    `SELECT rank, title, authors, publisher, publication_year, isbn13,
            cover_url, detail_url, loan_count
       FROM popular_loan_books
      WHERE snapshot_id = ?
      ORDER BY rank ASC
      LIMIT ? OFFSET ?`
  )
    .bind(snapshot.id, params.pageSize, offset)
    .all<PopularLoanBookRow>();

  const response = json({
    page: params.page,
    pageSize: params.pageSize,
    totalResults: snapshot.item_count,
    periodStart: snapshot.period_start,
    periodEnd: snapshot.period_end,
    fetchedAt: snapshot.fetched_at,
    items: rows.results.map(bookFromRow)
  });

  response.headers.set("cache-control", `public, max-age=${RESPONSE_MAX_AGE_SECONDS}`);
  ctx.waitUntil(caches.default.put(cacheKey, response.clone()));
  return response;
}

export async function refreshPopularLoanSnapshot(env: Env): Promise<void> {
  try {
    const snapshotDate = formatKoreanDate(new Date());
    const books = await fetchPopularLoans(env);
    const contentHash = await hashBooks(books);
    const latest = await getLatestSnapshot(env.DB);

    if (latest?.content_hash === contentHash) {
      console.log(JSON.stringify({
        event: "popular_loan_snapshot_unchanged",
        count: books.length
      }));
      return;
    }

    await saveSnapshot(env.DB, snapshotDate, snapshotDate, contentHash, books);
    console.log(JSON.stringify({
      event: "popular_loan_snapshot_saved",
      count: books.length
    }));
  } catch (error) {
    console.error(JSON.stringify({
      event: "popular_loan_snapshot_failed",
      message: error instanceof Error ? error.message : "unknown_error"
    }));
  }
}

async function getOrCreateSnapshot(env: Env): Promise<PopularLoanSnapshotRow | null> {
  const snapshot = await getLatestSnapshot(env.DB);

  if (snapshot && snapshot.period_start === snapshot.period_end) {
    return snapshot;
  }

  const snapshotDate = formatKoreanDate(new Date());
  const books = await fetchPopularLoans(env);
  const contentHash = await hashBooks(books);
  await saveSnapshot(env.DB, snapshotDate, snapshotDate, contentHash, books);
  return getLatestSnapshot(env.DB);
}

async function fetchPopularLoans(env: Env): Promise<PopularLoanBook[]> {
  const response = await fetch(buildProviderURL(env));

  if (!response.ok) {
    throw new Error(`aladin_bestseller_request_failed_${response.status}`);
  }

  const payload = await response.json<AladinListResponse>();
  const items = Array.isArray(payload.item) ? payload.item : [];
  const books = items
    .slice(0, POPULAR_LOAN_MAX_ITEMS)
    .map(normalizeBook);

  if (books.length === 0) {
    throw new Error("aladin_bestseller_empty_response");
  }

  return books;
}

function buildProviderURL(env: Env): string {
  const url = new URL(env.ALADIN_API_BASE_URL);
  const pathPrefix = url.pathname.endsWith("/") ? url.pathname.slice(0, -1) : url.pathname;
  url.pathname = `${pathPrefix}/ItemList.aspx`;
  url.searchParams.set("ttbkey", env.ALADIN_API_KEY);
  url.searchParams.set("QueryType", "Bestseller");
  url.searchParams.set("SearchTarget", "Book");
  url.searchParams.set("Start", "1");
  url.searchParams.set("MaxResults", String(POPULAR_LOAN_MAX_ITEMS));
  url.searchParams.set("Cover", "Big");
  url.searchParams.set("output", "JS");
  url.searchParams.set("Version", "20131101");
  return url.toString();
}

async function saveSnapshot(
  db: D1Database,
  periodStart: string,
  periodEnd: string,
  contentHash: string,
  books: PopularLoanBook[]
): Promise<void> {
  const snapshot = await db.prepare(
    `INSERT INTO popular_loan_snapshots (
       period_start, period_end, fetched_at, item_count, content_hash, status
     )
     VALUES (?, ?, ?, ?, ?, 'pending')
     RETURNING id`
  )
    .bind(periodStart, periodEnd, new Date().toISOString(), books.length, contentHash)
    .first<{ id: number }>();

  if (!snapshot) {
    throw new Error("popular_loan_snapshot_insert_failed");
  }

  try {
    const statements = books.map((book) => db.prepare(
      `INSERT INTO popular_loan_books (
         snapshot_id, rank, title, authors, publisher, publication_year, isbn13,
         cover_url, detail_url, loan_count
       )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
      .bind(
        snapshot.id,
        book.rank,
        book.title,
        book.authors,
        book.publisher,
        book.publicationYear,
        book.isbn13,
        book.coverURL,
        book.detailURL,
        book.loanCount
      ));

    for (let index = 0; index < statements.length; index += DB_BATCH_SIZE) {
      await db.batch(statements.slice(index, index + DB_BATCH_SIZE));
    }

    await db.prepare(
      `UPDATE popular_loan_snapshots
          SET status = 'complete'
        WHERE id = ?`
    )
      .bind(snapshot.id)
      .run();
  } catch (error) {
    await db.prepare("DELETE FROM popular_loan_snapshots WHERE id = ?")
      .bind(snapshot.id)
      .run();
    throw error;
  }
}

async function getLatestSnapshot(db: D1Database): Promise<PopularLoanSnapshotRow | null> {
  return db.prepare(
    `SELECT id, period_start, period_end, fetched_at, item_count, content_hash
       FROM popular_loan_snapshots
      WHERE status = 'complete'
      ORDER BY fetched_at DESC, id DESC
      LIMIT 1`
  )
    .first<PopularLoanSnapshotRow>();
}

function buildCacheKey(url: URL, snapshotID: number, page: number, pageSize: number): string {
  const cacheUrl = new URL(url.origin);
  cacheUrl.pathname = "/books/trending";
  cacheUrl.searchParams.set("snapshot", String(snapshotID));
  cacheUrl.searchParams.set("page", String(page));
  cacheUrl.searchParams.set("pageSize", String(pageSize));
  return cacheUrl.toString();
}

function normalizeBook(item: AladinBookItem, index: number): PopularLoanBook {
  return {
    rank: positiveInteger(item.bestRank) || index + 1,
    title: text(item.title),
    authors: text(item.author),
    publisher: text(item.publisher),
    publicationYear: publicationYear(item.pubDate ?? item.pubdate),
    isbn13: text(item.isbn13 ?? item.isbn),
    coverURL: secureURL(item.cover),
    detailURL: text(item.link),
    loanCount: 0
  };
}

function bookFromRow(row: PopularLoanBookRow): PopularLoanBook {
  return {
    rank: row.rank,
    title: row.title,
    authors: row.authors,
    publisher: row.publisher,
    publicationYear: row.publication_year,
    isbn13: row.isbn13,
    coverURL: secureURL(row.cover_url),
    detailURL: row.detail_url,
    loanCount: row.loan_count
  };
}

async function hashBooks(books: PopularLoanBook[]): Promise<string> {
  const bytes = new TextEncoder().encode(JSON.stringify(books));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function text(value: string | undefined): string {
  return value ?? "";
}

function secureURL(value: string | undefined): string {
  const url = text(value);
  return url.startsWith("http://") ? `https://${url.slice(7)}` : url;
}

function positiveInteger(value: string | number | undefined): number {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : 0;
}

function publicationYear(value: string | undefined): string {
  return text(value).slice(0, 4);
}

function formatKoreanDate(date: Date): string {
  return formatDate(new Date(date.getTime() + 9 * 60 * 60 * 1000));
}

function formatDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}
