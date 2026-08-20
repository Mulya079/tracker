# Provider retention terms for the model calls this app needs

Research record for [Mulya079/tracker#7](https://github.com/Mulya079/tracker/issues/7).
Checked **2026-08-20**. Every quote below was pulled from the vendor's own
policy or terms page on that date.

The question: which providers offer zero data retention **in writing**, today,
for four call types, and on what plan or tier.

| # | Call type |
|---|---|
| A | Structured extraction from a pasted job posting (schema-constrained output) |
| B | Long-context generation for CV and cover-letter rendering |
| C | Text embeddings for similarity search |
| D | Document parsing / OCR for CV upload (PDF, DOCX) |

---

## 0. Read this first: what this session could and could not check

Outbound HTTPS from this session goes through a policy-enforcing egress proxy.
**Most vendor domains are blocked by that policy.** Two candidates' primary
sources were reachable and are quoted in full below. Everything else is
recorded as **unverified**, with the exact URL that still needs checking.

Blocked, confirmed by direct probe on 2026-08-20 (`403`/`connect_rejected` from
the proxy, not a vendor error):

`openai.com` · `platform.openai.com` · `developers.openai.com` ·
`help.openai.com` · `trust.openai.com` · `ai.google.dev` ·
`docs.cloud.google.com` · `policies.google.com` · `aws.amazon.com` ·
`docs.aws.amazon.com` · `learn.microsoft.com` · `azure.microsoft.com` ·
`mistral.ai` · `docs.mistral.ai` · `legal.mistral.ai` · `cohere.com` ·
`docs.cohere.com` · `voyageai.com` · `docs.voyageai.com` ·
`developers.deepgram.com` · `docs.llamaindex.ai` · `unstructured.io` ·
`reducto.ai` · `openrouter.ai` · `together.ai` · `fireworks.ai` ·
`www.anthropic.com` · `privacy.claude.com` · `support.claude.com`

Reachable: `platform.claude.com`, `cloud.google.com`.

Search-engine result summaries were available and were used to locate candidate
URLs. **They are not cited as terms anywhere in this document.** A search
summary is a paraphrase of a page nobody in this session read, which is weaker
evidence than the marketing copy the ticket already rules out.

Verification status is marked on every provider:

- **VERIFIED** — the vendor's own policy/terms page was fetched today and is quoted verbatim.
- **CARRIED FORWARD** — a first-party quote this organisation recorded on an earlier date, not re-checked today.
- **BLOCKED** — could not reach the vendor's pages; nothing is asserted about its terms.

---

## 1. Anthropic — Claude API — VERIFIED

**Source:** <https://platform.claude.com/docs/en/manage-claude/api-and-data-retention>
("API and data retention", Claude Platform Docs). Fetched 2026-08-20.
Supporting pages, same date:
<https://platform.claude.com/docs/en/build-with-claude/pdf-support>,
<https://platform.claude.com/docs/en/build-with-claude/structured-outputs>,
<https://platform.claude.com/docs/en/build-with-claude/embeddings>.

### Is zero retention the default?

**No. It is requested, per organisation, through sales.**

> Under a ZDR arrangement, Anthropic does not store customer prompts or
> responses at rest after the API response is returned. To request ZDR for your
> organization, contact the Anthropic sales team. ZDR is enabled per
> organization; each new organization requires ZDR to be enabled separately by
> your account team, and enablement does not automatically extend to other
> organizations under the same account.

The FAQ on the same page repeats the route with no self-serve alternative:

> To request a ZDR arrangement, contact the Anthropic sales team.

Compare the *default*, which the same page states plainly:

> Conversation content (your prompts and Claude's outputs) is not retained by
> default; the exception is Covered Models, which require 30-day retention.

Note the wording carefully. "Not retained by default" is Anthropic's statement
of its standard posture; ZDR is the *contractual* form of it. For a decision
procedure that requires a written term rather than a stated practice, the
enforceable version is the ZDR arrangement, and that arrangement is sales-gated.

### What it covers, per call type

The page carries a per-feature eligibility table. Relevant rows, verbatim from
the "ZDR eligible" column:

| Feature | Endpoint | ZDR eligible | Details column |
|---|---|---|---|
| Messages API | `/v1/messages` | Yes | — |
| 1M token context window | `/v1/messages` | Yes | — |
| PDF support | `/v1/messages` | Yes | "HIPAA eligibility applies to PDFs sent inline through the Messages API, not through the Files API." |
| Structured outputs | `/v1/messages` | **Yes (qualified)** | "Your prompts and Claude's outputs are not stored. Only the JSON schema is cached, for up to 24 hours since last use. This also covers strict tool use (`strict: true` on tools), which uses the same grammar pipeline." |
| Prompt caching | `/v1/messages` | Yes | — |
| Citations | `/v1/messages` | Yes | — |
| **Files API** | `/v1/files` | **No** | "Files retained until explicitly deleted or they reach their configured expiration." |
| **Batch processing** | `/v1/messages/batches` | **No** | "29-day retention; async storage required." |
| Code execution | `/v1/messages` (with `code_execution`) | No | — |
| Claude Managed Agents | `/v1/agents`, `/v1/sessions` | No | — |

The legend for the qualified value:

> **Yes (qualified):** Your prompts and Claude's outputs are not stored, but a
> bounded technical artifact (named in the Details column) is retained briefly
> for the feature to function.

Mapping to the four call types:

- **A (structured extraction)** — covered, with the schema-cache qualification. The JSON schema is a fact about *this application*, not about a person's CV, so a 24-hour schema cache carries no user content. Acceptable.
- **B (long-context generation)** — covered. Messages API and the 1M context window are both plain "Yes".
- **C (embeddings)** — **not offered at all.** From the embeddings guide: "Anthropic does not offer its own embedding model." There is no endpoint, so there is no term.
- **D (document parsing / OCR)** — **partially covered, and the shape matters.** PDF support is ZDR-eligible *when the PDF is sent inline in the Messages API*. Uploading it to the Files API is not: "Files retained until explicitly deleted or they reach their configured expiration." The FAQ is explicit that this is a live footgun rather than a blocked path:

  > Nothing blocks the request. Features marked "No" for ZDR are fundamentally
  > stateful: the Batch API stores your jobs, the Files API stores your files,
  > and code execution runs in persistent containers. […] Using them is a choice
  > to step outside your ZDR arrangement for that specific data.

  So a ZDR organisation that uploads a CV to `/v1/files` has silently left ZDR
  for that CV. Nothing errors.

### Disqualifiers and limits

1. **No embeddings.** Call type C needs a second vendor regardless.
2. **DOCX is not supported.** From the PDF support page: "Binary formats such as .xlsx or .docx are not supported in document blocks and must be converted to text or PDF first." Call type D is only half-served.
3. **Covered Models are excluded from ZDR entirely.**

   > **Claude Fable 5 and Claude Mythos 5:** These models require 30-day data
   > retention and are not available under ZDR.

   And, mechanically:

   > On the Claude API, requests to Claude Fable 5 from an organization whose
   > data retention configuration does not meet this requirement return a `400
   > invalid_request_error`.

   This is the same finding already recorded in The Scenic Route's
   `src/lib/ai/providers/anthropic.ts`, still true on 2026-08-20. The most
   capable model is structurally unavailable under a zero-retention posture. The
   error is the posture working, not a bug to route around.
4. **Flagged content survives ZDR, for up to two years.**

   > Even with ZDR or HIPAA arrangements in place, Anthropic may retain data
   > where required by law or where it has been flagged by Anthropic's automated
   > trust and safety systems. As a result, if a chat or session is flagged,
   > Anthropic may retain inputs and outputs for up to 2 years.

   Worth stating out loud for a CV-tailoring app: a false positive on a
   trust-and-safety classifier means a stranger's CV is retained for two years.
   No provider examined avoids some version of this clause, but it must not be
   described to users in terms the clause does not support.
5. **CORS is off under ZDR.** "CORS is not supported for organizations with ZDR arrangements. […] route requests through a backend proxy server." This app already needs a server-side path, so it costs nothing here, but it forecloses ever calling the API from the browser.
6. **Console and Playground are outside ZDR.** Pasting a real CV into the Console to debug a prompt is a retention event. Worth a line in whatever runbook exists.

### Where the data processor is not Anthropic

> This page covers the Claude API (`api.anthropic.com`), Claude Platform on AWS,
> and Claude in Microsoft Foundry, where Anthropic is the data processor. On
> Amazon Bedrock and Google Cloud's Agent Platform, the cloud provider is the
> data processor; refer to those platforms' data retention and compliance
> documentation for their equivalent controls.

And in the FAQ:

> No. The ZDR and HIPAA arrangements described on this page apply to the Claude
> API, where Anthropic is the data processor. On Bedrock and Google Cloud, the
> cloud provider is the data processor; refer to those platforms' data retention
> and compliance policies for their equivalent controls.

So "use Claude via Bedrock" is a different retention question with a different
answer, governed by AWS's terms — which this session could not reach (§4).

---

## 2. Google Cloud — Gemini Enterprise Agent Platform (formerly Vertex AI) — VERIFIED

**Source:** <https://cloud.google.com/terms/service-terms> — "Service Specific
Terms", **last modified July 29, 2026**. Fetched 2026-08-20. Service definitions
from <https://cloud.google.com/terms/services>, same date.

This is a contract page, not a docs page, which is the strongest class of source
available for this question.

### Is zero retention the default?

**Effectively yes, and it requires no request, no plan tier and no negotiation.**
The terms are incorporated into the ordinary Google Cloud agreement:

> These Service Specific Terms are incorporated into the agreement under which
> Google has agreed to provide Google Cloud Platform and SecOps Services (as
> described at https://cloud.google.com/terms/services) to Customer (the
> "Agreement").

Two clauses carry the substance.

**§18, Training Restriction:**

> Google will not use Customer Data to train or fine-tune any AI/ML models
> without Customer's prior permission or instruction.

**§20(h), Handling of Prompts and Generated Output:**

> Absent Customer's prior permission or instruction, Google will not store
> outside Customer's Account (i) Customer Data prompted to a Generative AI
> Service for longer than is reasonably necessary to create the Generated
> Output, or (ii) the Generated Output.

Read that precisely. It is a *no-storage-beyond-processing* term, which is the
substance of zero retention, but the wording is "longer than is reasonably
necessary" rather than a hard "not at rest after the response is returned". It
is also scoped to storage **outside Customer's Account** — data Google writes
into your own project is yours and is not covered by this clause. That is
weaker, on its face, than Anthropic's ZDR sentence, and stronger in that it is
in the default contract rather than behind a sales call. It is a genuine
trade-off and should be recorded as one, not flattened.

### What it covers, per call type

The scope of §20(h) turns on what counts as a "Generative AI Service". The
Services Summary names them explicitly, and the list settles two of the four
call types:

> **Generative AI Services**
> Note: In addition to the named Generative AI Services, for the purpose of
> applicability of the Generative AI Service Specific Terms, Generative AI
> Services also includes any Generally Available generative AI features of a
> Service.
> […]
> **Generative AI on Gemini Enterprise Agent Platform (formerly Generative AI on
> Vertex AI)** […] includes the following:
> **Gemini Enterprise Agent Platform API (formerly Vertex AI API)** enables
> customers to access generative AI foundation models via an API.
> […]
> **Embeddings API** generates unified text, image, video, and audio vector
> embeddings to enable high-precision semantic search, classification, and
> agentic retrieval workflows.

- **A (structured extraction)** — covered. Gemini via the platform API is a named Generative AI Service.
- **B (long-context generation)** — covered, same clause.
- **C (embeddings)** — **covered.** The Embeddings API is named in the list, so §20(h) reaches it. This is the only verified provider in this document with a written no-storage term over embeddings.
- **D (document parsing / OCR)** — **not covered by §20(h).** Document AI is defined in the Services Summary under the general AI/ML services, *not* under the "Generative AI Services" heading:

  > **Document AI**: Document AI is a unified console for document processing
  > that lets you quickly access all document processing models and tools.
  > Customers can use Document AI's Document Workbench to build custom document
  > classification, extraction or splitting models, or utilize pre-trained
  > models for document extraction, including OCR, Form Parser and specialized
  > models.

  §18's training restriction covers "any AI/ML models", so Document AI does
  inherit the no-training term. But the no-storage term is scoped to Generative
  AI Services and therefore does not reach it. **Document AI retention is an
  open question** — its data-governance page lives on `docs.cloud.google.com`,
  which is blocked (§4).

### Disqualifiers and open questions

1. **Abuse monitoring is referenced but not readable from here.** The terms carve out logging for abuse review and point at a documentation page:

   > Google uses automated safety tools to detect abuse of Generative AI
   > Services. Notwithstanding the "Handling of Prompts and Generated Output"
   > section in the Service Specific Terms for GCP Services, if these tools
   > detect potential abuse or violations of Google's AUP or Prohibited Use
   > Policy, Google may log prompts […] solely for the purpose of reviewing and
   > determining whether a violation has occurred. See the Abuse Monitoring
   > documentation page for more information […]

   The clause above appears in the Partner-Specific Terms and is written about
   Partners and Non-TOS Customers; a directly equivalent clause for ordinary
   customers was **not found** in the body of the Service Specific Terms. That
   does not mean no abuse logging happens to ordinary customers — it means the
   terms locate the detail on a documentation page this session cannot reach.
   **Treat Vertex/Gemini abuse-monitoring retention as unverified** until
   <https://docs.cloud.google.com/vertex-ai/generative-ai/docs/learn/abuse-monitoring>
   is read. This is the single most important gap in the Google finding.

2. **Document AI retention is unverified** (above).

3. **The Gemini API on `ai.google.dev` (AI Studio) is a different product with different terms** — free-tier usage there has historically permitted human review and training. `ai.google.dev` is blocked. Do not assume the Cloud terms carry over. If Google is chosen, it must be the Cloud/Vertex path with a billing account, not an AI Studio key.

4. **"Reasonably necessary" is a standard, not a deadline.** Anthropic's ZDR sentence names an event ("after the API response is returned"). Google's names a purpose. If the decision needs a bright line, Anthropic's wording is the sharper instrument, at the price of a sales conversation.

---

## 3. Carried forward from The Scenic Route — not re-verified today

These are first-party quotes this organisation recorded on **2026-08-02**,
against vendor pages that are blocked from this session. They are reproduced
because they are the same organisation's own primary-source check under the same
procedure, and because they bear directly on call type C. **They have not been
re-checked on 2026-08-20.** Source in-repo:
`/home/user/The_Scenic_Route/src/lib/ai/providers/voyage.ts` and
`deepgram.ts`.

### Voyage AI — embeddings — CARRIED FORWARD (checked 2026-08-02)

Recorded from `docs.voyageai.com/docs/faq`:

> For Voyage-hosted model API endpoints, customers can opt out from Voyage
> storing and using their data for future model training, so that there is a
> zero-day retention of the data.

The recorded reading: **zero retention is available and is not the default.** It
is an account-level opt-out set by an organisation admin with a payment method
on file. Not enterprise-gated — the owner can set it themselves — but also not
a term that binds without someone having flipped it.

Relevance here: Voyage is Anthropic's recommended embeddings provider (the
Anthropic embeddings guide, verified today, says "Anthropic does not offer its
own embedding model. One embeddings provider that has a wide variety of options
and capabilities […] is Voyage AI"). If the app runs Claude for A/B/D, Voyage is
the natural C. **Re-verify before binding**, per the procedure.

The Scenic Route's handling of this is worth copying rather than re-deriving:
because the guarantee lives in a dashboard the codebase cannot see, the provider
registers only when the environment separately asserts the toggle was set
(`VOYAGE_ZERO_RETENTION=confirmed`). A constant in code claiming zero retention
would be a claim about somebody else's dashboard.

### Deepgram — transcription — CARRIED FORWARD (checked 2026-08-02)

Not one of this ticket's four call types. Recorded only because it is the
strongest *shape* of guarantee found so far, and it is the shape to look for:

> The only data we will store and use in future model training is the data that
> is contractually included through participation in the Deepgram Model
> Improvement Partnership Program.

with a per-request opt-out (`mip_opt_out=true`) rather than an account setting.
A per-request parameter cannot be silently undone in a console nobody is
watching. If any candidate for call types A–D offers a per-request retention
flag, that beats an account toggle, which beats a sales agreement.

---

## 4. Could not verify — the list that still needs checking

Nothing is asserted about any provider below. Each row is a URL that a session
with wider egress, or the owner in a browser, must read and quote.

| Provider | Call types it could serve | Page to read | Why it is unverified |
|---|---|---|---|
| OpenAI | A, B, C, D | `platform.openai.com/docs/guides/your-data` (endpoint-level ZDR list); `openai.com/policies/…`; `trust.openai.com` | host blocked |
| Amazon Bedrock | A, B, C (and Claude models under AWS as processor) | `docs.aws.amazon.com/bedrock/latest/userguide/data-retention.html`; AWS Service Terms §50 at `aws.amazon.com/service-terms/` | host blocked |
| AWS Textract | D | `aws.amazon.com/service-terms/`; Textract FAQ | host blocked |
| Microsoft Foundry / Azure OpenAI | A, B, C | `learn.microsoft.com/azure/ai-foundry/responsible-ai/openai/data-privacy` | host blocked |
| Azure Document Intelligence | D | `learn.microsoft.com/azure/ai-services/document-intelligence/` (data privacy page) | host blocked |
| Mistral | A, B, C, D (Mistral OCR) | `docs.mistral.ai/admin/monitor-comply/zero-data-retention`; `legal.mistral.ai/terms/data-processing-addendum` | host blocked |
| Cohere | A, C | `cohere.com/terms-of-use`; `docs.cohere.com` deployment/privacy pages | host blocked |
| Voyage AI | C | `docs.voyageai.com/docs/faq`; `voyageai.com/terms` | host blocked (quote from 2026-08-02 carried forward, §3) |
| Google Document AI | D | `docs.cloud.google.com/document-ai/docs/data-governance` | host blocked |
| Google Vertex abuse monitoring | A, B, C | `docs.cloud.google.com/vertex-ai/generative-ai/docs/learn/abuse-monitoring` | host blocked — **gap in an otherwise verified finding** |
| Google Gemini API (AI Studio) | A, B, C | `ai.google.dev/gemini-api/terms` | host blocked |
| LlamaParse, Reducto, Unstructured, Datalab | D | vendor DPAs | hosts blocked |

Two of these matter more than the rest: **Bedrock**, because it would let Claude
serve A/B/D under a cloud provider's default terms rather than a sales-gated
arrangement; and the **Vertex abuse-monitoring page**, because it is the one
unread page that could weaken an otherwise clean Google finding.

---

## 5. What the four call types look like across what was verified

`Y` = written term found covering it. `—` = provider does not offer it.
`?` = offered, term not verified.

| | A extraction | B long-context | C embeddings | D parse/OCR |
|---|---|---|---|---|
| **Anthropic Claude API** (ZDR, sales-gated) | Y (schema cached 24h) | Y | — | Y for PDF **inline only**; DOCX unsupported; Files API is **not** ZDR |
| **Google Cloud** (default contract terms) | Y (§20h) | Y (§20h) | Y (§20h) | ? Document AI outside §20h; retention page unread |
| Everything else | ? | ? | ? | ? |

Three observations fall out of that table.

**No single verified provider covers all four.** Anthropic has no embeddings
endpoint; Google's document-parsing service sits outside its own no-storage
clause. Either choice is a two-vendor arrangement, which means the registry
needs per-capability retention posture rather than one provider-level flag —
which is the shape The Scenic Route already built.

**DOCX is nobody's problem but this app's.** Anthropic does not accept it.
Whatever Google's Document AI terms turn out to say, converting DOCX to text or
PDF *inside the app* is the option where the file never leaves. That is not a
workaround; it is the better answer, and it should be the plan even if a vendor
later turns out to accept DOCX under acceptable terms.

**The Files API footgun deserves a lint rule, not a note.** Anthropic's own FAQ
says nothing blocks a non-ZDR-eligible call. An app that uploads a CV to
`/v1/files` for convenience has left its retention posture with no error, no
warning and no log line. If Anthropic is bound, the code should be unable to
reach `/v1/files`.

---

## 6. The procedure this feeds

Following `The_Scenic_Route/plans/p2-capture/capture-spec.md` §5.2, this is a
decision procedure and not a vendor name. Restated for this repository:

1. Read the candidate's data-retention and training terms. Record the date, the URL and the exact wording next to the binding in code.
2. Bind only if the terms give zero retention **without** requiring a plan the owner is not on. Record which of the three shapes it is, because they are not equivalent:
   - **per-request flag** (strongest — cannot be undone in a console nobody watches)
   - **account toggle** (bind only behind an explicit environment acknowledgement that someone set it, the way `voyage.ts` does)
   - **negotiated agreement** (weakest to verify from code; the code cannot see the contract, so the acknowledgement pattern applies here too)
3. If nothing clears for a capability, leave it unbound and let the feature degrade visibly, rather than binding something weaker quietly.

Two additions this ticket earns:

4. **Retention is per capability and per endpoint, not per vendor.** Anthropic is ZDR-eligible on `/v1/messages` and not on `/v1/files` — the same vendor, the same account, the same CV, two different answers. A single `retention: 'zero-retention'` constant on a provider object would be false the moment a file upload is added.
5. **Record what the term does *not* cover.** Every provider examined retains flagged content, and the two-year figure in Anthropic's terms is the only one this session could read. No user-facing copy may describe the posture in terms these clauses do not support.

---

## 7. Bottom line

- **Anthropic Claude API** is the only provider with a plain, unambiguous zero-retention sentence covering call types A, B and D-as-inline-PDF — and getting it means contacting sales and having it enabled per organisation. It cannot serve C at all, cannot take DOCX, and its Files API silently sits outside the arrangement.
- **Google Cloud** is the only provider verified today whose no-storage term covers A, B **and** C, in the default contract, with no request and no tier. The wording is softer ("longer than is reasonably necessary", and only "outside Customer's Account"), its document-parsing service falls outside that clause, and one unread page on abuse-monitoring logging could change the picture.
- **Nothing else was verifiable from this session.** Bedrock and the Vertex abuse-monitoring page are the two follow-ups most likely to change the answer.
- **No verified provider covers all four call types.** Plan for two bindings and per-capability posture, and plan to do DOCX-to-text conversion in-app.
