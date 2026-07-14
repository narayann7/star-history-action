/**
 * Unit tests for the axios retry interceptor. Run: tsx renderer/retry.test.ts
 *
 * No network: a custom axios adapter fakes the HTTP responses, sleep is a no-op,
 * and the clock is fixed so backoff math is deterministic.
 */
import axios from "axios";
import { computeWaitMs, isRateLimit403, installRetry } from "./retry";

let failures = 0;
function check(name: string, cond: boolean) {
  if (cond) {
    process.stdout.write(`ok   ${name}\n`);
  } else {
    failures++;
    process.stdout.write(`FAIL ${name}\n`);
  }
}

// --- isRateLimit403 -------------------------------------------------------
check("403 with retry-after is a rate limit", isRateLimit403({ status: 403, headers: { "retry-after": "30" }, data: "" }));
check("403 with remaining 0 is a rate limit", isRateLimit403({ status: 403, headers: { "x-ratelimit-remaining": "0" }, data: "" }));
check("403 with secondary-limit body is a rate limit", isRateLimit403({ status: 403, headers: {}, data: "You have exceeded a secondary rate limit" }));
check("plain forbidden 403 is NOT a rate limit", !isRateLimit403({ status: 403, headers: {}, data: "Must have admin rights" }));
check("404 is not a rate limit", !isRateLimit403({ status: 404, headers: {}, data: "" }));

// --- computeWaitMs --------------------------------------------------------
const NOW = 1_000_000_000_000;
check("retry-after wins", computeWaitMs({ headers: { "retry-after": "5" } }, 1, NOW) === 5000);
check("retry-after past cap gives up", computeWaitMs({ headers: { "retry-after": "3600" } }, 1, NOW) === null);
check("waits until ratelimit reset", computeWaitMs({ headers: { "x-ratelimit-remaining": "0", "x-ratelimit-reset": String((NOW + 10_000) / 1000) } }, 1, NOW) === 10_000);
check("reset too far out gives up", computeWaitMs({ headers: { "x-ratelimit-remaining": "0", "x-ratelimit-reset": String((NOW + 3_600_000) / 1000) } }, 1, NOW) === null);
const backoff = computeWaitMs({ headers: {} }, 3, NOW);
check("backoff grows (attempt 3 in 4000..4500)", backoff !== null && backoff >= 4000 && backoff < 4500);

// --- installRetry end to end ---------------------------------------------
async function makeClient(script: Array<{ status: number; headers?: any; data?: any }>) {
  const client = axios.create();
  let i = 0;
  client.defaults.adapter = async (config) => {
    const step = script[Math.min(i, script.length - 1)];
    i++;
    const response = { data: step.data ?? {}, status: step.status, statusText: "", headers: step.headers ?? {}, config } as any;
    if (step.status >= 400) {
      const err: any = new Error(`status ${step.status}`);
      err.config = config;
      err.response = response;
      throw err;
    }
    return response;
  };
  const retries: number[] = [];
  installRetry(client, {
    sleepFn: async () => {},
    now: () => NOW,
    onRetry: (info) => retries.push(info.attempt),
  });
  return { client, retries: () => retries, calls: () => i };
}

async function run() {
  // Transient rate-limit 403 then success: should resolve.
  {
    const { client, retries } = await makeClient([
      { status: 403, headers: { "retry-after": "1" } },
      { status: 200, data: { ok: true } },
    ]);
    const res = await client.get("https://api.github.com/x");
    check("retries a transient 403 then succeeds", res.status === 200 && retries().length === 1);
  }

  // Always 403 rate limit: gives up after maxRetries and rejects.
  {
    const { client, retries } = await makeClient([{ status: 403, headers: { "retry-after": "1" } }]);
    let threw = false;
    try {
      await client.get("https://api.github.com/x");
    } catch {
      threw = true;
    }
    check("gives up after max retries on persistent 403", threw && retries().length === 4);
  }

  // Non-retryable 401: fails immediately, no retries.
  {
    const { client, retries } = await makeClient([{ status: 401 }]);
    let threw = false;
    try {
      await client.get("https://api.github.com/x");
    } catch {
      threw = true;
    }
    check("does not retry a 401", threw && retries().length === 0);
  }

  // Genuine permission 403 (no rate-limit signal): not retried.
  {
    const { client, retries } = await makeClient([{ status: 403, headers: {}, data: "Resource protected" }]);
    let threw = false;
    try {
      await client.get("https://api.github.com/x");
    } catch {
      threw = true;
    }
    check("does not retry a non-rate-limit 403", threw && retries().length === 0);
  }

  if (failures > 0) {
    process.stderr.write(`\n${failures} test(s) failed\n`);
    process.exit(1);
  }
  process.stdout.write("\nall retry tests passed\n");
}

run();
