## Mission

Tracker helps a person keep work coming by turning what they capture while chasing it into a profile that makes each approach stronger than the last.

Tracker is a working name. The product is unnamed until the MVP is validated (#18).

Treat the sentence as a guide. Where a spec disagrees with it, say so on the ticket and argue it out.

One rule derived from it binds until the MVP cut line (#16): **every feature serves one of the five jobs in `CONTEXT.md`, and the ticket names which one.** A feature that serves no job waits until after the cut line.

When jobs 4 and 5 compete with jobs 1 to 3 for the same work, jobs 1 to 3 win. The tracker half is what makes this usable; the profile half is what makes it worth building.

Amending the sentence or the rule takes an ADR in `docs/adr/`. See `docs/adr/0001-mission-and-working-name.md`.

## Agent skills

### Issue tracker

Issues live in GitHub Issues on `Mulya079/tracker`, using the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout (`CONTEXT.md` + `docs/adr/` at the repo root). See `docs/agents/domain.md`.
