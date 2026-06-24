import type { Env } from "../env";
import { json, RESPONSE_MAX_AGE_SECONDS } from "../http";

interface AladinLookupResponse {
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
  categoryId?: number;
  categoryName?: string;
  description?: string;
  fullDescription?: string;
  priceStandard?: number;
  priceSales?: number;
  link?: string;
  customerReviewRank?: number;
  subInfo?: {
    itemPage?: number;
    toc?: string;
    story?: string;
  };
}

interface Data4LibraryRecommendationResponse {
  response?: {
    docs?: Array<{
      book?: Data4LibraryRecommendationItem;
      doc?: Data4LibraryRecommendationItem;
    }>;
  };
}

interface Data4LibraryRecommendationItem {
  bookname?: string;
  authors?: string;
  publisher?: string;
  publication_year?: string;
  isbn13?: string;
  bookImageURL?: string;
  bookDtlUrl?: string;
}

interface RelatedBook {
  title: string;
  authors: string;
  publisher: string;
  publicationYear: string;
  isbn13: string;
  coverURL: string | null;
  detailURL: string | null;
}

interface BookDetail {
  title: string;
  author: string;
  publisher: string;
  publishedDate: string;
  isbn: string;
  isbn13: string;
  coverURL: string;
  categoryId: number;
  categoryName: string;
  description: string;
  fullDescription: string;
  priceStandard: number;
  priceSales: number;
  link: string;
  customerReviewRank: number;
  itemPage: number;
  tableOfContents: string;
  story: string;
  relatedBooks: RelatedBook[];
}

const RELATED_BOOK_LIMIT = 20;
const ALADIN_DETAIL_TIMEOUT_MS = 10_000;
const RECOMMENDATION_TIMEOUT_MS = 10_000;

export async function handleBookDetail(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  const url = new URL(request.url);
  const isbn = parseISBN(url.searchParams.get("isbn"));

  if (isbn === null) {
    return json({ error: "invalid_isbn" }, 400);
  }

  const cacheKey = new Request(buildCacheKey(url, isbn), { method: "GET" });
  const cached = await caches.default.match(cacheKey);

  if (cached) {
    return cached;
  }

  let item: AladinBookItem | undefined;
  let relatedBooks: RelatedBook[] = [];
  let recommendationsAvailable = true;

  try {
    [item, relatedBooks] = await Promise.all([
      fetchAladinBookDetail(env, isbn),
      fetchReaderRecommendations(env, isbn).catch((error) => {
        recommendationsAvailable = false;
        console.error(JSON.stringify({
          event: "data4library_reader_recommendations_request_failed",
          message: error instanceof Error ? error.message : "unknown_error"
        }));
        return [];
      })
    ]);
  } catch (error) {
    console.error(JSON.stringify({
      event: "aladin_book_detail_request_failed",
      message: error instanceof Error ? error.message : "unknown_error"
    }));
    return json({ error: "book_detail_provider_unavailable" }, 502);
  }

  if (!item) {
    return json({ error: "book_not_found" }, 404);
  }

  const response = json({ item: normalizeBook(item, relatedBooks) });

  if (recommendationsAvailable) {
    response.headers.set("cache-control", `public, max-age=${RESPONSE_MAX_AGE_SECONDS}`);
    ctx.waitUntil(caches.default.put(cacheKey, response.clone()));
  } else {
    response.headers.set("cache-control", "no-store");
  }

  return response;
}

async function fetchAladinBookDetail(
  env: Env,
  isbn: string
): Promise<AladinBookItem | undefined> {
  const response = await fetch(buildAladinLookupURL(env, isbn), {
    signal: AbortSignal.timeout(ALADIN_DETAIL_TIMEOUT_MS)
  });

  if (!response.ok) {
    throw new Error(`aladin_lookup_request_failed_${response.status}`);
  }

  const payload = await response.json<AladinLookupResponse>();
  return Array.isArray(payload.item) ? payload.item[0] : undefined;
}

function buildAladinLookupURL(env: Env, isbn: string): string {
  const url = new URL(env.ALADIN_API_BASE_URL);
  const pathPrefix = url.pathname.endsWith("/") ? url.pathname.slice(0, -1) : url.pathname;
  url.pathname = `${pathPrefix}/ItemLookUp.aspx`;
  url.searchParams.set("ttbkey", env.ALADIN_API_KEY);
  url.searchParams.set("ItemIdType", isbn.length === 13 ? "ISBN13" : "ISBN");
  url.searchParams.set("ItemId", isbn);
  url.searchParams.set("Cover", "Big");
  url.searchParams.set("output", "JS");
  url.searchParams.set("Version", "20131101");
  url.searchParams.set("OptResult", "Toc,Story,categoryIdList");
  return url.toString();
}

function buildCacheKey(url: URL, isbn: string): string {
  const cacheUrl = new URL(url.origin);
  cacheUrl.pathname = "/books/detail";
  cacheUrl.searchParams.set("version", "8");
  cacheUrl.searchParams.set("isbn", isbn);
  return cacheUrl.toString();
}

async function fetchReaderRecommendations(
  env: Env,
  isbn: string
): Promise<RelatedBook[]> {
  const readerRecommendations = await fetchRecommendations(env, isbn, "reader");

  if (readerRecommendations.length > 0) {
    return readerRecommendations;
  }

  const maniaRecommendations = await fetchRecommendations(env, isbn, "mania");

  if (maniaRecommendations.length > 0) {
    return maniaRecommendations;
  }

  return [];
}

async function fetchRecommendations(
  env: Env,
  isbn: string,
  type: "reader" | "mania"
): Promise<RelatedBook[]> {
  const response = await fetch(buildRecommendationsURL(env, isbn, type), {
    signal: AbortSignal.timeout(RECOMMENDATION_TIMEOUT_MS)
  });

  if (!response.ok) {
    throw new Error(`data4library_recommendations_request_failed_${response.status}`);
  }

  const payload = await response.json<Data4LibraryRecommendationResponse>();
  const docs = payload.response?.docs;

  if (!Array.isArray(docs)) {
    return [];
  }

  return docs
    .map((entry) => entry.book ?? entry.doc)
    .filter((book): book is Data4LibraryRecommendationItem => book !== undefined)
    .map(normalizeRelatedBook)
    .filter((book) => book.isbn13.length > 0)
    .slice(0, RELATED_BOOK_LIMIT);
}

function buildRecommendationsURL(env: Env, isbn: string, type: "reader" | "mania"): string {
  const url = new URL(env.DATA4LIBRARY_API_BASE_URL);
  const pathPrefix = url.pathname.endsWith("/") ? url.pathname.slice(0, -1) : url.pathname;
  url.pathname = `${pathPrefix}/recommandList`;
  url.searchParams.set("authKey", env.DATA4LIBRARY_API_KEY);
  url.searchParams.set("isbn13", isbn);

  url.searchParams.set("type", type);
  url.searchParams.set("format", "json");
  return url.toString();
}

function parseISBN(value: string | null): string | null {
  if (value === null) {
    return null;
  }

  const isbn = value.trim();
  return /^(?:\d{10}|\d{13})$/.test(isbn) ? isbn : null;
}

function normalizeBook(item: AladinBookItem, relatedBooks: RelatedBook[]): BookDetail {
  return {
    title: text(item.title),
    author: text(item.author),
    publisher: text(item.publisher),
    publishedDate: text(item.pubDate ?? item.pubdate),
    isbn: text(item.isbn),
    isbn13: text(item.isbn13),
    coverURL: text(item.cover),
    categoryId: integer(item.categoryId),
    categoryName: text(item.categoryName),
    description: text(item.description),
    fullDescription: text(item.fullDescription),
    priceStandard: integer(item.priceStandard),
    priceSales: integer(item.priceSales),
    link: text(item.link),
    customerReviewRank: integer(item.customerReviewRank),
    itemPage: integer(item.subInfo?.itemPage),
    tableOfContents: text(item.subInfo?.toc),
    story: text(item.subInfo?.story),
    relatedBooks
  };
}

function normalizeRelatedBook(item: Data4LibraryRecommendationItem): RelatedBook {
  return {
    title: text(item.bookname),
    authors: text(item.authors),
    publisher: text(item.publisher),
    publicationYear: text(item.publication_year),
    isbn13: text(item.isbn13),
    coverURL: optionalSecureURL(item.bookImageURL),
    detailURL: optionalSecureURL(item.bookDtlUrl)
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

function optionalSecureURL(value: string | undefined): string | null {
  const url = secureURL(value);
  return url.length > 0 ? url : null;
}
