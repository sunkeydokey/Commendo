export interface Env {
  ALADIN_API_KEY: string;
  DATA4LIBRARY_API_KEY: string;
  FIREBASE_PROJECT_ID?: string;
  FIREBASE_CLIENT_EMAIL?: string;
  FIREBASE_PRIVATE_KEY?: string;
}

type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue };

interface JsonBody {
  [key: string]: JsonValue;
}

const routes = new Map<string, Set<string>>([
  ["GET", new Set([
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

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    void env;
    void ctx;

    const url = new URL(request.url);

    if (!isKnownRoute(request.method, url.pathname)) {
      return json({ error: "Not found" }, 404);
    }

    return json({
      status: "not_implemented",
      route: url.pathname,
      method: request.method
    }, 501);
  },

  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    void controller;
    void env;
    void ctx;
  }
};

function isKnownRoute(method: string, pathname: string): boolean {
  return routes.get(method.toUpperCase())?.has(pathname) ?? false;
}

function json(body: JsonBody, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8"
    }
  });
}
