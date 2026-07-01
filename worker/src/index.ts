import type { Env } from "./env";
import { routeRequest } from "./router";
import { cleanupIncompleteSnapshots } from "./snapshot-cleanup";
import { refreshNewArrivalSnapshots } from "./routes/new-arrivals";
import { refreshBestsellerSnapshot } from "./routes/bestsellers";

export type { Env } from "./env";

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return routeRequest(request, env, ctx);
  },

  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    void controller;
    ctx.waitUntil(cleanupIncompleteSnapshots(env)
      .then(() => Promise.all([
        refreshNewArrivalSnapshots(env),
        refreshBestsellerSnapshot(env)
      ]))
      .then(() => undefined));
  }
};
