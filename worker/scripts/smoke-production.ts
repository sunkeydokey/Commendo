const DEFAULT_BASE_URL = "https://commendo-worker.sunkeydokey.workers.dev";
const DEFAULT_SEARCH_QUERY = "한강";
const DEFAULT_TIMEOUT_MS = 30_000;

type JsonObject = Record<string, unknown>;

interface SmokeResult {
  body: JsonObject;
  elapsedMs: number;
  headers: Headers;
  status: number;
}

interface SmokeContext {
  newArrivals?: JsonObject;
  trending?: JsonObject;
  search?: JsonObject;
}

const baseURL = normalizeBaseURL(process.env.COMMENDO_WORKER_BASE_URL ?? DEFAULT_BASE_URL);
const searchQuery = process.env.COMMENDO_SMOKE_QUERY ?? DEFAULT_SEARCH_QUERY;

async function main(): Promise<void> {
  const context: SmokeContext = {};

  context.newArrivals = await smokeEndpoint({
    name: "new-arrivals",
    path: "/books/new-arrivals?type=all&page=1&pageSize=1",
    expectedMaxAge: 10800,
    validate: validateNewArrivals
  });

  context.trending = await smokeEndpoint({
    name: "trending",
    path: "/books/trending?page=1&pageSize=1",
    expectedMaxAge: 10800,
    validate: validateTrending
  });

  context.search = await smokeEndpoint({
    name: "search",
    path: `/books/search?q=${encodeURIComponent(searchQuery)}&page=1&pageSize=1`,
    expectedMaxAge: 1800,
    validate: (body) => validateSearch(body, searchQuery)
  });

  const detailISBN = process.env.COMMENDO_SMOKE_DETAIL_ISBN ?? deriveDetailISBN(context);
  await smokeEndpoint({
    name: "detail",
    path: `/books/detail?isbn=${encodeURIComponent(detailISBN)}`,
    expectedMaxAge: 10800,
    validate: validateDetail
  });

  console.log("production smoke checks passed");
}

async function smokeEndpoint(options: {
  name: string;
  path: string;
  expectedMaxAge: number;
  validate: (body: JsonObject) => string;
}): Promise<JsonObject> {
  let firstBody: JsonObject | undefined;

  for (const attempt of [1, 2]) {
    const result = await fetchJSON(options.path);
    assertCacheControl(options.name, result.headers, options.expectedMaxAge);
    const summary = options.validate(result.body);

    if (attempt === 1) {
      firstBody = result.body;
    }

    console.log(formatResult({
      name: options.name,
      attempt,
      status: result.status,
      elapsedMs: result.elapsedMs,
      headers: result.headers,
      summary
    }));
  }

  if (!firstBody) {
    throw new Error(`${options.name}: first response was not captured`);
  }

  return firstBody;
}

async function fetchJSON(path: string): Promise<SmokeResult> {
  const url = new URL(path, baseURL);
  const startedAt = Date.now();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DEFAULT_TIMEOUT_MS);

  try {
    const response = await fetch(url, { signal: controller.signal });
    const elapsedMs = Date.now() - startedAt;
    const contentType = response.headers.get("content-type") ?? "";

    if (!response.ok) {
      throw new Error(`${url.pathname}: expected 2xx, got ${response.status}`);
    }

    if (!contentType.toLowerCase().includes("application/json")) {
      throw new Error(`${url.pathname}: expected JSON content-type, got ${contentType || "<missing>"}`);
    }

    const body = await response.json();

    if (!isObject(body)) {
      throw new Error(`${url.pathname}: expected JSON object body`);
    }

    if (typeof body.error === "string") {
      throw new Error(`${url.pathname}: response contains error=${body.error}`);
    }

    return {
      body,
      elapsedMs,
      headers: response.headers,
      status: response.status
    };
  } finally {
    clearTimeout(timeout);
  }
}

function validateNewArrivals(body: JsonObject): string {
  assertEqual(body.type, "all", "new-arrivals.type");
  assertEqual(body.page, 1, "new-arrivals.page");
  assertEqual(body.pageSize, 1, "new-arrivals.pageSize");
  assertPositiveNumber(body.totalResults, "new-arrivals.totalResults");

  const item = firstItem(body.items, "new-arrivals.items");
  const title = requiredString(item.title, "new-arrivals.items[0].title");
  requiredString(item.publisher, "new-arrivals.items[0].publisher");
  requiredDetailISBN(item, "new-arrivals.items[0]");
  return `items=1 total=${body.totalResults} title=${title}`;
}

function validateTrending(body: JsonObject): string {
  assertEqual(body.page, 1, "trending.page");
  assertEqual(body.pageSize, 1, "trending.pageSize");
  assertPositiveNumber(body.totalResults, "trending.totalResults");

  const item = firstItem(body.items, "trending.items");
  const title = requiredString(item.title, "trending.items[0].title");
  requiredString(item.publisher, "trending.items[0].publisher");
  requiredDetailISBN(item, "trending.items[0]");
  return `items=1 total=${body.totalResults} title=${title}`;
}

function validateSearch(body: JsonObject, expectedQuery: string): string {
  assertEqual(body.query, expectedQuery.trim(), "search.query");
  assertEqual(body.page, 1, "search.page");
  assertEqual(body.pageSize, 1, "search.pageSize");
  assertPositiveNumber(body.totalResults, "search.totalResults");

  const item = firstItem(body.items, "search.items");
  const title = requiredString(item.title, "search.items[0].title");
  requiredString(item.publisher, "search.items[0].publisher");
  requiredDetailISBN(item, "search.items[0]");
  return `items=1 total=${body.totalResults} title=${title}`;
}

function validateDetail(body: JsonObject): string {
  if (!isObject(body.item)) {
    throw new Error("detail.item: expected object");
  }

  const title = requiredString(body.item.title, "detail.item.title");
  requiredString(body.item.publisher, "detail.item.publisher");
  requiredDetailISBN(body.item, "detail.item");
  const relatedBooks = Array.isArray(body.item.relatedBooks) ? body.item.relatedBooks.length : 0;
  return `item=1 relatedBooks=${relatedBooks} title=${title}`;
}

function deriveDetailISBN(context: SmokeContext): string {
  for (const body of [context.newArrivals, context.search, context.trending]) {
    const isbn = body ? firstValidISBNFromBody(body) : null;

    if (isbn) {
      return isbn;
    }
  }

  throw new Error("detail: set COMMENDO_SMOKE_DETAIL_ISBN or ensure list/search smoke responses include a valid ISBN");
}

function firstValidISBNFromBody(body: JsonObject): string | null {
  if (Array.isArray(body.items)) {
    for (const item of body.items) {
      if (isObject(item)) {
        const isbn = validDetailISBN(item);

        if (isbn) {
          return isbn;
        }
      }
    }
  }

  return null;
}

function firstItem(value: unknown, label: string): JsonObject {
  if (!Array.isArray(value) || value.length === 0 || !isObject(value[0])) {
    throw new Error(`${label}: expected non-empty object array`);
  }

  return value[0];
}

function requiredDetailISBN(item: JsonObject, label: string): string {
  const isbn = validDetailISBN(item);

  if (!isbn) {
    throw new Error(`${label}: expected numeric 10 or 13 digit isbn/isbn13`);
  }

  return isbn;
}

function validDetailISBN(item: JsonObject): string | null {
  for (const key of ["isbn13", "isbn"]) {
    const value = item[key];

    if (typeof value === "string" && /^(?:\d{10}|\d{13})$/.test(value)) {
      return value;
    }
  }

  return null;
}

function requiredString(value: unknown, label: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${label}: expected non-empty string`);
  }

  return value;
}

function assertPositiveNumber(value: unknown, label: string): void {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
    throw new Error(`${label}: expected positive number`);
  }
}

function assertEqual(actual: unknown, expected: unknown, label: string): void {
  if (actual !== expected) {
    throw new Error(`${label}: expected ${String(expected)}, got ${String(actual)}`);
  }
}

function assertCacheControl(name: string, headers: Headers, expectedMaxAge: number): void {
  const cacheControl = headers.get("cache-control") ?? "";
  const normalized = cacheControl.toLowerCase();

  if (!normalized.includes("public") || !normalized.includes(`max-age=${expectedMaxAge}`)) {
    throw new Error(`${name}: expected cache-control public, max-age=${expectedMaxAge}; got ${cacheControl || "<missing>"}`);
  }
}

function formatResult(result: {
  name: string;
  attempt: number;
  status: number;
  elapsedMs: number;
  headers: Headers;
  summary: string;
}): string {
  const cacheControl = result.headers.get("cache-control") ?? "<missing>";
  const age = result.headers.get("age") ?? "-";
  const cfCacheStatus = result.headers.get("cf-cache-status") ?? "-";

  return [
    `[${result.name}#${result.attempt}]`,
    `status=${result.status}`,
    `elapsedMs=${result.elapsedMs}`,
    `cache-control="${cacheControl}"`,
    `age=${age}`,
    `cf-cache-status=${cfCacheStatus}`,
    result.summary
  ].join(" ");
}

function normalizeBaseURL(value: string): string {
  const url = new URL(value);
  url.pathname = url.pathname.replace(/\/+$/, "");
  url.search = "";
  url.hash = "";
  return url.toString();
}

function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`production smoke checks failed: ${message}`);
  process.exitCode = 1;
});
