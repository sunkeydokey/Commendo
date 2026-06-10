import type { Env } from "./env";
import { routeRequest } from "./router";
import { refreshNewArrivalSnapshots } from "./routes/new-arrivals";
import { refreshPopularLoanSnapshot } from "./routes/popular-loans";

export type { Env } from "./env";

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return routeRequest(request, env, ctx);
  },

  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    void controller;
    ctx.waitUntil(Promise.all([
      refreshNewArrivalSnapshots(env),
      refreshPopularLoanSnapshot(env)
    ]).then(() => undefined));
  }
};
