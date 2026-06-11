import type { Env } from "./env";
import { json } from "./http";
import { handleBookDetail } from "./routes/book-detail";
import { handleNewArrivals } from "./routes/new-arrivals";
import { handlePopularLoans } from "./routes/popular-loans";

const routes = new Map<string, Set<string>>([
  ["GET", new Set([
    "/books/new-arrivals",
    "/books/trending",
    "/books/search",
    "/books/detail",
    "/books/availability",
    "/libraries/book-exist"
  ])],
  ["POST", new Set([
    "/notifications/register",
    "/notifications/unregister",
    "/notifications/preferences"
  ])]
]);

export async function routeRequest(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  const url = new URL(request.url);

  if (!isKnownRoute(request.method, url.pathname)) {
    return json({ error: "Not found" }, 404);
  }

  if (request.method === "GET" && url.pathname === "/books/new-arrivals") {
    return handleNewArrivals(request, env, ctx);
  }

  if (request.method === "GET" && url.pathname === "/books/trending") {
    return handlePopularLoans(request, env, ctx);
  }

  if (request.method === "GET" && url.pathname === "/books/detail") {
    return handleBookDetail(request, env, ctx);
  }

  return json({
    status: "not_implemented",
    route: url.pathname,
    method: request.method
  }, 501);
}

function isKnownRoute(method: string, pathname: string): boolean {
  return routes.get(method.toUpperCase())?.has(pathname) ?? false;
}
