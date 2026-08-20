# Opportunity sourcing surfaces and what they permit

Research for [Mulya079/tracker#8](https://github.com/Mulya079/tracker/issues/8) (part of [#2](https://github.com/Mulya079/tracker/issues/2)).
Date: 2026-08-20. Fact-finding only — this settles no product question.

## Method, and its limits

Outbound HTTP from this session was restricted: direct page fetches (`WebFetch`, `curl`) were
blocked by the egress proxy for every third-party host tried. All evidence below comes from
web search scoped to the owning domain, which surfaces text from the primary page but does not
let me read the page end to end.

What that means for how you read this file:

- Every link points at the primary source. Follow it before you build against it.
- Quoted wording is wording the search index returned *from that primary page*. It has not been
  byte-verified against the live page in this session.
- Anything I could not trace to the owning domain is labelled **[unverified]** and should be
  treated as a lead, not a fact.
- Rate limits and prices are the most volatile facts here. Re-check every one at build time.

---

## Verdict first

1. **Jobs is solved, but not by job boards.** The aggregators that own the demand (Indeed,
   LinkedIn) are closed or partner-gated. The open path is the *ATS layer* — Greenhouse, Lever,
   Ashby, SmartRecruiters, Personio, Workable, Teamtailor all expose per-employer public job
   feeds with no auth — plus national public employment services (Germany, France, US) which
   publish real APIs on open terms.
2. **Creative grants is a crawl-and-parse problem** with three structured exceptions:
   Grants.gov (US, unauthenticated), the EU Funding & Tenders Portal (covers Creative Europe),
   and — for *past* grants only, not open calls — 360Giving and UKRI Gateway to Research.
   No UK or Irish arts council publishes open calls in a machine-readable form.
3. **Freelance clients has no legitimate posting surface worth building on.** Upwork's API is
   explicitly personal/internal use only, Fiverr forbids scraping outright, and the rest have no
   public API. If sourcing means anything here it means *intent signals* from open registries
   (Companies House) and open social protocols (Bluesky, Mastodon) — a different pipeline
   entirely.
4. **"Publicly reachable" is not "permitted".** Several surfaces below return data to an
   unauthenticated GET *and* forbid automated collection in their terms. Where that is the case
   I say so and stop; no workaround is described anywhere in this file.
5. **Attribution and freshness are the real constraints,** not rate limits. Several permitted
   feeds carry conditions that shape the product: Remotive delays jobs 24 hours and forbids
   using listings to harvest signups; Adzuna requires a specific visual credit on every ad shown.

---

# 1. Jobs

## 1.1 Summary table

| Surface | Access | Auth | Cost | Automated access permitted? |
|---|---|---|---|---|
| Greenhouse Job Board API | JSON REST, per-employer | none for GET | free | Yes — data is published as public |
| Lever Postings API | JSON/HTML, per-employer | none | free | Yes |
| Ashby Posting API | JSON, per-employer | none | free | Yes |
| SmartRecruiters Posting API | JSON REST, per-employer | none | free | Yes, 10 req/s |
| Personio | XML feed, per-employer | none | free | Yes |
| Teamtailor | XML feed, per-employer | none, opt-in by client | free | Yes, where the client enabled it |
| Workable | JSON, per-employer | token (`r_jobs`) for full API | free w/ account | Yes, account-scoped |
| Bundesagentur für Arbeit (DE) | JSON REST | static client id header | free | Yes, public API |
| France Travail Offres d'emploi | JSON REST | OAuth, free account | free | Yes, under a reuse licence |
| USAJOBS (US) | JSON REST | API key (email + key header) | free | Yes, but **use is scoped to the registered company** |
| Grants.gov-style public feeds | — | — | — | see §2 |
| Adzuna | JSON REST | `app_id` + `app_key` | free tier; commercial = 14-day trial then negotiate | Yes, with heavy attribution conditions |
| Jooble | JSON REST | per-country key | free key, **500 lifetime calls** [unverified] | Yes, key issued on request |
| Careerjet | JSON REST | affiliate ID | free w/ partner account | Yes, "frequency of calls you can make is limited" |
| Remotive | JSON REST | none | free | Yes, with attribution + 24h delay + no-signup-harvesting condition |
| We Work Remotely | READ API + RSS | key for API | free tier | API yes (1,000/day); **scraping explicitly prohibited** |
| Hacker News (Algolia + Firebase) | JSON REST | none | free | Yes; official HN API has no rate limit |
| **Indeed** | Publisher Job Search API **deprecated** | partner agreement | n/a | **No** — closed to new integrations |
| **LinkedIn** | Job Posting API partner-only, **closed to new partners** | signed agreement | n/a | **No** — scraping prohibited by the User Agreement |
| Welcome to the Jungle (ex-Otta) | no first-party public API found | — | — | Not established; resellers exist [unverified] |
| Google Cloud Talent Solution | v4 API, employer-side | GCP | GCP pricing | Not an aggregator of others' jobs |

## 1.2 The ATS layer — the actual answer for jobs

Modern applicant tracking systems publish each customer's open roles at a stable public URL so
the customer can build their own careers page. That publication is the *intended* use, which is
what makes reading it legitimate. The trade-off: it is per-employer, so you need a list of board
tokens; there is no cross-employer search.

**Greenhouse** — [Job Board API](https://developers.greenhouse.io/job-board.html).
"Job Board data is publicly available, so authentication is not required for any GET endpoints."
Only the application-submission POST needs Basic Auth. The separate
[Harvest API](https://harvestdocs.greenhouse.io/docs/api-rate-limiting) (customer-private data)
is rate limited "to the amount specified in the returned `X-RateLimit-Limit` header, per 10
seconds", returning HTTP 429 over the limit — but Harvest is not the sourcing surface, the Job
Board API is. No published rate limit on the public board endpoints; treat politely.

**Lever** — [Postings API](https://github.com/lever/postings-api), base
`https://api.lever.co/v0/postings/`. "The Postings API is a publicly accessible API that
provides access to your company's published job postings; it is often used to set up a custom
jobs page." No authentication for GETs. Responds JSON or HTML per `Accept:` header or `?mode=`.
HTTPS only. Lever also documents an
[XML job posting feed](https://help.lever.co/hc/en-us/articles/20087377566109-Using-Lever-s-XML-job-posting-feed).
No published rate limit.

**Ashby** — [public job posting API](https://developers.ashbyhq.com/docs/public-job-posting-api),
`https://api.ashbyhq.com/posting-api/job-board/{board}`. No API key. Read-only, one board at a
time, no filtering or search. Ashby's own docs note this is what partner boards (LinkedIn,
Indeed, Otta, Built In, ZipRecruiter, Levels.fyi) consume. The authenticated
[`jobPosting.list`](https://developers.ashbyhq.com/reference/jobpostinglist) endpoint carries an
explicit instruction for public use: "If you are using the API to publicly expose job postings,
set the `listedOnly` parameter to `true` … so that you only fetch listed job postings that can be
displayed publicly." That distinction matters — respect it.

**SmartRecruiters** — [Posting API](https://developers.smartrecruiters.com/docs/posting-api).
"The Posting API is available without authentication and contains publicly available data."
[Rate limiting](https://developers.smartrecruiters.com/docs/rate-limiting): up to 10 requests
per second for most endpoints, 8 concurrent requests, `X-RateLimit-Concurrent-Limit` and
`-Remaining` headers on every response, 429 + `Retry-After` on violation. This is the best
documented of the ATS group.

**Personio** — public XML feed per customer, no auth:
`GET https://{company}.jobs.personio.de/xml?language=en`
([support doc](https://support.personio.de/hc/en-us/articles/207576365-Integrate-jobs-from-Personio-into-your-website-via-XML),
[API reference](https://developer.personio.de/v1.0/reference/get_xml)). Strong EU/DACH coverage,
which matters given the UK/EU bias in the brief.

**Teamtailor** — public XML feed exists but "it is up to the client to activate this and share
the URL"; richer data is behind the [Client API](https://docs.teamtailor.com/) (JSON:API,
`api.teamtailor.com` for EU stack). So coverage is opt-in and patchy.

**Workable** — [API docs](https://workable.readme.io/reference/jobs). The full `/jobs` endpoint
needs a Super Admin-generated token with the `r_jobs` scope; default page size 50. A lighter
public endpoint exists for browser use: `https://www.workable.com/api/accounts/<account>`
([help doc](https://help.workable.com/hc/en-us/articles/115012771647-Using-the-Workable-API-to-create-a-careers-page)).

**Recruitee** is reported to sit in the same no-auth-option group **[unverified]** — I did not
reach a Recruitee-owned page confirming it.

**Freshness:** all of these read live from the employer's own ATS, so they are the freshest job
data that exists — fresher than any aggregator, which is downstream of exactly these feeds.

## 1.3 National public employment services

These are the only cross-employer job search APIs on genuinely open terms.

**Germany — Bundesagentur für Arbeit Jobsuche API.**
[Docs](https://jobsuche.api.bund.dev/), OpenAPI spec at
[`openapi.yaml`](https://jobsuche.api.bund.dev/openapi.yaml). Search endpoint `/pc/v6/jobs`;
details fetched by base64 `refnr`; employer logos at `/ct/v1/arbeitgeberlogo`. Auth is an
`X-API-Key` header carrying the fixed client id `jobboerse-jobsuche` — i.e. no registration.
Free. Largest job database in Germany. Note this is a community-maintained spec of the BA's own
public API (bund.dev is the German government's own developer portal umbrella).

**France — France Travail (ex-Pôle emploi) Offres d'emploi API.**
[API page](https://francetravail.io/data/api/offres-emploi). Free: "use it freely while
respecting the conditions mentioned in the France Travail job offers database reuse licence and
by creating an account on francetravail.io." Two quota levels — a per-API ceiling (the Offers
API "supports a maximum load of 100 calls per second") and a per-application share of it. OAuth
via the francetravail.io developer account. **Read the reuse licence before building** — it is
the binding document and I could not read it directly.

**US — USAJOBS.** [Developer site](https://developer.usajobs.gov/guides/). API key + request
header, free. Two things in the terms matter more than the rate limit:
"Data provided to you through the API is for the explicit use of the requesting company
identified on the USAJOBS Program Office API Registration Form. No other use of the data
provided is permitted without prior approval, in writing, from OPM USAJOBS." And OPM "retains
the right, at its sole discretion, to create limits at any time with or without notice on the
number of API transactions." The
[Historic JOAs endpoint](https://developer.usajobs.gov/API-Reference/GET-api-HistoricJoa)
"does not require authorization or authentication. The data returned by this endpoint is
publicly consumable" — but that is historic, not live vacancies.

**EU — EURES.** The [portal](https://europa.eu/eures/portal/) aggregates ~3 million vacancies,
"updated daily by the European employment services". I found **no public vacancy API or open
data feed** for EURES. ESCO (the occupation/skills taxonomy behind it) *is* machine-readable and
has its own API, but ESCO is a classification, not a vacancy source. Treat EURES as: valuable,
not currently machine-readable, worth a direct enquiry to the EURES helpdesk before assuming.

**UK — Find a job (DWP).** [Service](https://findajob.dwp.gov.uk/),
[employer guide](https://www.gov.uk/government/publications/advertise-your-vacancies/find-a-job-guide-for-employers).
Employers can bulk-upload vacancies "as a feed", so an inbound feed mechanism exists — but I
found **no published outbound API, feed, or developer documentation** for reading vacancies. The
UK's structured-job-data story is notably worse than Germany's or France's. Worth a direct
enquiry; do not assume a read path exists.

## 1.4 Commercial aggregators

**Adzuna** — [developer portal](https://developer.adzuna.com/),
[terms of service](https://developer.adzuna.com/docs/terms_of_service). `app_id` + `app_key` as
query params against `https://api.adzuna.com/v1/api/jobs/{country}/search/1`. Nine endpoints:
ad search plus salary/vacancy trend data. The terms are the constraint, not the tech:

- Attribution is prescriptive: every displayed ad must be labelled "Jobs by Adzuna" at least
  116 × 23 pixels, with "Jobs" hyperlinked to the relevant Adzuna domain and "Adzuna" rendered
  as the Adzuna logo image, also hyperlinked. Salary and vacancy data must credit "The Adzuna
  API" with a link.
- "Data may not be used in its original format or in aggregation (including but not limited to
  vacancy counts, average salaries etc) to deliver any ongoing work or research without written
  consent."
- "Any usage that appears to be an attempt to extract Confidential Information for commercial
  reuse will immediately be considered a breach of these terms and conditions."
- "Any use of the Adzuna API by commercial, government or academic organisations is permitted
  subject to a 14 day trial period, strictly for validating general coverage and quality of
  data in addition to usability testing." Beyond that: negotiate.
- Adzuna "has absolute discretion over granting access" and may suspend on suspected violation.

Free-tier volume is widely reported as ~1,000 calls/month **[unverified]** — I could not confirm
a published number on an Adzuna page. Assume it is small and confirm on signup.

Read plainly: Adzuna is fine for a personal-scale tool with visible credit, and requires a
commercial conversation the moment this is a product. The aggregation clause is the one that
bites a tracker that stores and re-derives.

**Jooble** — [REST API docs](https://help.jooble.org/en/support/solutions/articles/60001448238-rest-api-documentation).
Free key on request per country domain (`jooble.org` = US, `uk.jooble.org` = UK, etc.), each key
scoped to its own market. Reported free plan cap: **500 requests total, lifetime, per key**
**[unverified]** — if true, this is a demo, not a data source.

**Careerjet** — [public search API](https://github.com/careerjet/careerjet-api-client-python).
"If you are a webmaster and would like to embed Careerjet search results into your website,
please feel free to use their public search API." Requires an affiliate ID from a Careerjet
partner account. "In order to avoid misuse of the API, the frequency of calls you can make is
limited" — no number published. Note the framing: it is an *embed* API, aimed at displaying
Careerjet results, not at building a private index.

**Indeed — closed.** The [Publisher Job Search API](https://developer.indeed.com/docs/publisher-jobs/job-search)
and [Get Job](https://developer.indeed.com/docs/publisher-jobs/get-job) are marked deprecated and
"not available for new integrations". What Indeed still runs is the employer/ATS direction:
[Job Sync API](https://docs.indeed.com/job-sync-api/job-sync-api-guide) pushes jobs *into*
Indeed, Indeed Apply routes applications, and all of it sits under the
[Indeed Partner Developer Agreement](https://docs.indeed.com/legal-terms/additional-api-terms-and-guidelines).
There is no read path for a job-seeker tool. **State it plainly: Indeed is not available.**
(Glassdoor is part of the same group; its old partner API is likewise not an open path.)

**LinkedIn — forbidden.** Two separate closures:

- *Scraping.* [User Agreement §8.2](https://www.linkedin.com/legal/user-agreement) prohibits
  users from developing, supporting or using "software, devices, scripts, robots or any other
  means or processes (such as crawlers, browser plugins and add-ons or any other technology) to
  scrape or copy the Services, including profiles and other data from the Services", and bars
  "bots or other unauthorized automated methods to access the Services". LinkedIn's
  [prohibited software help page](https://www.linkedin.com/help/linkedin/answer/a1341387)
  confirms enforcement: accounts restricted or shut down, tools made non-operational without
  notice. There is also a separate
  [Crawling Terms and Conditions](https://www.linkedin.com/legal/crawling-terms) governing the
  narrow permitted-crawler case.
- *API.* The [Job Posting API](https://learn.microsoft.com/en-us/linkedin/talent/job-postings/api/overview)
  is partner-gated and "LinkedIn is currently not accepting new partnerships for the Job Posting
  API." Access requires meeting criteria and signing an API agreement with data restrictions
  ([getting access](https://learn.microsoft.com/en-us/linkedin/shared/authentication/getting-access)).

LinkedIn is ruled out. No further discussion.

**Google Cloud Talent Solution** — [v4 is live](https://cloud.google.com/talent-solution/job-search/docs/apis);
v3/v3p1beta1/v4beta1 shut down 13 October 2021 ([release notes](https://cloud.google.com/talent-solution/docs/release-notes)).
Relevant only if *you* hold a corpus and want Google's matching over it. It is not a source of
other people's jobs.

## 1.5 Remote boards, RSS, and the long tail

**RSS is not dead, but it is thin.** The pattern survives mostly on niche remote boards.

**We Work Remotely** — this one has an unusually clear line and it is worth quoting because it
draws the boundary the whole ticket is about.
[API terms](https://weworkremotely.com/api-terms-and-guidelines): "The only We Work Remotely
data you may use in your product or application is that which is exposed via the API. Scraping,
copying, saving, or storing their data is strictly prohibited and against their Terms of
Service." Rate limit: 1,000 requests/day per authenticated user, 429 over quota, with ETag /
`If-None-Match` and Last-Modified / `If-Modified-Since` caching offered as the intended fix.
"Attempts to circumvent rate limiting, such as leveraging multiple applications, are strictly
prohibited." There are also public
[category RSS feeds](https://weworkremotely.com/remote-job-rss-feed) (programming split by
front/back/full-stack, design, devops, sales & marketing, customer support, management &
finance, all-other). So: **API and RSS yes, scraping no.**

**Remotive** — [public API](https://github.com/remotive-com/remote-jobs-api),
`https://remotive.com/api/remote-jobs`. No auth. Conditions that shape the product:
listings must link back to the job's original Remotive URL and credit Remotive as source;
republishing to third-party job boards may get access revoked; "displaying jobs in order to
collect signups/email addresses to show a listing constitutes a breach of their terms of
service"; and **jobs are delayed by 24 hours** deliberately, so Remotive gets attributed first.
The endpoint is "for sharing Remotive's listings, not bulk scraping" — cache, don't poll hard.
The signup-gating clause is worth flagging to product: it constrains what the surface around a
Remotive-sourced listing may do.

**Hacker News "Who is hiring?"** — the monthly thread is a real freelance/contract source and it
is fully open. Two APIs:
[official Firebase API](https://github.com/hackernews/api), which has **no rate limit**, and
[HN Search by Algolia](https://hn.algolia.com/api) for querying thread comments. Free, no auth.
Freshness: monthly cadence, comments live. This is the single cheapest structured-ish source in
the whole survey, and it straddles jobs and freelance.

**Welcome to the Jungle (merged with Otta, January 2024)** — I found no first-party public API.
Third-party job-data resellers claim to carry it; those are their own contracts, not WTTJ's
permission, and I did not verify what WTTJ's terms say. **[unverified]** Treat as unresolved.

---

# 2. Creative grants

## 2.1 The shape of the problem

The ticket's hypothesis is right. **There is no grants equivalent of the ATS layer.** Arts
funders publish open calls as prose on CMS pages, announce them by newsletter, and — in the UK
and Ireland especially — publish *awarded* grants as open data while publishing *open calls* as
web pages. Those are opposite ends of the lifecycle, and only the useless end is machine-readable.

Three structured exceptions exist, and they are all governmental.

## 2.2 Summary table

| Surface | Region | Access | Auth | Cost | Covers open calls? |
|---|---|---|---|---|---|
| Grants.gov `search2` | US | JSON REST | **none** | free | Yes |
| Simpler.Grants.gov API | US | JSON REST | API key | free | Yes |
| EU Funding & Tenders Portal (SEDIA) | EU | structured search over public index | none for published calls | free | Yes — incl. Creative Europe |
| 360Giving / GrantNav | UK | API + bulk CSV/JSON + datastore | none | free, CC-BY-SA | **No — awarded grants only** |
| UKRI Gateway to Research | UK | REST, JSON + XML | none | free, OGL | **No — funded projects only** |
| Arts Council England | UK | web pages + published award lists | n/a | n/a | No machine-readable calls |
| Creative Scotland / ACW / ACNI / Arts Council Ireland | UK+IE | web pages, newsletters | n/a | n/a | No |
| Candid (Foundation Directory / Grants API) | Global | JSON REST | subscription key | paid, custom | Partly — funder/grant data |
| Instrumentl | US-centric | API on top plans only | subscription | $179–$499/mo | Yes, within their index |
| ArtRabbit / Artquest / CuratorSpace | UK/intl | web pages, weekly email | n/a | free to read | No published API |
| Submittable | Global | v3/v4 API | customer key | tied to a paid plan | It is the *host*, not a directory |

## 2.3 The three that work

**Grants.gov (US federal).** [API resources](https://grants.gov/api),
[Search2 reference](https://grants.gov/api/common/search2). The key fact:
"The primary endpoint, `v1/api/search2`, is designed to be accessible without user
authentication (in other words, no login or authentication key required)." POST JSON to
`https://api.grants.gov/v1/api/search2`. Free. This is the single most permissive grants surface
found. A parallel modernised API is being built at
[Simpler.Grants.gov](https://simpler.grants.gov/developers) — that one *is* keyed, with a
default of **60 requests/minute and 10,000/day per key**. US-only, and mostly not arts —
but NEA and NEH opportunities do appear there.

**EU Funding & Tenders Portal (SEDIA).** [Portal](https://ec.europa.eu/info/funding-tenders/opportunities/portal/),
and — important — the portal maintains its own
[APIs support page](https://ec.europa.eu/info/funding-tenders/opportunities/portal/screen/support/apis).
This is the single entry point (Single Electronic Data Interchange Area) for all Commission-managed
funding, which means **Creative Europe calls live here**: see the
[CREA programme page](https://ec.europa.eu/info/funding-tenders/opportunities/portal/screen/programmes/crea2027)
and, e.g., call identifier `CREA-CULT-2026-COOP`. Reported behaviour: anonymous access for
published calls and project data; EU Login + API keys only for submission and management
functions **[unverified — from a third-party integration guide, not the Commission's own API
page]**. The search index is faceted on call/topic identifier, title, description, keywords and
tags, and calls carry explicit opening and closing dates — which is exactly the structure a
deadline-aware tracker wants.

**This is the highest-value grants target in the whole survey for a UK/EU creative user.** Verify
the terms on the Commission's own APIs page before building; the underlying data is public-sector
information and the Commission's general reuse policy is permissive, but confirm rather than assume.

## 2.4 The UK trap: awarded ≠ open

Two excellent UK open-data sources exist and **neither lists open calls**. Do not let their
quality mislead the architecture decision.

**360Giving / GrantNav.** [GrantNav](https://grantnav.threesixtygiving.org/),
[technical docs](https://www.360giving.org/explore/technical/). Full dataset downloadable as
CSV or JSON; a [360Giving API](https://www.360giving.org/explore/technical/grantnav-data/)
exists for scripts and applications; direct read-only Datastore access is available for complex
needs ("ideal for accessing large amounts of data in one go but not for high volumes of repeated
queries"). Licensed **CC-BY-SA** — attribution required, and derived works must carry the same
licence, which is a real constraint on a closed product. The
[Data Standard](https://standard.threesixtygiving.org/en/latest/reference/) is a proper spec
(JSON canonical, tabular equivalent). But its subject is grants that have *already been made*.
Its use to this project is funder discovery and prior-art — "who funds work like mine" — not
"what can I apply to this month".

**UKRI Gateway to Research.** [API resources](https://gtr.ukri.org/resources/api.html),
[GtR-2 API](https://gtr.ukri.org/resources/gtrapi2.html). Two API versions; GtR-2 returns JSON
and XML and is versioned independently of the UI. Data under the **Open Government Licence** —
the most permissive licence in this file. Endpoints: Projects, Organisations, People,
Publications, Search. Again: funded projects, not open calls. UKRI's live calls sit on
[ukri.org/opportunity](https://www.ukri.org/opportunity/) as web pages.

**Find a grant (GOV.UK).** [Service](https://www.find-government-grants.service.gov.uk/) —
central government grant opportunities, searchable and filterable. I found **no documented public
API** for it. The Cabinet Office publishes *awards* to 360Giving standard, again the wrong end of
the lifecycle. This is a crawl-and-parse target, and being a GOV.UK service its markup is likely
stable and its `robots.txt` permissive — check both.

## 2.5 Arts councils: prose, all the way down

- **Arts Council England** — [Project Grants](https://www.artscouncil.org.uk/ProjectGrants),
  [open funds](https://www.artscouncil.org.uk/our-open-funds),
  [Project Grants data](https://www.artscouncil.org.uk/ProjectGrants/project-grants-data).
  ACE publishes award lists per year and a National Investment Dashboard. **No API, no feed, no
  structured open-calls file found.** Open funds are HTML pages with guidance PDFs.
- **Creative Scotland** — [funding programmes](https://www.creativescotland.com/funding/funding-programmes),
  including the [Open Fund for Individuals](https://www.creativescotland.com/funding/funding-programmes/open-funding/open-fund-for-individuals)
  (£5m annual budget, R&D and delivery up to 24 months). Distribution channel is a newsletter.
  No feed found.
- **Arts Council of Wales / Arts Council of Northern Ireland** — same pattern; the
  [Four Nations International Fund](https://www.creativescotland.com/news-stories/latest-news/archive/2026/01/funding-available-uk-arts-councils-expand-support-international-cultural-partnerships)
  is announced as news, not data.
- **Arts Council Ireland** — [funding opportunities](https://artscouncil.ie/funding/funding-opportunities/),
  a filterable HTML index. No feed found.

So: **crawl-and-parse, with per-funder adapters.** The mitigating facts are that the set of
funders worth watching is small (tens, not thousands), their pages change slowly, and the fields
that matter (title, deadline, amount, eligibility, link) are few. That is a tractable extraction
problem for a model, and it is one where "raw captures are immutable, derived rows are
regenerable" pays off directly — re-parse when the extractor improves rather than migrating.

## 2.6 Aggregators

- **ArtRabbit** — [artist opportunities](https://www.artrabbit.com/artist-opportunities).
  Curated weekly from submissions, newsletters, magazines and blogs; emailed to ~19,000
  practitioners; every opportunity vetted. Editorially the best-matched source found for a
  creative user. **No public API or documented feed found, and I did not establish its terms on
  automated access.** Ask them — a curated human-vetted list is exactly the kind of asset whose
  owner may say yes to a small licensed feed and no to a crawler.
- **Artquest, CuratorSpace** — same shape; nothing machine-readable surfaced.
- **Candid** (Foundation Directory, Grants API) — [developer portal](https://developer.candid.org/),
  [API terms](https://developer.candid.org/page/candid-api-terms-of-service),
  [licence agreement](https://candid.org/terms-of-service/api-license-agreement/). Real,
  documented, subscription-keyed. Free trial keys available via a request form; production
  pricing via sales, usage-based options with usage reporting in the portal. Sandbox APIs only
  come with a paid API and may not be used in production. Data compiled from 990/990-PF filings,
  direct foundation reporting and 35+ monitored sources — i.e. **funder intelligence, skewed
  US**, more than a European open-calls calendar.
- **Instrumentl** — [API integration](https://help.instrumentl.com/en/articles/10020925-api-integration):
  API only on Full Lifecycle, Enterprise and University plans. Plans $179–$499/month, 14-day
  trial. US nonprofit-centric.
- **GrantStation** — $179/yr or $249/2yr membership; database access, no API surfaced.
- **Submittable** — [v4 API](https://submittable-api.submittable.com/docs/v4/index.html),
  [v3](https://submittable-api.submittable.com/docs/v3/index.html). Worth understanding for what
  it *is*: the platform many arts organisations use to *run* their calls. Its API is scoped to
  your own account's submissions, obtained via your Customer Success Manager. It is not a
  directory of other people's open calls. Rate limits not surfaced.

---

# 3. Freelance clients

## 3.1 The reframe

The ticket is right that this is the least posting-shaped of the three, and the research
sharpens why: **the marketplaces that do have postings mostly forbid or refuse programmatic
reading of them.** So "sourcing" splits into three candidate meanings, only two of which are
buildable on legitimate terms.

1. **Marketplace briefs** (Upwork, Fiverr, Freelancer, Malt, PeoplePerHour) — largely closed.
2. **Intent signals** from open registries and open protocols — open, and legal, but noisy and
   requires inference.
3. **The user's own inbound** — email, DMs, existing contacts. Not a sourcing surface at all;
   it is capture. Worth naming because it may be the honest answer.

## 3.2 Summary table

| Surface | Access | Auth | Cost | Automated access permitted? |
|---|---|---|---|---|
| **Upwork** | GraphQL API | OAuth, approved key | free | **Personal and internal use only — commercial use not supported** |
| **Fiverr** | no public data API | — | — | **No — "any attempts to scrape data from the Fiverr platform are strictly prohibited"** |
| Freelancer.com | REST + OAuth | key | free tier | Yes, under [API T&Cs](https://www.freelancer.com/about/apiterms); cache must refresh ≥ every 24h |
| Malt | none found | — | — | Not established; no public API |
| PeoplePerHour | none found | — | — | Not established; no public API |
| Contra | none found | — | — | Not established |
| Hacker News (freelancer threads) | Firebase + Algolia | none | free | Yes, no rate limit on official API |
| **Reddit** (r/forhire etc.) | Data API | OAuth | free tier; commercial = separate agreement | Non-commercial yes; **commercial requires a signed agreement** |
| Bluesky / AT Protocol | public XRPC | none for public endpoints | free | Yes, "generous rate-limits" |
| Companies House (UK) | REST | free API key | free | Yes, 600 req / 5 min |
| Crunchbase | REST | subscription | custom, sales-gated | Yes, per licence tier |
| X / Twitter | REST | key | pay-per-use credits; enterprise from $50k/mo | Yes, at cost |

## 3.3 Marketplaces

**Upwork — read the usage clause before anything else.**
[Developer space](https://www.upwork.com/developer),
[GraphQL docs](https://www.upwork.com/developer/documentation/graphql/api/docs/index.html),
[API request limits](https://support.upwork.com/hc/en-us/articles/115015933428-What-are-the-API-requests-limits),
[requesting a key](https://support.upwork.com/hc/en-us/articles/115015857647-How-to-request-an-API-key-from-Upwork).

The disqualifying line: **"Upwork API is available for personal and internal use only.
Commercial use isn't supported."** Access is by application — any membership plan may request,
Upwork reviews and replies in roughly a week, and most rejections are for missing account
requirements. Rate limit: 10 requests/second per IP, 429 over. No sandbox or test accounts for
third-party developers.

What that means concretely: a person automating *their own* Upwork job feed for their own use is
inside the stated purpose. A product that reads Upwork on behalf of its users is not. If this app
ever ships to anyone but its author, Upwork is out unless Upwork says otherwise in writing.
Design for that now rather than discovering it later.

**Fiverr — forbidden, full stop.** [Terms of Service](https://www.fiverr.com/legal-portal/legal-terms/terms-of-service),
[Community Standards](https://help.fiverr.com/hc/en-us/articles/32242973123985-Our-Community-Standards):
"Any attempts to scrape data from the Fiverr platform are strictly prohibited." No public data
API surfaced; the [Affiliate Agreement](https://www.fiverr.com/legal-portal/legal-terms/affiliate-agreement)
governs a marketing programme, not data access. Ruled out.

**Freelancer.com — the one open marketplace.** [Developer portal](https://developers.freelancer.com/),
[API Terms & Conditions](https://www.freelancer.com/about/apiterms). Grants "a limited,
non-exclusive, non-assignable, non-transferable licence to use the API to develop, test, and
support software applications, websites, or products, and to integrate the API with your
products or services" — note that *does* contemplate integration into your products, unlike
Upwork. Constraints: no attempting "to exceed or circumvent limitations on access via rate limit
or any other method"; no "excessive or abusive usage"; and a cache condition — "Where Data is
cached, users should refresh the cache at least every 24 hours … this limited permission to
cache is for performance reasons only." OAuth. Specific numeric rate limits were not surfaced;
get them from the developer portal. Quality of briefs on Freelancer.com is a separate product
question, not a research one.

**Malt, PeoplePerHour, Contra** — no public developer API found for any of them. Third-party
scraper products exist on Apify and similar; those are the scraper vendor's offering, not the
platform's permission, and nothing in this file endorses them. Treat all three as: no
established legitimate programmatic path. If Malt matters for the EU freelance market
specifically, a partnership enquiry is the route.

## 3.4 Intent signals — the actually-open surfaces

If sourcing here means "notice that someone is about to need what I do", these are open on
documented terms.

**Companies House (UK).** [Developer guidelines](https://developer.company-information.service.gov.uk/developer-guidelines/),
[rate limiting](https://developer-specs.company-information.service.gov.uk/guides/rateLimiting).
Free API key. "You can make up to 600 requests within a 5 minute period", 429 thereafter, reset
at the end of the window; higher limits by request; "we reserve the right to ban without notice
applications that regularly exceed or attempt to bypass the rate limits." There is also a
**streaming API** for real-time filings. New incorporations, new officers, filed accounts —
these are genuine, legal, freely-licensed signals of commercial activity. Coverage is UK only.

**Bluesky / AT Protocol.** [Rate limits](https://docs.bsky.app/docs/advanced-guides/rate-limits),
[API hosts and auth](https://docs.bsky.app/docs/advanced-guides/api-directory),
[`app.bsky.feed.searchPosts`](https://docs.bsky.app/docs/api/app-bsky-feed-search-posts).
"Many Bluesky Lexicon endpoints are public and do not require authentication" and should be
called against `https://public.api.bsky.app`, which is cached and is the host Bluesky asks
"public web" use cases to use. "These API services have generous rate-limits" and Bluesky asks
developers to contact them if limited; 429 + rate-limit headers on responses. Post search over
an open network with no key and no cost is a genuinely unusual affordance in 2026. Mastodon's
public timeline/search APIs sit in the same category (per-instance terms).

**Hacker News.** Covered in §1.5 — the "Who wants to be hired / freelancer seeking freelancer"
threads are the same mechanism as "Who is hiring". Free, unlimited, monthly.

**Reddit — usable non-commercially, gated commercially.** r/forhire, r/hiring, r/slavelabour and
craft-specific subs are real freelance demand. Reddit's Data API Terms require a **separate
agreement with Reddit for commercial purposes**; the free tier is capped at **100 queries per
minute per OAuth client id**, averaged over a 10-minute window, and since late 2025 there is an
explicit approval gate for new products. *Caveat: reddit.com and redditinc.com are not accessible
to this search agent, so all of this is second-hand and **[unverified]**. Read
`redditinc.com/policies/data-api-terms` directly before relying on any of it.*

**Crunchbase.** [API](https://about.crunchbase.com/products/crunchbase-api),
[licence agreement](https://data.crunchbase.com/docs/license-agreement),
[FAQ](https://support.crunchbase.com/hc/en-us/articles/32319290128019-Crunchbase-API-FAQ).
Funding rounds are the classic "they just raised, they'll be hiring contractors" signal — but
"access to the `funding-rounds` endpoint requires Enterprise or Applications access", and
pricing is custom, sales-gated, and scaled by end-user count. Priced for a company, not a person.

**X / Twitter.** [Pricing](https://docs.x.com/x-api/getting-started/pricing). Now pay-per-usage
credits rather than fixed tiers; Basic and Pro remain available; from 20 April 2026 "Owned
Reads" are $0.001 per resource. Enterprise "starts at $50,000 / Month". Search over *other
people's* posts — which is what an intent-signal pipeline needs — is the expensive half. Hard to
justify against free Bluesky and HN.

---

# 4. Cross-cutting notes

**"Publicly reachable" is not "permitted".** Several surfaces in this file return data to an
unauthenticated GET and *still* forbid automated collection — We Work Remotely is the crisp
example: public RSS and a documented API, and "scraping, copying, saving, or storing their data
is strictly prohibited". The permission question is answered by the terms, not by the HTTP
status code. Where the answer is no, this file says no and stops.

**Read `robots.txt` as a first-class input, not a formality.** For every crawl-and-parse target
in §2, the funder's `robots.txt` and terms page should be recorded alongside the adapter, and the
adapter should refuse to run if either changes. That is cheap to build now and impossible to
retrofit credibly.

**Attribution obligations are product constraints.** Adzuna's pixel-dimension credit,
Remotive's link-back and no-signup-gating clause, 360Giving's CC-BY-SA share-alike — each of
these dictates something visible in the UI or in the licence of derived output. They belong in
the spec, not in an integration ticket.

**Freshness ranking, best to worst.** ATS feeds (live, employer-authored) > national employment
service APIs (daily) > Grants.gov / EU portal (as published) > commercial aggregators (hours to
days, and Remotive deliberately 24h) > crawled arts council pages (whatever your crawl cadence
is) > 360Giving / GtR (retrospective by months).

**Cost ranking.** Free and unauthenticated: ATS feeds, Grants.gov `search2`, Lever, Ashby,
SmartRecruiters, Personio, HN, Bluesky public endpoints. Free with a key: BA Jobsuche, France
Travail, USAJOBS, Companies House, Adzuna (non-commercial), Simpler.Grants.gov. Paid or
negotiated: Adzuna commercial, Candid, Crunchbase, Instrumentl, X. Closed at any price to a
newcomer: Indeed, LinkedIn.

**Ruled out, stated plainly and not revisited:** Indeed (read APIs deprecated, closed to new
integrations), LinkedIn (User Agreement §8.2 prohibits automated access; Job Posting API closed
to new partners), Fiverr (scraping strictly prohibited, no data API), Upwork for any commercial
product (API is personal and internal use only), Malt / PeoplePerHour / Contra (no legitimate
programmatic path established).

---

# 5. What still needs answering

These are the gaps this session could not close, ranked by how much they change the architecture.

1. **EU Funding & Tenders Portal API terms and endpoint shape** — read
   [the portal's own APIs page](https://ec.europa.eu/info/funding-tenders/opportunities/portal/screen/support/apis).
   This is the highest-value grants surface for a UK/EU creative user and my evidence for it is
   the weakest in the file.
2. **France Travail's reuse licence** — the binding document behind "use it freely".
3. **Adzuna's actual free-tier quota and the commercial terms past the 14-day trial** — decides
   whether Adzuna is a real source or a demo.
4. **Reddit's Data API Terms, read directly** — the domain is unreachable from this session.
5. **Whether DWP Find a job has any read API** — a direct enquiry, since the UK is otherwise the
   weakest jobs-data jurisdiction in this survey despite being the primary market.
6. **ArtRabbit's terms, and whether they would license a feed** — a conversation, not a crawl.
7. **Jooble's 500-lifetime-call figure** — if true, delete Jooble from consideration.
8. **A canonical list of ATS board tokens for employers the user cares about** — the ATS route
   is only as good as this list, and building it is the real work in §1.2.

---

## Filing note

Issue #8 asks for the findings as a Markdown file in `Mulya079/tracker`, linked from the issue.
This session was instructed not to modify the repo, so the file sits at the scratchpad path it
was written to. The repo currently has no research directory; matching the existing
`docs/agents/` convention, `docs/research/sourcing-surfaces.md` would be the consistent home.
