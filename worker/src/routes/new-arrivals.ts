import type { Env } from "../env";
import { json, parsePositiveInteger, RESPONSE_MAX_AGE_SECONDS } from "../http";

type NewArrivalType = "all" | "special";

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
  categoryName?: string;
  description?: string;
  priceStandard?: number;
  priceSales?: number;
  link?: string;
}

interface NewArrivalBook {
  title: string;
  author: string;
  publisher: string;
  publishedDate: string;
  isbn: string;
  isbn13: string;
  coverURL: string;
  categoryName: string;
  description: string;
  priceStandard: number;
  priceSales: number;
  link: string;
}

interface NewArrivalSnapshotRow {
  id: number;
  snapshot_date: string;
  fetched_at: string;
  item_count: number;
}

interface NewArrivalBookRow {
  title: string;
  author: string;
  publisher: string;
  published_date: string;
  isbn: string;
  isbn13: string;
  cover_url: string;
  category_name: string;
  description: string;
  price_standard: number;
  price_sales: number;
  link: string;
}

const NEW_ARRIVAL_LISTS: Record<NewArrivalType, string> = {
  all: "ItemNewAll",
  special: "ItemNewSpecial"
};

const NEW_ARRIVAL_MAX_ITEMS = 200;
const ALADIN_PAGE_SIZE = 50;

export async function handleNewArrivals(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  const url = new URL(request.url);
  const params = parseNewArrivalQuery(url.searchParams);

  if ("error" in params) {
    return json({ error: params.error }, 400);
  }

  const cacheKey = new Request(buildCacheKey(url, params.type, params.page, params.pageSize), {
    method: "GET"
  });
  const cached = await caches.default.match(cacheKey);

  if (cached) {
    return cached;
  }

  const snapshot = await getOrCreateSnapshot(env, params.type).catch((error) => {
    console.error(JSON.stringify({
      event: "new_arrival_snapshot_lazy_create_failed",
      type: params.type,
      message: error instanceof Error ? error.message : "unknown_error"
    }));
    return null;
  });

  if (!snapshot) {
    return json({ error: "new_arrivals_snapshot_unavailable" }, 503);
  }

  const offset = (params.page - 1) * params.pageSize;
  const rows = await env.DB.prepare(
    `SELECT title, author, publisher, published_date, isbn, isbn13, cover_url,
            category_name, description, price_standard, price_sales, link
       FROM new_arrival_books
      WHERE snapshot_id = ?
      ORDER BY rank ASC
      LIMIT ? OFFSET ?`
  )
    .bind(snapshot.id, params.pageSize, offset)
    .all<NewArrivalBookRow>();

  const response = json({
    type: params.type,
    page: params.page,
    pageSize: params.pageSize,
    totalResults: snapshot.item_count,
    snapshotDate: snapshot.snapshot_date,
    fetchedAt: snapshot.fetched_at,
    items: rows.results.map(bookFromRow)
  });

  response.headers.set("cache-control", `public, max-age=${RESPONSE_MAX_AGE_SECONDS}`);
  ctx.waitUntil(caches.default.put(cacheKey, response.clone()));
  return response;
}

export async function refreshNewArrivalSnapshots(env: Env): Promise<void> {
  const today = formatDate(new Date());

  for (const type of Object.keys(NEW_ARRIVAL_LISTS) as NewArrivalType[]) {
    try {
      const books = await fetchAladinNewArrivals(env, type);
      await saveSnapshot(env.DB, type, today, books);
      console.log(JSON.stringify({
        event: "new_arrival_snapshot_saved",
        type,
        count: books.length
      }));
    } catch (error) {
      console.error(JSON.stringify({
        event: "new_arrival_snapshot_failed",
        type,
        message: error instanceof Error ? error.message : "unknown_error"
      }));
    }
  }
}

async function getOrCreateSnapshot(env: Env, type: NewArrivalType): Promise<NewArrivalSnapshotRow | null> {
  const snapshot = await getLatestSnapshot(env.DB, type);

  if (snapshot) {
    return snapshot;
  }

  const books = await fetchAladinNewArrivals(env, type);
  await saveSnapshot(env.DB, type, formatDate(new Date()), books);
  return getLatestSnapshot(env.DB, type);
}

async function fetchAladinNewArrivals(env: Env, type: NewArrivalType): Promise<NewArrivalBook[]> {
  const books: NewArrivalBook[] = [];
  const totalPages = Math.ceil(NEW_ARRIVAL_MAX_ITEMS / ALADIN_PAGE_SIZE);

  for (let page = 1; page <= totalPages && books.length < NEW_ARRIVAL_MAX_ITEMS; page += 1) {
    const response = await fetch(buildAladinListUrl(env, type, page));

    if (!response.ok) {
      throw new Error(`aladin_list_request_failed_${response.status}`);
    }

    const payload = await response.json<AladinListResponse>();
    const items = Array.isArray(payload.item) ? payload.item : [];

    if (items.length === 0) {
      break;
    }

    books.push(...items.map(normalizeBook));

    if (items.length < ALADIN_PAGE_SIZE) {
      break;
    }
  }

  return books.slice(0, NEW_ARRIVAL_MAX_ITEMS);
}

function buildAladinListUrl(env: Env, type: NewArrivalType, page: number): string {
  const baseUrl = new URL(env.ALADIN_API_BASE_URL);
  const pathPrefix = baseUrl.pathname.endsWith("/") ? baseUrl.pathname.slice(0, -1) : baseUrl.pathname;
  baseUrl.pathname = `${pathPrefix}/ItemList.aspx`;
  baseUrl.searchParams.set("ttbkey", env.ALADIN_API_KEY);
  baseUrl.searchParams.set("QueryType", NEW_ARRIVAL_LISTS[type]);
  baseUrl.searchParams.set("SearchTarget", "Book");
  baseUrl.searchParams.set("Start", String(page));
  baseUrl.searchParams.set("MaxResults", String(ALADIN_PAGE_SIZE));
  baseUrl.searchParams.set("Cover", "Big");
  baseUrl.searchParams.set("output", "JS");
  baseUrl.searchParams.set("Version", "20131101");
  return baseUrl.toString();
}

async function saveSnapshot(
  db: D1Database,
  type: NewArrivalType,
  snapshotDate: string,
  books: NewArrivalBook[]
): Promise<void> {
  const snapshot = await db.prepare(
    `INSERT INTO new_arrival_snapshots (list_type, snapshot_date, fetched_at, item_count, status)
     VALUES (?, ?, ?, ?, 'pending')
     RETURNING id`
  )
    .bind(type, snapshotDate, new Date().toISOString(), books.length)
    .first<{ id: number }>();

  if (!snapshot) {
    throw new Error("new_arrival_snapshot_insert_failed");
  }

  const statements = books.map((book, index) => db.prepare(
    `INSERT INTO new_arrival_books (
       snapshot_id, rank, title, author, publisher, published_date, isbn, isbn13,
       cover_url, category_name, description, price_standard, price_sales, link
     )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(
      snapshot.id,
      index + 1,
      book.title,
      book.author,
      book.publisher,
      book.publishedDate,
      book.isbn,
      book.isbn13,
      book.coverURL,
      book.categoryName,
      book.description,
      book.priceStandard,
      book.priceSales,
      book.link
    ));

  for (let index = 0; index < statements.length; index += ALADIN_PAGE_SIZE) {
    await db.batch(statements.slice(index, index + ALADIN_PAGE_SIZE));
  }

  await db.prepare(
    `UPDATE new_arrival_snapshots
        SET status = 'complete'
      WHERE id = ?`
  )
    .bind(snapshot.id)
    .run();
}

async function getLatestSnapshot(
  db: D1Database,
  type: NewArrivalType
): Promise<NewArrivalSnapshotRow | null> {
  return db.prepare(
    `SELECT id, snapshot_date, fetched_at, item_count
       FROM new_arrival_snapshots
      WHERE list_type = ? AND status = 'complete'
      ORDER BY fetched_at DESC, id DESC
      LIMIT 1`
  )
    .bind(type)
    .first<NewArrivalSnapshotRow>();
}

function parseNewArrivalQuery(searchParams: URLSearchParams):
  | { type: NewArrivalType; page: number; pageSize: number }
  | { error: string } {
  const type = searchParams.get("type") ?? "all";

  if (type !== "all" && type !== "special") {
    return { error: "invalid_type" };
  }

  const page = parsePositiveInteger(searchParams.get("page") ?? "1");

  if (page === null) {
    return { error: "invalid_page" };
  }

  const pageSize = parsePositiveInteger(searchParams.get("pageSize") ?? "20");

  if (pageSize === null || pageSize > 20) {
    return { error: "invalid_page_size" };
  }

  return { type, page, pageSize };
}

function buildCacheKey(url: URL, type: NewArrivalType, page: number, pageSize: number): string {
  const cacheUrl = new URL(url.origin);
  cacheUrl.pathname = "/books/new-arrivals";
  cacheUrl.searchParams.set("type", type);
  cacheUrl.searchParams.set("page", String(page));
  cacheUrl.searchParams.set("pageSize", String(pageSize));
  return cacheUrl.toString();
}

function normalizeBook(item: AladinBookItem): NewArrivalBook {
  return {
    title: text(item.title),
    author: text(item.author),
    publisher: text(item.publisher),
    publishedDate: text(item.pubDate ?? item.pubdate),
    isbn: text(item.isbn),
    isbn13: text(item.isbn13),
    coverURL: text(item.cover),
    categoryName: text(item.categoryName),
    description: text(item.description),
    priceStandard: integer(item.priceStandard),
    priceSales: integer(item.priceSales),
    link: text(item.link)
  };
}

function bookFromRow(row: NewArrivalBookRow): NewArrivalBook {
  return {
    title: row.title,
    author: row.author,
    publisher: row.publisher,
    publishedDate: row.published_date,
    isbn: row.isbn,
    isbn13: row.isbn13,
    coverURL: row.cover_url,
    categoryName: row.category_name,
    description: row.description,
    priceStandard: row.price_standard,
    priceSales: row.price_sales,
    link: row.link
  };
}

function text(value: string | undefined): string {
  return value ?? "";
}

function integer(value: number | undefined): number {
  return typeof value === "number" && Number.isInteger(value) ? value : 0;
}

function formatDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}
