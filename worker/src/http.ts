export const RESPONSE_MAX_AGE_SECONDS = 86400;

export function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8"
    }
  });
}

export function parsePageQuery(searchParams: URLSearchParams):
  | { page: number; pageSize: number }
  | { error: string } {
  const page = parsePositiveInteger(searchParams.get("page") ?? "1");

  if (page === null) {
    return { error: "invalid_page" };
  }

  const pageSize = parsePositiveInteger(searchParams.get("pageSize") ?? "20");

  if (pageSize === null || pageSize > 20) {
    return { error: "invalid_page_size" };
  }

  return { page, pageSize };
}

export function parsePositiveInteger(value: string): number | null {
  if (!/^[1-9]\d*$/.test(value)) {
    return null;
  }

  const parsed = Number(value);
  return Number.isSafeInteger(parsed) ? parsed : null;
}
