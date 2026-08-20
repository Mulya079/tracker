# Background job limits on candidate hosting

**Ticket:** [Mulya079/tracker#9](https://github.com/Mulya079/tracker/issues/9) — "Check background job limits on candidate hosting"
**Question:** what can each candidate host run in the background, on what schedule, for how long, and at what price?
**Researched:** 2026-08-20
**Workload assumed throughout:** one nightly run of 3 sourcing agents, each 2–5 minutes, each mostly waiting on model and search API calls. That is 6–15 min of wall clock per night, ~3–7.5 hours per month, of which only a small fraction is CPU.

---

## 0. Method, and how much to trust each number

Direct fetches of vendor documentation were **blocked by this session's egress policy** (`vercel.com`, `supabase.com`, `fly.io`, `docs.github.com`, `inngest.com` all return 403 at the proxy). Every figure below therefore comes from the web-search index reading those same primary pages, with the search restricted to the vendor's own domain wherever possible. Each claim links the primary URL it came from.

That means: the **source is** primary, but the **reading** of it is second-hand. Treat structural facts (a limit exists, and roughly where it sits) as reliable, and treat exact dollar figures as needing a one-minute confirmation against the linked page before anyone commits money. Anything I could not pin to a vendor page is marked *unverified* rather than smoothed over.

Two figures below are flagged inline as lower-confidence: the GitHub Actions Pro included-minutes number, and Render's per-instance-type rates.

---

## 1. The precedent on disk, and what it actually constrains

`/home/user/The_Scenic_Route` runs its daily tick at 04:00 UTC. From `plans/admin/progress.md` (decision log, 2026-08-02):

> "A Vercel Hobby plan refuses any schedule that runs more than once a day, so the every-five-minutes tick did not deploy."

and from `docs/setup.md`:

> "`vercel.json` already declares the schedule — daily at 04:00 UTC, which is the tightest a Hobby plan allows."

**The important correction for this ticket: that constraint does not block a nightly run.** Nightly *is* once per day. The Scenic Route was blocked because it wanted a five-minute queue drain, not because it wanted a nightly job. What actually threatens nightly multi-source sourcing on Vercel Hobby is a different limit — **function duration** — plus the fuzziness of when a Hobby cron fires.

Two other bits of the precedent carry over regardless of host:

- Vercel runs **no crons on preview deployments** (`progress.md`), so any branch verification is by hand.
- A Supabase Free project **pauses after a week idle**; the daily tick is what prevents it. A nightly job on any host keeps that property.

---

## 2. Vercel

### Cron frequency

| | Hobby | Pro |
|---|---|---|
| Cron jobs per project | 100 | 100 |
| Minimum interval | **once per day** | per minute |
| Trigger precision | **anywhere within the specified hour** | per minute |

Source: [Usage & Pricing for Cron Jobs](https://vercel.com/docs/cron-jobs/usage-and-pricing) — "cron jobs can only run once per day… Vercel may invoke these cron jobs at any point within the specified hour to help distribute load across all accounts. For example, an expression like `0 8 * * *` could trigger an invocation anytime between 08:00:00 and 08:59:59." The 100-per-project count on every plan is from [Cron jobs now support 100 per project on every plan](https://vercel.com/changelog/cron-jobs-now-support-100-per-project-on-every-plan) (Jan 2026); older write-ups saying "5 on Hobby" are stale. Crons themselves carry no separate charge — the function they invoke is billed like any other.

**Consequence for a nightly sourcing run on Hobby:** the schedule fits, but "04:00 UTC" means "somewhere in the 04:00 hour". Fine for sourcing, which nobody is watching at 4am.

### Function duration

With fluid compute (on by default):

| | default | maximum |
|---|---|---|
| Hobby | 300s | **300s** |
| Pro | 300s | **800s** GA; 1800s in beta on supported Node/Python runtimes |

Sources: [Configuring Maximum Duration](https://vercel.com/docs/functions/configuring-functions/duration), [Vercel Functions Limits](https://vercel.com/docs/functions/limitations), [Vercel Functions can now run up to 30 minutes](https://vercel.com/changelog/vercel-functions-can-now-run-up-to-30-minutes).

**This is the real Hobby blocker.** Three agents at 2–5 min each, run sequentially inside one cron-invoked function, is 360–900s. Hobby's ceiling is 300s. Even one agent at the 5-minute end sits exactly on the limit.

### `after()` / `waitUntil()` — what it does and does not buy you

- `after()` (Next.js) and `waitUntil()` (`@vercel/functions`) schedule work to continue **after the response is sent**, without blocking it. [API reference](https://vercel.com/docs/functions/functions-api-reference/vercel-functions-package), [changelog](https://vercel.com/changelog/waituntil-is-now-available-for-vercel-functions).
- **It does not extend the invocation's budget.** "Promises passed to `waitUntil()` will have the same timeout as the function itself. If the function times out, the promises will be cancelled." The `maxDuration` deadline covers request processing *and* the post-response tasks.
- There is no durability, no retry, no state. If the instance is torn down, the work is gone and nothing tells you.

So `after()` is the right tool for "flush a log line after responding" and the wrong tool for "run a 5-minute agent". Treating it as a background-job system is the classic mistake here.

### Fluid compute billing

You are billed for **Active CPU** only while code is actually executing, not while awaiting I/O — model calls, DB queries, third-party APIs all pause the CPU meter — plus **Provisioned Memory** for the instance lifetime in GB-hours, plus invocations. [Fluid compute pricing](https://vercel.com/docs/functions/usage-and-pricing), [Active CPU pricing announcement](https://vercel.com/blog/introducing-active-cpu-pricing-for-fluid-compute).

Included / rates:

- **Hobby:** 4 Active-CPU hours/mo, 360 GB-hrs Provisioned Memory/mo, 1M invocations/mo. Hobby is capped — you cannot buy past it.
- **Pro:** $20/mo per user with **$20 of included credit**, then pay-as-you-go, uncapped. Active CPU from **$0.128/hr**, Provisioned Memory from **$0.0106/GB-hr**, invocations 1M included then **$0.60/1M**.

Sources: [Fluid compute pricing](https://vercel.com/docs/functions/usage-and-pricing), [Vercel Pricing](https://vercel.com/pricing), [Vercel Hobby Plan](https://vercel.com/docs/plans/hobby).

### Vercel Workflows

Vercel's durable-execution product, positioned exactly at this shape of problem: "For workloads that require unlimited execution time, use Vercel Workflows, which allow your code to pause, resume, and maintain state for minutes to months without duration limits." Limits include 10,000 steps per run, 25,000 events per run, 50 MB per step payload, 2 GB entity storage per run, 240s max replay duration, no limit on schedules/cron. Billed on Workflow Events, Data Written and Data Retained; **Data Retained is not available on Hobby**. [Workflow Pricing and Limits](https://vercel.com/docs/workflows/pricing), [Vercel Workflows](https://vercel.com/docs/workflows).

Note the shape of the escape hatch: Workflows removes the *wall-clock* limit by splitting the run into durable steps. **Each step still executes inside a Function** and is bound by that function's `maxDuration`. A single uninterruptible 5-minute model call is still a 300s/800s problem; a 5-minute agent decomposed into ten 30-second steps is not.

### Hobby's other constraint

The Hobby plan is **non-commercial, personal use only** ([Vercel Hobby Plan](https://vercel.com/docs/plans/hobby), [Fair Use Guidelines](https://vercel.com/docs/limits/fair-use-guidelines)). If the tracker is ever monetised, Hobby stops being an option on licensing grounds before it stops on technical ones.

### Verdict — does the nightly run fit?

| | Fits? | How | Cost/mo |
|---|---|---|---|
| **Hobby** | **Only with fan-out, and tightly** | cron hits a dispatcher that fires 3 separate invocations (one per agent) in parallel, each under 300s. Sequential does not fit. An agent that runs long gets killed with no retry | **$0**, and 7.5 h/mo × 2 GB ≈ 15 GB-hrs sits far inside the 360 GB-hr allowance. Non-commercial only |
| **Pro** | **Yes, comfortably** | 800s per invocation; either 3 parallel invocations or a Workflow. Cron can be precise | **$20/mo** flat. The job's own compute is roughly: ~15 GB-hrs memory ≈ **$0.16**, plus maybe 0.5–1 Active-CPU hr ≈ **$0.06–$0.13** — under $1, entirely absorbed by the $20 credit |

---

## 3. Supabase

### Scheduling — `pg_cron` / Supabase Cron

**No frequency restriction of the kind Vercel Hobby imposes.** Jobs "can run anywhere from every second to once a year". Available on Free. Jobs can run SQL, call a database function, invoke an Edge Function, or hit an HTTP webhook. [Supabase Cron docs](https://supabase.com/docs/guides/cron), [pg_cron extension](https://supabase.com/docs/guides/database/extensions/pg_cron), [Scheduling Edge Functions](https://supabase.com/docs/guides/functions/schedule-functions).

Guidance from the same docs: no more than **8 jobs concurrently**, each job **no more than 10 minutes**; pg_cron supports up to **32 concurrent jobs**, each consuming a database connection. Outbound HTTP goes via `pg_net`, which is "intended to handle at most 200 requests per second", stores response data for 6 hours, and is POST/JSON-shaped ([pg_net](https://supabase.com/docs/guides/database/extensions/pg_net)).

So Supabase solves the *scheduling* half outright — and it will happily schedule work that runs somewhere else entirely, which is the pattern worth remembering.

### Edge Functions — the execution half

| Limit | Value |
|---|---|
| Wall clock | **400s** total worker lifetime |
| Background tasks (`EdgeRuntime.waitUntil`) | **150s on Free**, **400s on paid** |
| CPU time | **2s per request** (async I/O excluded) |
| Memory | enforced by the supervisor; specific figure not stated on the limits page — *unverified* |

Sources: [Edge Function limits](https://supabase.com/docs/guides/functions/limits), [Background Tasks](https://supabase.com/docs/guides/functions/background-tasks), [wall clock time limit](https://supabase.com/docs/guides/troubleshooting/edge-function-wall-clock-time-limit-reached-Nk38bW), [CPU limits](https://supabase.com/docs/guides/troubleshooting/edge-function-cpu-limits), [546 WORKER_RESOURCE_LIMIT](https://supabase.com/docs/guides/troubleshooting/edge-function-546-error-response).

The background-tasks doc is explicit about the trap: **"`EdgeRuntime.waitUntil()` prevents early retirement, but it does not extend the hard wall clock limit."** Same lesson as Vercel's `after()`.

Two limits bite differently:

- **400s wall clock** rules out three sequential agents (360–900s) but permits one agent per invocation, fanned out. On Free the 150s background-task cap rules out even a single 5-minute agent.
- **2s CPU per request** is the sharper and less obvious one. Model calls are I/O and don't count, so an agent that mostly waits is fine — but decryption, embedding maths, or parsing a large HTML page of search results is real CPU, and 2s is not much of it.

### Queues

[Supabase Queues](https://supabase.com/docs/guides/queues) is a Postgres-native durable queue built on `pgmq`: exactly-once delivery within a customisable visibility window, messages stored in Postgres, archivable, logged or unlogged tables. No published size/throughput limits found — *unverified*. There is a documented pattern for [consuming queue messages with Edge Functions](https://supabase.com/docs/guides/queues/consuming-messages-with-edge-functions).

This is the piece that makes the "Supabase schedules, something else executes" pattern clean: `pg_cron` enqueues three jobs at 04:00, a worker anywhere drains them, and the queue holds the durability.

### Cost

- **Free:** $0. 500K Edge Function invocations/mo. Two active projects. **Paused after 1 week of inactivity** — a nightly job prevents that. 150s background-task cap.
- **Pro:** **$25/mo**, includes **$10/mo compute credits** (covers one Micro instance), 2M Edge Function invocations then $2/1M, no automatic pausing.

Sources: [Supabase Pricing](https://supabase.com/pricing), [Edge Functions Pricing](https://supabase.com/docs/guides/functions/pricing), [Project Pausing](https://supabase.com/docs/guides/platform/free-project-pausing), [Manage Compute usage](https://supabase.com/docs/guides/platform/manage-your-usage/compute).

### Verdict

| | Fits? | Cost/mo |
|---|---|---|
| **Free + Edge Functions** | **No** for 5-min agents (150s cap). Yes only for agents under ~2 min, fanned out one per invocation | $0 |
| **Pro + Edge Functions** | **Yes with fan-out** — one agent per invocation under 400s. Watch the 2s CPU limit | **$25/mo** (invocations negligible: ~90/mo against 2M) |
| **`pg_cron` as scheduler only, worker elsewhere** | **Yes, no caveats** — this is the strongest use of Supabase here | $0 on Free, plus whatever the worker costs |

---

## 4. Worker-shaped alternatives

### 4a. Fly.io — container host, scheduled Machines

- **Scheduling:** Machines have a built-in `--schedule` flag (`hourly`, `daily`, `weekly`, `monthly`) that starts the Machine on a **fuzzy** cycle. Fly's own guidance: "good for simple, low-frequency jobs (~1x/day) but not for precise timing." For real cron precision, Fly's [task scheduling blueprint](https://fly.io/docs/blueprints/task-scheduling/) covers running a Cron Manager. Sources: [fly machine run](https://fly.io/docs/machines/flyctl/fly-machine-run/), [Scheduled machines announcement](https://community.fly.io/t/new-feature-scheduled-machines/7398).
- **Duration:** none. It is a VM; it runs until the process exits.
- **Cost:** a `shared-cpu-1x` 1 GB Machine running 24/7 is **~$6.79/mo** (Fly quotes three of them at $20.37/mo); a 256 MB one full-time is **$2.32/mo** and "less than $1/month" if it auto-stops when idle. Stopped Machines bill only rootfs at **$0.15/GB/mo**. Billing is per-second while running. There is **no free tier** any more — pay-as-you-go, no minimum, no cap. Sources: [Fly.io Resource Pricing](https://fly.io/docs/about/pricing/), [Billing](https://fly.io/docs/about/billing/), [Cost Management](https://fly.io/docs/about/cost-management/).
- **Nightly run:** 7.5 h/mo of a 1 GB Machine ≈ $6.79 × 7.5/730 ≈ **$0.07**, plus $0.15 rootfs. Call it **$0.25/mo** — or **~$2.60/mo** if you add a 256 MB always-on scheduler Machine to get precise timing instead of a fuzzy daily.

**Fits: yes, with the most headroom of anything here.** No duration limit at all. The cost is the operational one — you now own a container image and a deploy path.

### 4b. Railway — container host with a cron primitive

- **Scheduling:** crontab expressions on a service; **minimum interval 5 minutes**. The service **must exit on completion** — "if the code that runs in your Cron service does not exit, subsequent executions of the Cron will be skipped", and a run still in flight when the next is due causes the new one to be skipped. [Cron Jobs](https://docs.railway.com/cron-jobs), [Cron vs workers vs queues](https://docs.railway.com/guides/cron-workers-queues).
- **Duration:** no documented cap; you pay for the minutes you run.
- **Cost:** **Hobby $5/mo** including **$5 of usage credit** — the $5 subscription is charged regardless, and usage under $5 costs nothing extra. Compute is **$10/GB RAM/mo + $20/vCPU/mo, metered per minute**, plus $0.05/GB egress. [Pricing Plans](https://docs.railway.com/pricing/plans), [Pricing](https://docs.railway.com/pricing).
- **Nightly run:** 7.5 h/mo at 1 vCPU + 1 GB ≈ (7.5/730) × $30 ≈ **$0.31/mo** of usage, entirely inside the $5 credit. **Total $5/mo.**

**Fits: yes.** The skip-if-still-running behaviour is a real design constraint — three agents that occasionally overrun into the next night's slot would silently drop a run — but at daily cadence that is nearly impossible.

### 4c. Render — cron job service

- **Scheduling:** cron jobs as a first-class service type. **Max run time 12 hours.** [Cron Jobs](https://render.com/docs/cronjobs).
- **Cost:** cron jobs "bill per minute while running, not as a monthly plan", with a **$1/month minimum per cron job service**. Instance types up to Pro Plus. Note that **background workers have no free tier** — they start at Starter — so the free-web-service tier is not a route in. Per-instance-type per-minute rates were not retrievable — *unverified*, check [Render Pricing](https://render.com/pricing). Sources: [Cron Jobs](https://render.com/docs/cronjobs), [Background Workers](https://render.com/docs/background-workers), [Pricing](https://render.com/pricing).
- **Nightly run:** 7.5 h/mo against a ~$7/mo-equivalent Starter instance ≈ $0.07 of metered time, so the **$1/mo floor** dominates. **~$1/mo**, plus whatever workspace plan applies.

**Fits: yes**, with the cleanest mental model of the container hosts — a cron job service *is* the primitive. Lowest verified confidence on exact price.

### 4d. GitHub Actions — the free option, and the one with the worst timing

- **Scheduling:** `schedule:` with standard 5-field cron. But: "the `schedule` event can be delayed during periods of high loads… If the load is sufficiently high enough, **some queued jobs may be dropped**." [Events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows).
- **Duration:** **6 hours per job** on GitHub-hosted runners; 35 days per workflow run. [Actions limits](https://docs.github.com/en/actions/reference/limits).
- **Cost:** private repos get a monthly quota of free minutes — **2,000/mo on Free**; Pro is *commonly* 3,000 but the search result hedged, so treat that as *low confidence*. Linux runners are the base rate at **$0.008/min** beyond the quota; Windows ×2, macOS ×10. [Actions billing](https://docs.github.com/billing/managing-billing-for-github-actions/about-billing-for-github-actions), [Billing and usage](https://docs.github.com/en/actions/concepts/billing-and-usage).
- **Nightly run:** 3 agents × 5 min × 30 nights = **450 min/mo**, comfortably inside 2,000. **$0/mo.**

**Fits: yes, and free** — the 6-hour job limit makes the whole workload trivially small. The catch is that dropped and delayed runs are documented behaviour, not an incident. For "find job postings overnight" that is survivable; for anything a person waits on, it is not. Also note that scheduled workflows in a public repo get disabled after a long idle period, and that the repo already lives on GitHub (`Mulya079/tracker`), so there is no new vendor to onboard.

### 4e. Trigger.dev — job-queue service built for exactly this

- **Scheduling:** [scheduled tasks](https://trigger.dev/product/scheduled-tasks) with cron, first class.
- **Duration:** **"Tasks can run for as long as you need, with no timeouts"**; Cloud enforces a 14-day max TTL per run. [Limits](https://trigger.dev/docs/limits), [Max duration changelog](https://trigger.dev/changelog/max-duration).
- **Cost:** Free includes **$5/mo of usage** and stops when spent; **Hobby $10/mo** with $10 usage credit, 50 concurrent runs; **Pro $50/mo** with $50 usage and 200 concurrent runs (+50 for $10/mo). Billing is compute-seconds plus run count; a `small-1x` machine is quoted at **$0.0000338/sec** (≈$0.122/hr), with a worked example of a 10s task × 100 runs/day at ~$1.09/mo. [Cloud Pricing](https://trigger.dev/pricing), [concurrency changelog](https://trigger.dev/changelog/concurrency-plan-increases).
- **Nightly run:** 7.5 h/mo × $0.122 ≈ **$0.91** of compute plus ~90 runs. Inside the Free plan's $5. **$0/mo on Free, $10/mo on Hobby** for production comfort.

**Fits: yes, best-shaped.** Retries, run history, durable state and no duration ceiling are the four things a multi-step agent run actually wants, and this is the only option that gives all four without you building them.

### 4f. Inngest — durable execution, step-bounded

- **Free tier:** 100k executions/mo, 25 concurrent steps. **Pro $99/mo** with 1M executions and higher concurrency. [Pricing](https://www.inngest.com/pricing), [Usage limits](https://www.inngest.com/docs/usage-limits/inngest).
- **Duration:** max **1,000 steps per function**; "each step has a timeout depending on the hosting provider of your choice, but Inngest supports up to **2 hours** at the maximum." Free-plan `step.sleep` capped at 7 days; 256 KiB max event payload on Free.
- **The catch that matters:** Inngest orchestrates, it does not host. **Each step runs on your infrastructure and is bounded by that platform's function timeout.** Putting Inngest in front of Vercel Hobby still leaves you with 300s per step. It converts a duration problem into a decomposition problem — which is real progress, but not the same as removing the limit.
- **Nightly run:** ~900 executions/mo against 100k. **$0/mo** on Free, plus the host's own cost.

---

## 5. Answering the ticket directly

**Does a nightly run of 3 agents × 2–5 min fit, and what does it cost per month?**

| Option | Fits? | Shape required | Cost/mo |
|---|---|---|---|
| **Vercel Hobby** | Marginal | Must fan out to 3 parallel invocations; each agent must stay under 300s, with no retry when it doesn't. Cron fires anywhere in the hour. Non-commercial licence only | **$0** |
| **Vercel Pro** | Yes | 3 parallel invocations at 800s each, or Workflows for step-level durability | **$20** (job compute <$1, absorbed by credit) |
| **Supabase Free + Edge Functions** | No | 150s background-task cap kills a 5-min agent | $0 |
| **Supabase Pro + Edge Functions** | Yes, with care | One agent per invocation under 400s; 2s CPU/request is the hidden ceiling | **$25** |
| **Supabase `pg_cron` as scheduler + external worker** | Yes | Cron/queue in Postgres, execution elsewhere | $0 on Free + worker cost |
| **Fly.io Machines** | Yes | Scheduled Machine (fuzzy daily) or a small always-on scheduler; no duration limit | **~$0.25**, or **~$2.60** with precise timing |
| **Railway cron service** | Yes | Service must exit; runs skip if the previous overruns | **$5** (usage ~$0.31 inside the credit) |
| **Render cron job** | Yes | 12-hour ceiling, per-minute billing | **~$1** (rates *unverified*) |
| **GitHub Actions** | Yes | 6-hour job limit; scheduled runs can be **delayed or dropped** | **$0** (450 of 2,000 free min) |
| **Trigger.dev** | Yes | No timeouts, retries and run history included | **$0** Free / **$10** Hobby |
| **Inngest** | Yes, conditionally | Steps still bounded by your host's function timeout | **$0** Free + host cost |

### What the numbers say

1. **The Scenic Route's constraint does not transfer.** Vercel Hobby's once-per-day cron is a problem for a five-minute queue drain; a nightly sourcing run is once per day by definition. The thing to write into the tracker's own notes is that **the limit that bites here is function duration (300s on Hobby), not cron frequency.**

2. **Every serverless option demands the same shape: fan out, one agent per invocation.** Three sequential agents is 6–15 minutes and exceeds Hobby's 300s, Supabase's 400s, and Vercel Pro's 800s alike. Three parallel invocations fits all three. Design the runner so each agent is its own invocation and the destination stays portable across all of these.

3. **`after()` and `EdgeRuntime.waitUntil()` are not background jobs.** Both vendors say so explicitly in their own docs. They defer work past the response inside an invocation that is still counting down to the same deadline, with no durability and no retry. Anything that reads "we'll just kick it off with `after()`" is a 300-second bomb with no alarm.

4. **Compute cost is noise; plan floors are the whole bill.** Seven and a half hours a month of mostly-idle work costs cents everywhere. What you are choosing between is $0 (GitHub Actions, Trigger.dev Free, Fly), $5 (Railway), $20 (Vercel Pro) and $25 (Supabase Pro). **The model API bill for three nightly agents will exceed all of these**, which argues for picking on operational fit rather than price.

5. **Separating scheduler from executor is the cheapest way to stay unlocked.** `pg_cron` on Supabase Free schedules at any cadence with no plan gate; `pgmq` gives durable hand-off; the executor can then be Vercel, Fly, Railway or Trigger.dev without the schedule changing. That keeps the destination feature from inheriting whichever host's ceiling happens to be lowest.

### If I had to recommend

- **To prove the destination feature works, this month, at zero cost:** GitHub Actions on a schedule. Six-hour job limit, secrets already there, repo already there. Accept that runs are sometimes late and occasionally dropped — for overnight sourcing that is tolerable, and it buys a real answer about whether the agents produce anything worth keeping before anyone pays for anything.
- **To run it as a product feature:** Trigger.dev ($0–10/mo). No duration ceiling, retries and run history built in, cron scheduling native. It is the only option in the table designed for multi-step model-calling runs rather than adapted to them.
- **If the app is staying on Vercel anyway and the destination is a first-class feature:** Vercel Pro at $20/mo, with the run decomposed into Workflows steps rather than one long function. That removes the wall-clock question permanently instead of moving it.
- **What to avoid:** building the nightly run as one long function on Vercel Hobby. It fits only if every agent stays under five minutes forever, and the failure mode when one doesn't is a silent kill with no retry and no record.

---

## 6. Loose ends worth one more check before anyone commits

- Render's per-minute rate per instance type (the $1/mo floor is documented; the rate above it is not confirmed here).
- GitHub Actions included minutes on the Pro plan — 2,000 on Free is solid; the 3,000 Pro figure is not.
- Supabase Edge Function **memory** limit — the limits page enforces one but the figure did not surface.
- Supabase Queues throughput and message-size limits — no published figures found.
- Whether the tracker counts as commercial use, which decides whether Vercel Hobby is available at all.
- All dollar figures were read out of the search index rather than fetched from the vendor pages, which this session's egress policy blocks. Confirm before spending.
