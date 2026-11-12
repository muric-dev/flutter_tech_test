# Usage ledger

## Why I track this

This is not about micromanagement. Nobody asked me for these numbers, and I'm not counting tokens to
feel bad about every question I asked.

I wanted to measure myself during the challenge. AI is part of how I build now, so I wanted to see it
the same way I see any other tool on my desk: where did the time go, and was my process organized or
was I just prompting on autopilot? You can't improve what you don't look at.

So I built a small tool for it, `usage-ledger`, a Claude Code plugin that saves tokens and active
time per question, tagged by feature and phase. It also helped me keep my own workflow honest: if a
phase has a name, it has a plan behind it.

## How to read it

"Active time" is the time the agent was actually working on my questions, not the time I spent
thinking, reading or testing on the device. My own time was much more than this (see the README).

Every question gets a feature and a phase. A phase is a step of a plan:

- `plan`: the agent writes the plan in `docs/<feature>/plan/` and stops for my approval.
- `apply-N`: it applies step N of that plan.
- `audit`: `staged-audit` runs on what I staged, before I commit.
- `fix`: it fixes what the audit or my review found.
- `handoff`: gates green, the change is ready for me to stage.

Questions are split in two: "work" is the agent changing files, "questions" is me asking about what
it did. More than half are questions, because I review what the agent writes the same way I would
review a PR.

## Time by feature

From 2026-10-29 to 2026-11-12, 12 days with activity, only for this project.

| Feature      | Active time | Share |
|--------------|------------:|------:|
| ai_companion |      2h 37m | 18.9% |
| library      |      1h 35m | 11.5% |
| player       |         12m |  1.5% |
| discover     |          3m |  0.4% |
| unassigned   |      9h 22m | 67.7% |
| **Total**    | **13h 50m** |  100% |

## Honest notes

- Two thirds of the time is `unassigned`. I started tagging on Nov 6, so everything before that has
  no feature: the Task 1 bug fixes, `AGENTS.md` and the skills. Lesson learned: set up the
  measurement first, then work.
- Inside `ai_companion`, the biggest slices are not the code steps but the audits of the language
  and the UI (about 1h 4m together). That's where I pushed back the most.
- I used the Claude Pro plan and never reached its weekly limit during the challenge.

The raw data, per question and per model call, is in [`usage.json`](usage.json). With the plugin
installed, `/usage-ledger:usage-ledger report` shows it as a board.
