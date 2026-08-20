# Harvest inventory: what is takeable from the two source repos

Research ticket: [Mulya079/tracker#6](https://github.com/Mulya079/tracker/issues/6)
Read on disk, 2026-08-20. Nothing was copied, modified or committed in either repo.

- `/home/user/The_Scenic_Route` — 299 commits, 2026-07-31 → 2026-08-12, P0–P10.1 merged. Next.js 15 / React 19 / Postgres via `postgres` driver, Supabase for auth only. No `LICENSE` file.
- `/home/user/theRealJobSearch` — 23 commits, 2025-03-15 → 2025-04-08. Next.js 14 / React 18. A fork of the MIT-licensed `supa-next-starter` (Michael Troya); the `LICENSE` file is the starter's, so anything taken from the boilerplate carries MIT attribution. The application code on top of it is the owner's.

Neither repo has `node_modules` installed, so no build was run. Every claim below comes from reading source.

---

## The finding that decides most of the rest

The privacy layer is **injected, not baked in**. `withPlaintext` (`src/lib/jobs/window.ts`) does three separable things:

1. **Policy** — is this descriptor registered, does its scope match, may it touch this column, is the column's class at or below the descriptor's. All of that lives in `src/lib/jobs/opener.ts` + `src/lib/privacy/manifest.ts` and needs no key, no KEK, no database.
2. **Crypto** — three functions, `seal` / `open` / `blindIndex`, passed *in* as a `BoundCrypto` object literal (`window.ts` lines 118–130).
3. **Audit** — a row in `audit_log` on both the return and the throw path.

```ts
export interface BoundCrypto {
  seal(spec: ColumnSpec, plaintext: string): Uint8Array;
  open(spec: ColumnSpec, stored: Uint8Array): string;
  blindIndex(spec: ColumnSpec, value: string): Uint8Array;
}
```

That means the new app **can take the whole job/outbox/capture spine and defer the privacy decision**, by supplying a passthrough `BoundCrypto` (`seal` = `utf8ToBytes`, `open` = `bytesToUtf8`, `blindIndex` = plain SHA-256) and deleting the `currentKek()` / `withDek` / `loadWrappedDek` block. The descriptor discipline, the column manifest, the audit trail and the scope assertions all keep working unchanged, and the day the privacy decision is made, real crypto drops into the same three slots.

Two costs to be honest about if that route is taken:

- **The columns stay `bytea`.** `db/schema.ts` types every content column `Uint8Array`, and `drain`'s payload scrub writes `Buffer.alloc(0)`. A passthrough codec keeps the schema shape while making the bytes readable — which is the honest state of a deferred decision, but nobody should describe that database as encrypted.
- **`opener.ts` gates on `storage: 'sealed'`.** `open.seal()` throws for any column the manifest declares `plain`. Keeping the manifest entries as `sealed` while the codec is passthrough works, but it makes the manifest say something untrue. The alternative is a fourth storage kind (`deferred`), which is a ten-line change in `manifest.ts` and `opener.ts`.

---

# The_Scenic_Route

## 1. Outbox + `runJob` runtime + job registry

| File | Lines |
|---|---|
| `src/lib/jobs/run.ts` | 188 |
| `src/lib/jobs/registry.ts` | 64 |
| `src/lib/jobs/descriptor.ts` | 114 |
| `src/lib/jobs/errors.ts` | 13 |
| `src/lib/jobs/opener.ts` | 151 |
| `src/lib/jobs/window.ts` | 148 |
| `src/lib/jobs/derived.ts` | 95 |
| `src/lib/outbox/drain.ts` | 184 |
| `src/lib/outbox/write.ts` | 111 |
| `src/lib/outbox/opportunistic.ts` | 65 |
| `src/lib/scheduler/types.ts` | 24 |
| `scripts/worker.ts` | 96 |
| `src/app/api/cron/tick/route.ts` | 149 |

**Dependency reach (measured, transitively):**

- `drain.ts` alone → **6 files, ~1085 lines**, one package (`postgres`). Reaches `db/schema.ts` (type-only), `jobs/errors.ts`, `log/logger.ts`, and through the logger, `privacy/classified.ts` + `classification.ts` (also type-only).
- `run.ts` + `registry.ts` + `descriptor.ts`, **no window** → **9 files, ~1134 lines**. `postgres`, `@noble/hashes/sha2`, `@noble/ciphers/utils`. The two `@noble` imports are `sha256` and `utf8ToBytes` in the idempotency key — replaceable with `node:crypto` in one line. `crypto/aead.ts` appears in the closure only as a *type-only* import chain (`descriptor → db/columns → type ColumnRef`), so it erases at compile time.
- Add `window.ts` → **23 files, ~2977 lines**, and now the whole KEK tree, `audit/sink.ts` and `db/connection.ts` come with it.
- `outbox/write.ts` (`enqueue`) → **21 files, ~2790 lines**, because it seals the payload and blind-indexes the dedupe key.

**Without the crypto layer?**

- `drain.ts`: **yes, cleanly.** It never opens anything. It handles claim-with-`for update skip locked`, lease expiry, exponential backoff capped at an hour, parking after 8 attempts, and payload scrub on success. Genuinely reusable as-is.
- `run.ts` + `registry.ts` + `descriptor.ts`: **yes.** `runJob` never touches a key; the registry check is identity-based (`byId.get(id) === descriptor`), which is the right design and independent of privacy.
- `window.ts` + `opener.ts`: **yes, via the `BoundCrypto` seam above.**
- `outbox/write.ts`: **needs one edit.** `enqueue` is the one write-path function that goes through `withPlaintext`; with a passthrough codec it works unchanged.

**Judgement: TAKE.** This is the strongest asset in either repo — a durable outbox and an idempotent job runner that have both been exercised against a real database, and the idempotency key design (`sha256(job | subject | modelVersion | inputVersion)`) is the sort of thing that is cheap to copy and expensive to re-derive after the bug.

**More coupled than it looks:**

- `runJob` hard-codes SQL against a specific `job_runs` shape — `user_id, job_id, subject_ref, idempotency_key, model_version, state, started_at, finished_at, error_name`, plus a unique index on `(user_id, idempotency_key)`. Migrations `0005` and `0016` come with it or nothing works.
- `drain.ts` imports `OutboxRow` from `src/lib/db/schema.ts`, which is a **644-line hand-written whole-schema file**. Copy the 16-line interface, not the file.
- `outbox/opportunistic.ts` (65 lines) imports four handler registrars from four different domains. It is glue for *this* app; do not take it, write the new app's own.
- The AI usage recorder (`ai/usage.ts:recordUsage`) writes into `job_runs`. Cost accounting and the job runner are one table.

---

## 2. AI provider registry + zero-retention gate

| File | Lines |
|---|---|
| `src/lib/ai/registry.ts` | 251 |
| `src/lib/ai/capability.ts` | 47 |
| `src/lib/ai/usage.ts` | 149 |
| `src/lib/ai/bootstrap.ts` | 50 |
| `src/lib/ai/providers/anthropic.ts` | 213 |
| `src/lib/ai/providers/deepgram.ts` | 143 |
| `src/lib/ai/providers/voyage.ts` | 138 |
| `src/lib/ai/providers/local-dev.ts` | 53 |
| `src/lib/net/allowlist.ts` | 47 |
| `src/lib/privacy/policy.ts` | 69 |

**Dependency reach:** registry + bootstrap + all four providers → **29 files, ~3800 lines**, packages `@anthropic-ai/sdk` + `postgres` + `@noble/*`. The crypto tree enters only through `usage.ts`'s type-only `SqlHandle` import and the `descriptor` chain — but `bootstrap.ts` pulls every provider, and `recordUsage` really does write SQL.

The design: `resolve({capability, tier, sensitivityClass})` walks registered providers in registration order and returns a `ModelBinding`. Tiers are `low | mid | high | frontier`; capabilities are `text | transcription | embedding`. Two refusals do the real work — `resolveFor` throws `NoProviderForReadError` for a `read` descriptor (the request path may show a person their words and may not send them anywhere), and `assertMayReach` throws rather than falling back to a weaker provider.

The zero-retention gate is small and blunt, in `privacy/policy.ts`:

```ts
const PERMITTED: Record<SensitivityClass, readonly RetentionPosture[]> = {
  S0: ['zero-retention', 'retained', 'local-dev'],
  S1: ['zero-retention'], S2: ['zero-retention'], S3: ['zero-retention'],
};
```

**Without the crypto layer?** **Yes** — nothing here decrypts. But it is not free of *privacy vocabulary*: `resolve` takes a `SensitivityClass`, so taking the registry means taking `privacy/classification.ts` (63 lines) and `privacy/policy.ts` (69), or ripping the class parameter out. Ripping it out is what turns the registry into an ordinary model-router; keeping it is what makes it a gate.

**Judgement: TAKE the registry + `capability.ts` + `local-dev.ts`; ADAPT the providers; TAKE `net/allowlist.ts` outright.** The `Provider` interface with optional `complete`/`embed`/`transcribe` and the `CapabilityNotCallableError` guard is a good, small seam. `net/allowlist.ts` is 47 self-contained lines with zero imports and is worth taking on the first day.

**More coupled than it looks:**

- **`anthropic.ts` carries stale model ids** — `claude-sonnet-5`, `claude-haiku-4-5`, and a header note that the top Anthropic tier requires 30-day retention and is therefore structurally unavailable. That reasoning is worth reading; the ids need re-checking against current pricing and availability before they ship anywhere.
- `embedWith` asserts `vectors.length === inputs.length` because the caller matches by position. Small, load-bearing, easy to drop while trimming.
- `usage.ts` will not compile without a `job_runs` table with `usage_unit`, `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_write_tokens`, `audio_seconds`. Taking the AI registry drags the jobs schema in behind it unless `recordUsage` is stubbed.
- `bootstrap.ts` is registration order = preference order. That is policy expressed as import order, and it is easy to break by tidying imports.

---

## 3. Capture pipeline (`capture.ingest`, `capture.split`)

| File | Lines |
|---|---|
| `src/lib/capture/ingest.ts` | 174 |
| `src/lib/capture/split.ts` | 238 |
| `src/lib/capture/jobs.ts` | 141 |
| `src/lib/capture/payload.ts` | 137 |
| `src/lib/capture/prompt.ts` | 190 |
| `src/lib/capture/request.ts` | 151 |
| `src/lib/capture/handlers.ts` | 140 |
| `src/lib/capture/transcribe.ts` | 82 |
| `src/lib/capture/dates.ts` | 158 |
| `src/lib/capture/density.ts` | 118 |
| `src/lib/capture/revision.ts` | 114 |
| `src/lib/capture/read.ts` | 579 |
| (whole `src/lib/capture/`) | **2993** |
| `src/app/api/capture/route.ts` | 99 |

**Dependency reach:**

- `capture/ingest.ts` → **29 files, ~3891 lines**.
- `capture/split.ts` → **34 files, ~4605 lines** — and it reaches `src/lib/pursuits/jobs.ts` for `FILE_KIND`, because splitting enqueues filing.
- `capture/handlers.ts` (the whole pipeline wired up) → **67 files, ~10,330 lines**, spanning `pursuits/`, `threads/`, `ingest/`, `ai/providers/`, `tone/`, and `config/banned-vocabulary.json`.

`capture.ingest` is the better of the two: it moves sealed bytes from `outbox.payload` into `captures.body` through one window, optionally transcribing audio *inside* the window so neither the audio nor the transcript exists outside it, writes a `signals` row in the same transaction, and handles the case where the client-minted uuid was already taken by someone else. `capture.split` is a model call bracketed by a window, with a genuinely subtle regeneration rule — it deletes derived items at positions `>=` its own output length, skipping user-edited rows, so a re-run that produces fewer items does not leave orphans from the previous model's reading.

**Without the crypto layer?** **Both, via the `BoundCrypto` seam** — but `split.ts` also needs the AI registry and `pursuits/jobs.ts`, and `ingest.ts` needs `ai/usage.ts` for the transcription billing.

**Judgement: ADAPT `capture.ingest`; LEAVE `capture.split`; TAKE `payload.ts` and `request.ts`.**

- `ingest.ts` is ~120 lines of real logic and the "insert, recognise a replay, or mint a fresh id" branch is worth copying almost verbatim.
- `split.ts` is inseparable from this product's domain — pursuits, threads, capture items, stated dates, item budgets. Take the *shape* (window → model call → seal → upsert derived, with billing in a `finally`), not the file.
- `payload.ts` (137 lines) is a versioned envelope for queued work with three parseable versions. Small, standalone, and the versioning discipline is the sort of thing that is only obvious after the first unparseable queued row.
- `request.ts` (151 lines) validates the capture request. Its one dependency is two enums from `db/schema.ts`.

**More coupled than it looks:**

- `capture/jobs.ts` holds `CAPTURE_INPUT_VERSION = 'v3'` — a constant that composes with a per-capture revision suffix to key idempotency. Copying `ingest.ts` without understanding this constant means re-runs silently no-op forever.
- `handlers.ts` is a 140-line file that transitively **is the application**. It looks like a registration list.
- `read.ts` is 579 lines — the largest file in the capture directory and the request-path read surface, not part of the job pipeline. Easy to sweep up by directory glob.

---

## 4. Envelope encryption + sensitivity manifest

| File | Lines |
|---|---|
| `src/lib/privacy/manifest.ts` | 433 |
| `src/lib/privacy/classification.ts` | 63 |
| `src/lib/privacy/classified.ts` | 68 |
| `src/lib/privacy/policy.ts` | 69 |
| `src/lib/db/columns.ts` | 75 |
| `src/lib/crypto/aead.ts` | 128 |
| `src/lib/crypto/keys.ts` | 127 |
| `src/lib/crypto/blind-index.ts` | 65 |
| `src/lib/crypto/passphrase-seal.ts` | 127 |
| `src/lib/crypto/recovery.ts` | 123 |
| `src/lib/crypto/kek/{current,derived,env,local,managed,types}.ts` | 291 |
| `src/lib/jobs/window.ts` | 148 |
| `src/lib/jobs/opener.ts` | 151 |
| `src/lib/audit/sink.ts` | 125 |
| `src/lib/log/logger.ts` | 107 |

**Dependency reach:** the crypto tree alone → **12 files, ~936 lines**, and its only packages are `@noble/ciphers` and `@noble/hashes`. It imports nothing from the rest of the app except a type from `privacy/classification.ts`. This is the cleanest-cut module in the repo.

Three pieces are worth separating:

- **`crypto/*`** — XChaCha20-Poly1305 envelope encryption, DEK-per-user wrapped by a KEK, Argon2id recovery wrap, HMAC blind indexes. Self-contained.
- **`privacy/manifest.ts`** — 433 lines, of which ~330 are the `COLUMN_MANIFEST` array itself: one entry per content column of *this* product's schema, with class, storage kind and a prose `note`. The machinery at the bottom (`buildIndex`, `entryOf`, `classOf`, `storageOf`, throwing `UnclassifiedColumnError` rather than defaulting) is ~100 lines and is the reusable half.
- **`privacy/classified.ts` + `log/logger.ts`** — the `Classified<T,C>` phantom brand and a logger whose field type resolves any classified member, at any depth, to `never`. 175 lines together, zero runtime cost, and it makes `log.info('x', { capture: { body } })` a compile error.

**Without the crypto layer?** This *is* the crypto layer — but it splits three ways:

- `manifest.ts` machinery + `db/columns.ts` + `classification.ts`: **takeable with no crypto at all.** They are a column-registry with a throw-by-default policy.
- `classified.ts` + `logger.ts`: **takeable with no crypto at all**, and cheap. A branded-type logger is useful even in an app that stores plaintext.
- `crypto/*` + the KEK tree: this is the thing being deferred. Do not take it now.

**Judgement: TAKE `classification.ts`, `classified.ts`, `logger.ts`, `db/columns.ts`, and the manifest *machinery* (not its 330 lines of entries). LEAVE `crypto/**` until the privacy decision is made — but note where it would slot back in.**

**More coupled than it looks:**

- **`CLAUDE.md` records a standing exception**: the KEK lives in an environment variable (`crypto/kek/env.ts`), in the same trust domain as the database credential. Anyone harvesting this must not carry over privacy copy the arrangement does not support.
- **Key identity is deliberately not bound into ciphertext**, so KEK custody can migrate by rewrapping one small key per user. There is a test pinning it (`hands a corpus over to a different KEK without re-encrypting any of it`). If the new app ever takes the crypto, that property must be preserved or an afternoon's migration becomes one nobody performs.
- `audit/sink.ts` opens its **own** connection via `db()` rather than joining the caller's transaction — deliberate, so a rollback cannot erase the record of the access. It also counts its own failures (`auditWriteFailures()`) because a silently-failing audit sink is indistinguishable from a working one. Both details are easy to lose in a copy.
- `db/columns.ts` binds the sensitivity class into the AEAD associated data. A value sealed under the wrong class **will not open again**. This is why the class may only come from the manifest — a subtlety that is invisible until data is unrecoverable.

---

## 5. `src/copy/` discipline + tone-lint rules

| File | Lines |
|---|---|
| `eslint-rules/index.js` | 32 |
| `eslint-rules/paths.js` | 50 |
| `eslint-rules/copy-surface.js` | 129 |
| `eslint-rules/no-banned-vocabulary.js` | 163 |
| `eslint-rules/no-copy-outside-copy-module.js` | 151 |
| `eslint-rules/no-decrypt-outside-window.js` | 96 |
| `eslint-rules/no-provider-sdk-outside-providers.js` | 71 |
| `eslint-rules/no-query-on-classified-column.js` | 118 |
| `eslint-rules/no-raw-console.js` | 40 |
| `eslint-rules/no-unsafe-motion.js` | 141 |
| `config/banned-vocabulary.json` | 15 |
| `src/copy/**` (10 files) | **1929** |
| `tests/lint.test.ts` | 266 |
| `tests/copy.test.ts` | 58 |

**Dependency reach:** the rules are plain ESM `.js` with **no imports outside `eslint-rules/`** except `node:module`, `node:fs`, `node:path` and `../config/banned-vocabulary.json`. The copy module is **10 files, ~1929 lines, zero package dependencies**. Both are the most portable things in the repo.

Two rules do the pairing that makes the discipline work: `no-copy-outside-copy-module` fails any prose written in `src/app` or `src/components`, and `no-banned-vocabulary` then checks everything in `src/copy` plus JSX text, `aria-label`/`alt`/`placeholder`/`title` attributes, static JSX expression containers, and Next `metadata` keys. Neither runs over identifiers, comments, or ordinary code strings — `throw new Error('job failed')` stays legal, which is the design decision that keeps the rule from being disabled within a week. Escapes take an annotated `// tone-allow: <reason>` with a minimum 8-character reason.

The word list is data, not code:

```json
{ "terms": ["back on track","overdue","behind","inactive","0% complete","you should","don't forget","still not done"],
  "stems": ["abandon","fail","streak","distract","incomplete"],
  "suffixes": ["","s","es","ed","d","ing","ion","ions","ment","ness","ly"] }
```

**Without the crypto layer?** **Entirely** — `no-banned-vocabulary`, `no-copy-outside-copy-module`, `copy-surface.js`, `paths.js`, `no-raw-console.js` and `no-unsafe-motion.js` have nothing to do with privacy. `no-decrypt-outside-window.js` and `no-query-on-classified-column.js` are the two that do.

**Judgement: TAKE the lint infrastructure (`index.js`, `paths.js`, `copy-surface.js`, the two copy/tone rules, `no-raw-console.js`, `config/banned-vocabulary.json`, and `tests/lint.test.ts`). LEAVE `src/copy/**` — that is this product's voice, not a reusable asset.** Also take `no-provider-sdk-outside-providers.js` if the AI registry is taken; it is 71 lines and it is what keeps vendor shapes from leaking.

**More coupled than it looks:**

- **`no-query-on-classified-column.js` parses `manifest.ts` with a regex** (`/column:\s*'([^']+)'[\s\S]{0,400}?storage:\s*'([^']+)'/g`). Reformat the manifest, or take the rule without the manifest, and it silently matches nothing while still passing. `tests/lint.test.ts` is the only thing that catches that — take the test with the rule or don't take the rule.
- `no-decrypt-outside-window.js` names `src/lib/jobs/window.ts` by **path string**, and hard-codes `src/lib/crypto/*` module paths in `DEFAULT_GUARDED`. Every path is a configurable option, but the defaults assume this repo's layout.
- `no-banned-vocabulary.js` reaches `../config/banned-vocabulary.json` via `createRequire` — a relative filesystem path, not a module resolution. The JSON file must sit at that exact relative location.
- `eslint.config.mjs` scopes all seven rules to `files: ['src/**/*.{ts,tsx}']`. That scoping is a decision (they govern what ships, not the tooling) and is invisible in the rule files.
- The rules are ESLint **9 flat-config** plugin shape. A repo on eslint 8 cannot use them without rework.

---

## 6. Supabase migrations + RLS patterns

| Path | Count / Lines |
|---|---|
| `supabase/migrations/0001..0027_*.sql` | 27 files, **2080 lines** |
| `supabase/test/auth-shim.sql` | 73 |
| `scripts/db/apply.ts` | ~120 |
| `tests/db/rls.test.ts` | 221 |
| `tests/db/class.test.ts` | 135 |

17 of 27 migrations reference `auth.users`; 14 declare `auth.uid()` policies. The house patterns, all visible in `0003_captures.sql` and `0004_outbox.sql`:

- Every user-owned table: `user_id uuid not null references auth.users(id) on delete cascade`, `alter table … enable row level security`, then explicit per-verb policies `for select|insert|delete to authenticated using (user_id = auth.uid())`.
- **Deliberate absence of an update policy** where rows are meant to be immutable — and, crucially, a **trigger** alongside it, because RLS does not constrain the service identity that background jobs run under. `captures_reject_rewrite()` raises `restrict_violation` on any change to `body`, `source`, `captured_at`, `user_id` or `id`, and fires for every role.
- Machinery tables (`outbox`, `job_runs`, `audit_log`) get RLS **enabled with no policies at all** — deny-by-default for `authenticated`, reachable only by the service identity.
- Every content column carries `comment on column … is 'class:S2 storage:sealed'`, cross-checked against `manifest.ts` by `tests/db/class.test.ts` against the live catalogue. An entry with no column fails; a column with no entry fails.

**Without the crypto layer?** The **patterns**, yes, entirely. The **files**, no — every content column is `bytea` and every class comment asserts a posture the new app has not adopted.

**Judgement: LEAVE the migrations; TAKE `scripts/db/apply.ts` and `supabase/test/auth-shim.sql`; ADAPT the RLS patterns as conventions.** The migrations describe this product's domain (pursuits, threads, identity versions, weave). What is reusable is the four patterns above and the two scripts.

- `scripts/db/apply.ts` (~120 lines) applies `supabase/migrations/*.sql` in filename order, one transaction per file, with a `schema_migrations` ledger. Deliberately not the Supabase CLI and deliberately not an ORM.
- `auth-shim.sql` (73 lines) creates `anon` / `authenticated` / `service_role` (the last `bypassrls`) plus a minimal `auth.users` and `auth.uid()`, so migrations and the RLS suite can run against a bare Postgres. It also grants `authenticated` table-level access, because without it a cross-user read is denied for the *wrong reason* — permission rather than policy — and the RLS suite passes while proving nothing. That paragraph is the most valuable 6 lines in the file.

**More coupled than it looks:** the numbering scheme (`0001_`…`0027_`) is `apply.ts`'s convention, not the Supabase CLI's timestamp convention. Taking the migrations and running them through `supabase db push` will not behave as expected. Also `0001_extensions.sql` requires `pgvector`, which constrains where the database can be hosted.

---

## 7. Conformance test suite

| File | Lines |
|---|---|
| `tests/conformance/checks.ts` | 186 |
| `tests/conformance/no-alarm-or-decay.test.ts` | 263 |
| `tests/conformance/no-initiation.test.ts` | 293 |
| `tests/conformance/no-progress-fraction.test.ts` | 112 |
| `tests/conformance/no-request-time-synthesis.test.ts` | 121 |
| `tests/conformance/no-thread-ranking.test.ts` | 158 |
| `tests/conformance/text-on-ground.test.ts` | 186 |
| fixtures (4 files) | 47 |
| `tests/db/conformance.test.ts` | 339 |
| `tests/db/canary.test.ts` | 254 |

**Dependency reach: near zero** — every file imports only `node:fs/promises` and `vitest`. They are filesystem scanners that walk `src/` and regex the source.

`checks.ts` is the reusable core: `streakShaped()`, `captureSchemaViolations()`, `notificationTriggerSources()`, `viewTracking()`. Each is a name list plus a filter. The comments in it are the actual asset — they document three occasions where the rule was broken on purpose and **passed**, and the corrections that followed. The distilled lesson, stated three times in three different words: *a record of somebody doing something is fine; only a record of them being shown something, or of whether they went along with it, belongs on the list.* `seen_at` had to come off because it flagged `threads.first_seen_at`; `taken_at` had to come off because it flagged `backups.taken_at`.

**Without the crypto layer?** **Yes, completely.** No conformance test touches crypto.

**Judgement: ADAPT — take `checks.ts` and the pattern; leave the six suites.** The pattern (a mission prohibition expressed as a scanner over your own source, each with a deliberately-broken fixture proving it fires) transfers to any product with product-level rules it wants to keep. The specific prohibitions — no streaks, never initiate, no progress fractions, no thread ranking — are The Scenic Route's mission, and only transfer if the new app shares it.

**More coupled than it looks:**

- **The suites hard-code paths and will throw, not fail, in a repo without them.** `no-initiation.test.ts` reads `src/app/(app)/page.tsx` and `src/lib/interview/kinds/unstuck.ts`; one assertion expects exactly `['src/app/(app)/onboarding/interview/page.tsx', 'src/app/(app)/onboarding/page.tsx']`. Copied into a new repo, this suite is red on arrival.
- The `db/` half needs a live Postgres. `vitest.config.ts` defines two projects; the `db` project runs `globalSetup` which **resets the whole database**, forces `singleFork`, and injects a test KEK (`Buffer.alloc(32, 0x2a)`). Taking the db conformance tests means taking that harness — `tests/db/setup.ts`'s `withRollback`, `global-setup.ts`, `scripts/db/reset.ts`.
- `VIEW_TRACKING_ALLOWED = ['home_offers.dismissed_at']` is a qualified single-column exception with three pages of reasoning. Copy the mechanism (qualify exceptions by full column name, never shorten the list), not the entry.

---

# theRealJobSearch

Context that governs everything below: **the repo does not describe its own database.** Three sources disagree.

| Source | Table | Columns |
|---|---|---|
| `supabase/migrations/20240315_create_jobs_table.sql` | `jobs` | `company_name, job_title, status, created_at, updated_at` |
| `src/lib/jobs.ts` (`TABLE_NAME`) | `jobs` | via `Tables<"jobs">` — **not a key of the `Database` type** |
| `src/types/database.types.ts` | `db_jobs` | `company_name, job_title, job_description, url, status, date_created, date_applied, date_rejected` |
| `src/repository/jobs/supabase-jobs-repository.ts` (`TABLE_NAME`) | `db_jobs` | plus `user_id`, which is in no type |

The live schema is `db_jobs`, created by hand in the hosted Supabase project. **The migration in the repo is dead** — it creates a table nothing reads, and `supabase/seed.sql` seeds it with a `'wishlist'` status that is not in the `JobStatus` union. Commit `eb84946 "limit users to their data"` added RLS; `grep` over `supabase/` finds **no policy, no `enable row level security`, no `user_id`** anywhere. The RLS exists only in the hosted project and is not recoverable from this repo.

## 8. Job status vocabulary — `src/repository/jobs/types.ts` (62 lines)

Lines 7–30 are the harvestable part and are fully standalone:

```ts
export type JobStatus = "created" | "applied" | "interview" | "offer" | "rejected" | "ghosted";
export const statusLabels: Record<JobStatus, string> = { … };
export interface JobFilters { status?, companyName?, search?, limit?, offset? }
```

**Dependency reach:** lines 1–5 import `Tables`/`Inserting`/`Updating` from `@/types/database.types` (71 lines). The union and the label map import nothing.

**Without the crypto layer?** Not applicable — no crypto in this repo.

**Judgement: TAKE the union and `statusLabels` — as a starting vocabulary, not as a settled one.** Six statuses that survived real use, including `ghosted`, which is the one nobody designs in advance and everybody needs. About 25 lines, worth 25 lines.

**More coupled than it looks:**

- **The union is enforced nowhere.** The DB column is `status TEXT` with no `CHECK`; `Job["status"]` is `string`, not `JobStatus`. The union is decoration that three separate places re-list by hand — `jobs-service.ts` has the six statuses written out twice more (`getJobCountByStatus`, `isValidStatus`), both with `status as any` casts at the call sites.
- `statusLabels` is user-facing copy sitting in a repository type file — the exact arrangement The Scenic Route's `no-copy-outside-copy-module` rule exists to prevent. If both repos are harvested into one app, this file violates the other repo's lint rule on arrival.

## 9. `JobsRepository` interface + Supabase implementation

| File | Lines |
|---|---|
| `src/repository/jobs/types.ts` (interface, lines 32–62) | 31 |
| `src/repository/jobs/supabase-jobs-repository.ts` | 186 |
| `src/repository/jobs/index.ts` | 25 |
| `src/services/jobs-service.ts` | 135 |
| `src/hooks/use-jobs.ts` | 118 |
| `src/lib/jobs.ts` (superseded duplicate) | 104 |

The interface is a clean six-method CRUD contract (`getJobs`, `getJobById`, `createJob`, `updateJob`, `deleteJob`, `countJobs`). The implementation behind it is not clean.

**Dependency reach:** repository → `@/lib/supabase/client` (7 lines, `createBrowserClient`) → `@/types/database.types`. Shallow. `use-jobs.ts` → `jobs-service` → `repository`, a three-layer stack for CRUD.

**Judgement: TAKE the interface; LEAVE the implementation; LEAVE the service and hook.**

The `JobsRepository` interface is 31 lines of good, honest shape and is genuinely worth copying. The Supabase implementation is not.

**More coupled than it looks / defects found:**

- **Type-broken, confirmed statically.** `src/lib/jobs.ts` does `Tables<typeof TABLE_NAME>` with `TABLE_NAME = "jobs"`, but `keyof Database["public"]["Tables"]` is `"db_jobs"` only. That is a hard compile error, in four functions. This file is also **dead** — nothing imports it; the repository superseded it and it was never deleted. That is what commit `3961d13 "job typing?"` (the final commit) was mid-way through.
- The repository does `.eq('user_id', user?.id)` and inserts `user_id` on a typed client whose `db_jobs` Row has **no `user_id` field**. More type errors, and the `user?.id` may be `undefined` — `.eq('user_id', undefined)` silently returns every row rather than none.
- **Every method opens its own client** — `createClient()` is called inside all six, and `getJobs`/`createJob`/`countJobs` each additionally `await supabase.auth.getUser()`, a network round trip per call.
- `updateJob` has its only real content commented out (`// updated_at: …`), leaving `{...updates}` spread into itself. Same for the `.order("created_at")` in `getJobs` and in `lib/jobs.ts`. The repo is littered with commented-out lines that were the actual behaviour.
- `console.error` on every failure, then rethrow.
- `getJobCountByStatus` in `jobs-service.ts` issues **six sequential `COUNT` queries**, awaited in a `for` loop. `use-jobs.ts` calls it on every filter change alongside two more queries — eight round trips per load, six of them serialisable into one `group by`.
- The singleton in `index.ts` (`getJobsRepository` / `resetJobsRepository`) is a module-level mutable — fine here, a hazard in a server-rendered app where module scope is shared across requests.

## 10. `src/app/dashboard/page.tsx` — ISO-week bucketing (167 lines)

The bucketing logic is roughly lines 24–78. Dependencies: `date-fns` (`startOfWeek`, `getISOWeek`, `getISOWeekYear`), `lodash` (`groupBy`), `recharts` for the chart.

```ts
const getWeekNumber = (date: Date) => {
  const start = startOfWeek(date, { weekStartsOn: 1 });
  return `${getISOWeekYear(start)}-W${getISOWeek(start)}`;
};
```

Then: build 9 empty buckets stepping 7 days from `today - 56 days`; `groupBy` the filtered jobs by week key; fill each pre-seeded bucket by counting `created` / `applied` / `rejected`; sort by parsed `(year, weekNum)`.

**Judgement: ADAPT — the *idea*, not the file.** Pre-seeding empty buckets so weeks with no activity render as zero rather than vanishing from the axis is the correct instinct and the thing people get wrong. Everything around it needs rewriting.

**Defects and coupling:**

- **The file is broken as written.** `"use client"` is line 1, and the default export `DashboardPage` is an **`async function` component** that calls the *browser* Supabase client. React 18 does not support async client components; this is not a thing that renders.
- The week key is **unpadded** — `2026-W5` sorts before `2026-W12` lexically. The code dodges this by `parseInt`-ing the halves back out for the sort, having thrown away the numbers it already had two lines earlier.
- `for (let i = 0; i < 9; i++)` builds nine buckets for a range described as eight weeks. Off-by-one, or an undocumented inclusive end.
- Jobs landing in a week not pre-seeded are **silently dropped** — `if (allWeeks[week])` with no `else`.
- Only three of the six statuses are ever charted. `interview`, `offer` and `ghosted` are counted in the stat tiles above and disappear from the graph below.
- `startOfWeek(date, { weekStartsOn: 1 })` before `getISOWeek` is redundant — ISO weeks already start Monday. Harmless, but it signals the ISO semantics were not understood.
- `new Date(job.date_created)` with no null guard; `date_created` is typed `string` but has no `NOT NULL` behind it.
- A `useEffect` `console.log`ging `processedData` on every change was left in.
- `lodash` is pulled in whole for one `groupBy`. `Object.groupBy` is native in the Node 22 the other repo targets.

---

# Summary table

| Candidate | Files | Lines (own / transitive) | Needs crypto? | Call |
|---|---|---|---|---|
| `outbox/drain.ts` | 1 | 184 / ~1085 | No | **Take** |
| `runJob` + registry + descriptor | 4 | 379 / ~1134 | No | **Take** |
| `withPlaintext` + `opener.ts` | 2 | 299 / ~2977 | Injectable | **Take** (passthrough codec) |
| `outbox/write.ts` (`enqueue`) | 1 | 111 / ~2790 | Injectable | **Take** |
| `worker.ts` + cron tick (scheduler seam) | 3 | 269 | No | **Adapt** |
| AI registry + `capability.ts` | 2 | 298 | No | **Take** |
| AI providers | 4 | 547 | No | **Adapt** (model ids stale) |
| `net/allowlist.ts` | 1 | 47 / 47 | No | **Take** |
| `privacy/policy.ts` + `classification.ts` | 2 | 132 | No | **Take** |
| `classified.ts` + `logger.ts` | 2 | 175 | No | **Take** |
| manifest *machinery* + `db/columns.ts` | 2 | ~175 of 508 | No | **Take** |
| `crypto/**` + KEK tree | 12 | 936 | Is the crypto | **Leave for now** |
| `capture.ingest` | 1 | 174 / ~3891 | Injectable | **Adapt** |
| `capture.split` | 1 | 238 / ~4605 | Injectable | **Leave** |
| `capture/payload.ts` + `request.ts` | 2 | 288 | No | **Take** |
| eslint copy/tone rules + `paths`/`copy-surface`/config | 6 | 640 | No | **Take** |
| `no-provider-sdk-outside-providers.js` | 1 | 71 | No | **Take** |
| `no-decrypt-outside-window` / `no-query-on-classified-column` | 2 | 214 | Guards it | **Leave for now** |
| `tests/lint.test.ts` | 1 | 266 | No | **Take** (with the rules) |
| `src/copy/**` | 10 | 1929 | No | **Leave** (this product's voice) |
| `supabase/migrations/**` | 27 | 2080 | Schema is bytea | **Leave** |
| `scripts/db/apply.ts` + `auth-shim.sql` | 2 | ~193 | No | **Take** |
| RLS + immutability-trigger patterns | — | — | No | **Adapt** as convention |
| `tests/conformance/checks.ts` | 1 | 186 | No | **Adapt** |
| conformance suites (6) | 6 | 1133 | No | **Leave** (hard-coded paths) |
| db test harness (`setup.ts`, `global-setup.ts`) | 2 | ~90 | Injects a KEK | **Adapt** |
| `JobStatus` + `statusLabels` | part of 1 | ~25 | n/a | **Take** |
| `JobsRepository` interface | part of 1 | 31 | n/a | **Take** |
| `SupabaseJobsRepository` | 1 | 186 | n/a | **Leave** |
| `jobs-service.ts` + `use-jobs.ts` | 2 | 253 | n/a | **Leave** |
| `src/lib/jobs.ts` | 1 | 104 | n/a | **Leave** (dead + won't compile) |
| ISO-week bucketing | part of 1 | ~55 | n/a | **Adapt** (idea only) |
| theRealJobSearch migration + seed | 2 | ~25 | n/a | **Leave** (describes a dead table) |

**Rough totals if the "Take" column is acted on:** about **3,000 lines** of source from The_Scenic_Route (jobs/outbox spine, AI registry, privacy vocabulary without the crypto, lint infrastructure, db scripts) plus **~60 lines** from theRealJobSearch. The 10,000-line figure that a naive `src/lib/capture/**` copy would produce is almost entirely this product's domain.

---

# Three things worth deciding before the harvest starts

1. **Take the `BoundCrypto` seam even though the privacy decision is deferred.** Harvesting `withPlaintext` with a passthrough codec costs ~30 extra lines today and preserves the descriptor/manifest/audit discipline. Harvesting the pipeline *without* it means every future privacy decision is a rewrite of every job, which is exactly the position The Scenic Route built this layer to avoid. The one thing that must not be copied is any user-facing copy describing a posture the new app does not have.

2. **The lint rules are the highest value-per-line asset in either repo and are almost free to take** — ~640 lines, no dependencies, and they encode a specific lesson (a rule that fires on correct code is one somebody disables within a week) that shows up three separate times in `checks.ts` as a correction. Take `tests/lint.test.ts` with them; `no-query-on-classified-column` in particular passes silently when broken.

3. **Nothing in theRealJobSearch's data layer should be copied, only read.** The repo cannot describe its own schema: the migration creates a table nothing uses, the generated types omit the column every query filters on, the RLS lives only in a hosted project, and the final commit left the codebase with hard compile errors. What is worth taking is a 25-line status union, a 31-line interface, and one design instinct about pre-seeding empty time buckets. Budget an hour, not a day.
