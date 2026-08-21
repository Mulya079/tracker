# Context

The domain model for this repository. Read this before exploring the codebase.

Tracker is a working name. The product is unnamed until the MVP is validated (#18).

## Mission

Tracker helps a person keep work coming by turning what they capture while chasing it into a profile that makes each approach stronger than the last.

The sentence describes what makes this different from a spreadsheet. It is a guide, not a veto: where a spec disagrees with it, say so on the ticket and argue it out. Amending it takes an ADR.

## The five jobs

Every feature serves one of these, and the ticket says which. A feature that serves none waits until after the MVP cut line (#16).

1. **Capture the work of chasing work.** Anything noticed while chasing an opportunity goes in fast and unstructured. A capture either updates an opportunity already in flight or starts a new one, and the app decides which. This is what feeds the profile.
2. **Bring the next opportunity.** The app watches feeds and proposes what to go after, filtered by what the profile knows. It also raises pursuits that have gone quiet and follow-ups that are due, on its own initiative rather than waiting to be asked.
3. **Make the case.** CVs and cover letters rendered from the profile, tailored per opportunity.
4. **Carry the opportunity through.** Stages, next actions, follow-ups, scheduling.
5. **Show whether it is working.** Where effort went, and what came back.

The profile is not a job. It is the mechanism the mission sentence names: job 1 feeds it, jobs 2 and 3 spend it.

Jobs 4 and 5 are an application tracker, and a spreadsheet already does them. They ship because the product is unusable without them. When they compete with jobs 1 to 3 for the same work, jobs 1 to 3 win.

## Ruled out

Not built, on any of the five jobs:

- **A contacts CRM.** People are attributes of opportunities and captures, not a separate thing to manage.
- **A general notes surface** with no path into an opportunity or the profile.
- **Importing The Scenic Route's corpus** as seed profile material. It is material from a different mission.
- **Anything that attaches to none of the five jobs.**

## Glossary

Terms are added here as tickets settle them. `Opportunity` and its kinds, origin, states and outcomes are being decided on #4. `Profile` is on #5. `Capture` and what gets extracted from one is on #10. `Lead` is on #14.

## Decisions

See `docs/adr/`.
