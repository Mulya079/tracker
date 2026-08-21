# 1. Mission sentence, working name, and the rule they bind

Date: 2026-08-21

## Status

Accepted

## Context

`tracker` is a repository name, not a product name, and the project had no governing sentence. The Scenic Route has one, and its `CLAUDE.md` gives it authority over any spec that disagrees. The mechanism is worth copying; that sentence is not, because this app does a different job.

The candidate framing from charting joined two claims with an "and": making the effort you pour into finding work visible to you, and turning it into the material that makes the next application better. Those are two products. The first is a dashboard, which a spreadsheet and every tracker on the market already provide. The second is the claim in the map's own notes, that the notes you take while chasing work are the same data your CV needs.

Ground through on [#3](https://github.com/Mulya079/tracker/issues/3).

## Decision

**The compounding claim governs.** The mission sentence is:

> Tracker helps a person keep work coming by turning what they capture while chasing it into a profile that makes each approach stronger than the last.

**The app is a companion, not an instrument.** It brings the person opportunities they did not find, including pursuits that have gone quiet, on its own initiative.

**It is a career-long instrument.** It is written for someone maintaining a steady flow of work over years. A discrete job search is a period of higher intensity within that, not a separate mode, and no Campaign entity exists in the MVP.

**Tracker stays as a working name.** A full design and naming pass happens once the MVP is validated (#18). `CONTEXT.md` and prose say "Tracker" and the rename is one commit.

**The sentence is a guide, not a veto.** Where a spec disagrees with it, that is argued on the ticket.

**One derived rule binds until the MVP cut line (#16):** every feature serves one of the five jobs in `CONTEXT.md`, and the ticket names which one.

**Jobs 1 to 3 beat jobs 4 and 5** when they compete for the same work.

## Consequences

The kill list in `CONTEXT.md` follows from the rule. A contacts CRM, a general notes surface and importing The Scenic Route's corpus attach to no job and are not built.

Jobs 4 and 5 re-promote the application tracker that the compounding claim demoted. This is deliberate: the product is unusable without stage management and a view of where effort went. The tiebreak is what stops them absorbing the whole MVP, and it has a cost. Weeks of tracker polish will be lost to profile work whose benefit is not felt immediately.

Because sourcing is part of the definition rather than a later feature, [#14](https://github.com/Mulya079/tracker/issues/14) sits above the cut line, and an empty pipeline on day one is a failure state rather than a normal start.

An earlier version of this decision took a sharper rule, that a feature must feed the profile or spend it. It was weakened because it killed the analytics page, the calendar and the board, all of which are wanted in the MVP. A rule that gets applied beats a sharper one that gets carved up.

## Amending

Changing the sentence, the five jobs, the rule or the tiebreak takes a new ADR superseding this one.
