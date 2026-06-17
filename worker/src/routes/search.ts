import type { Env } from "../env";
import { json, parsePositiveInteger } from "../http";

interface AladinSearchResponse {
  totalResults?: number;
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

interface SearchBook {
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

const SEARCH_RESPONSE_MAX_AGE_SECONDS = 60 * 30;
const ALADIN_SEARCH_TIMEOUT_MS = 10_000;

export async function handleSearch(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  const url = new URL(request.url);
  const params = parseSearchQuery(url.searchParams);

  if ("error" in params) {
    return json({ error: params.error }, 400);
  }

  const cacheKey = new Request(
    await buildCacheKey(url, params.query, params.page, params.pageSize),
    { method: "GET" }
  );
  const cached = await caches.default.match(cacheKey);

  if (cached) {
    return cached;
  }

  let payload: AladinSearchResponse;

  try {
    const response = await fetch(buildAladinSearchURL(env, params.query, params.page, params.pageSize), {
      signal: AbortSignal.timeout(ALADIN_SEARCH_TIMEOUT_MS)
    });

    if (!response.ok) {
      throw new Error(`aladin_search_request_failed_${response.status}`);
    }

    payload = await response.json<AladinSearchResponse>();
  } catch (error) {
    console.error(JSON.stringify({
      event: "aladin_search_request_failed",
      message: error instanceof Error ? error.message : "unknown_error"
    }));
    return json({ error: "search_provider_unavailable" }, 502);
  }

  const items = Array.isArray(payload.item) ? payload.item : [];
  const response = json({
    query: params.query,
    page: params.page,
    pageSize: params.pageSize,
    totalResults: integer(payload.totalResults),
    fetchedAt: new Date().toISOString(),
    items: items.map(normalizeBook)
  });

  response.headers.set("cache-control", `public, max-age=${SEARCH_RESPONSE_MAX_AGE_SECONDS}`);
  ctx.waitUntil(caches.default.put(cacheKey, response.clone()));
  return response;
}

function parseSearchQuery(searchParams: URLSearchParams):
  | { query: string; page: number; pageSize: number }
  | { error: string } {
  const query = normalizeQuery(searchParams.get("q"));

  if (query === null) {
    return { error: "invalid_query" };
  }

  const page = parsePositiveInteger(searchParams.get("page") ?? "1");

  if (page === null) {
    return { error: "invalid_page" };
  }

  const pageSize = parsePositiveInteger(searchParams.get("pageSize") ?? "20");

  if (pageSize === null || pageSize > 20) {
    return { error: "invalid_page_size" };
  }

  return { query, page, pageSize };
}

function normalizeQuery(value: string | null): string | null {
  if (value === null) {
    return null;
  }

  const query = value.trim();
  return query.length >= 2 && query.length <= 50 ? query : null;
}

function buildAladinSearchURL(env: Env, query: string, page: number, pageSize: number): string {
  const url = new URL(env.ALADIN_API_BASE_URL);
  const pathPrefix = url.pathname.endsWith("/") ? url.pathname.slice(0, -1) : url.pathname;
  url.pathname = `${pathPrefix}/ItemSearch.aspx`;
  url.searchParams.set("ttbkey", env.ALADIN_API_KEY);
  url.searchParams.set("Query", query);
  url.searchParams.set("SearchTarget", "Book");
  url.searchParams.set("Start", String(page));
  url.searchParams.set("MaxResults", String(pageSize));
  url.searchParams.set("Cover", "Big");
  url.searchParams.set("output", "JS");
  url.searchParams.set("Version", "20131101");
  return url.toString();
}

async function buildCacheKey(
  url: URL,
  query: string,
  page: number,
  pageSize: number
): Promise<string> {
  const cacheUrl = new URL(url.origin);
  cacheUrl.pathname = "/books/search";
  cacheUrl.searchParams.set("query", await hashQuery(query));
  cacheUrl.searchParams.set("page", String(page));
  cacheUrl.searchParams.set("pageSize", String(pageSize));
  return cacheUrl.toString();
}

async function hashQuery(query: string): Promise<string> {
  const data = new TextEncoder().encode(query);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function normalizeBook(item: AladinBookItem): SearchBook {
  return {
    title: text(item.title),
    author: text(item.author),
    publisher: text(item.publisher),
    publishedDate: text(item.pubDate ?? item.pubdate),
    isbn: text(item.isbn),
    isbn13: text(item.isbn13),
    coverURL: secureURL(item.cover),
    categoryName: text(item.categoryName),
    description: text(item.description),
    priceStandard: integer(item.priceStandard),
    priceSales: integer(item.priceSales),
    link: secureURL(item.link)
  };
}

function text(value: string | undefined): string {
  return value ?? "";
}

function integer(value: number | undefined): number {
  return typeof value === "number" && Number.isInteger(value) ? value : 0;
}

function secureURL(value: string | undefined): string {
  return text(value).replace(/^http:\/\//, "https://");
}
