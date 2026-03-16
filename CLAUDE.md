# System Design Game — Project Context

## What This Project Is

**system-design-game** is an interactive, university-style course for learning system design. It's designed to be fun, gamified, and published as a public GitHub repo for junior developers.

It is built on top of two external dependencies (NOT included in this repo — cloned by a setup script):

1. **System Design Primer** by Donne Martin — the "textbook"
   - Repo: `github.com/donnemartin/system-design-primer`
   - License: CC BY 4.0 (Creative Commons Attribution)
   - Content: A 1839-line README covering 20+ system design topics, 8 system design solutions with Python code, 6 OOD solutions with Jupyter notebooks, Anki flashcard decks, EPUB generator
   - After setup, located at: `deps/system-design-primer/`

2. **Server Survival** by Kostyantyn Pshenychnyy (pshenok) — a 3D browser game
   - Repo: `github.com/pshenok/server-survival`
   - License: MIT
   - Content: Three.js game where you build cloud infrastructure (Firewall, Queue, Load Balancer, Compute, Cache, SQL DB, Storage) to handle traffic. Survival + Sandbox modes. No build step — just open `index.html`.
   - After setup, located at: `deps/server-survival/`
   - Maps 1:1 to system design concepts: Firewalls=Security, LBs=Traffic Distribution, Queues=Async/Back Pressure, Cache=Caching, SQL DB=Databases, Compute=App Layer

## Repository Structure (Target State)

```
system-design-game/
├── CLAUDE.md                    # This file
├── README.md                    # Hero README: what this is, setup, quick start (FOR PUBLIC — NOT the course README)
├── LICENSE                      # License for original course content (choose appropriate open source license)
├── ATTRIBUTION.md               # Full credit to Donne Martin (CC BY 4.0) + Kostyantyn Pshenychnyy (MIT)
├── CONTRIBUTING.md              # How others can improve lectures, add quizzes, translations
├── setup.sh                     # macOS/Linux setup (bash)
├── setup.ps1                    # Windows PowerShell setup
├── Makefile                     # Alternative: `make setup`
├── .gitignore                   # Must ignore deps/, *.pyc, .DS_Store, etc.
│
├── course/                      # ALL course content lives here
│   ├── README.md                # Course home page (module map, status tracking)
│   ├── project-plan.md          # Detailed curriculum plan (v2)
│   ├── progress.md              # Student's quiz scores, challenge log
│   ├── glossary.md              # Key terms accumulated per lecture
│   ├── module-1/                # "The Request Journey" — Lectures 1-5
│   ├── module-2/                # "The Data Fortress" — Lectures 6-10
│   ├── module-3/                # "The Distributed Mind" — Lectures 11-15
│   └── module-4/                # "The Architect's Trial" — Lectures 16-20
│
└── deps/                        # Created by setup script, GITIGNORED
    ├── system-design-primer/    # Cloned from donnemartin/system-design-primer
    └── server-survival/         # Cloned from pshenok/server-survival
```

**IMPORTANT**: The current files (README.md, project-plan.md, etc.) are in the repo root but need to be moved into a `course/` subdirectory. The repo root README.md should be the public-facing hero README, NOT the course README.

## Path Conventions

All lecture files should reference dependencies using these paths (relative to the lecture file):
- Primer README: `../../deps/system-design-primer/README.md`
- Primer solutions: `../../deps/system-design-primer/solutions/system_design/<name>/README.md`
- Primer OOD notebooks: `../../deps/system-design-primer/solutions/object_oriented_design/<name>/<name>.ipynb`
- Primer Anki decks: `../../deps/system-design-primer/resources/flash_cards/`
- Server Survival: `../../deps/server-survival/index.html`

From course/README.md:
- Primer: `../deps/system-design-primer/README.md`
- Server Survival: `../deps/server-survival/index.html`

## The Student (Course Author)

- Intermediate developer — understands database basics (SQL/NoSQL, indexing, ACID) and scaling at a high level (load balancers, caches)
- Gaps in networking foundations and distributed systems theory
- Goal: Deep understanding of system design — no deadline, genuine curiosity
- Pace: Intensive — 10+ hours/week, ~3-4 weeks to complete
- Learns fast when having fun — interactive and gamified approach
- Prefers guided challenges (constraints + hints + framework provided, student fills in design decisions)

## Course Design Decisions (Already Made)

These decisions were made through detailed discussion and should NOT be revisited:

1. **20 lectures across 4 modules** + 4 Boss Battles + 1 Final Boss
2. **Estimation/napkin math moved to Lecture 2** (not Lecture 15) — it's a meta-skill needed from the start
3. **CAP Theorem primer added to Lecture 6** (brief intro) — full deep dive remains in Lecture 11
4. **Consistent Hashing gets a dedicated deep dive in Lecture 6** — not just a mention
5. **Resilience Patterns + Observability added to Lecture 13** — circuit breaker, retry with backoff, bulkhead, saga, metrics/logs/traces
6. **API Design Patterns added to Lecture 14** — pagination, rate limiting, idempotency, versioning
7. **Module 4 uses varied formats**: L17 guided walkthrough, L18 peer review (find flaws in a given design), L19 time-boxed drill (30-min timer, solo design)
8. **Pre-reading assignments** from the primer for every lecture
9. **Module Recaps** at the start of every Boss Battle (10-point concept summary)
10. **Standardized quiz format**: 3 fill-in-blank + 4 MCQ + 3 short answer = /10 per lecture
11. **Server Survival has specific success criteria** per integration point (e.g., "survive 2 min, budget > $200")
12. **Company architecture readings** assigned per module (Netflix, Twitter, Facebook Memcached, Google)
13. **OOD notebook integration**: LRU Cache notebook paired with L9, Hash Map notebook paired with L6
14. **Glossary accumulates** key terms after each lecture
15. **Anki decks** reviewed after each module

## Setup Script Requirements

The setup scripts (bash + PowerShell + Makefile) must:
- Be idempotent (safe to run multiple times — skip already-cloned repos)
- NOT require sudo/admin privileges
- Only require git as a prerequisite
- Clone system-design-primer into deps/ via HTTPS (not SSH, for wider compatibility)
- Clone server-survival into deps/ via HTTPS
- Print clear success message with next steps
- Fail gracefully with helpful error messages

HTTPS clone URLs:
- `https://github.com/donnemartin/system-design-primer.git`
- `https://github.com/pshenok/server-survival.git`

## Target Audience for Public Repo

Junior developers who want to learn system design. This means:
- README must be beginner-friendly, no jargon upfront
- Setup must be dead simple (one command + one script)
- Manual fallback instructions for those who don't trust scripts
- Prerequisites: just git + a web browser
- Python is optional (only for Jupyter notebooks)

## What Needs to Be Built

### Phase 1: Repo Infrastructure (do this FIRST)
- [ ] Reorganize: move current root files into `course/` subdirectory
- [ ] `.gitignore` — deps/, *.pyc, .DS_Store, node_modules, etc.
- [ ] `setup.sh` — bash setup for macOS/Linux
- [ ] `setup.ps1` — PowerShell setup for Windows
- [ ] `Makefile` — `make setup` alternative
- [ ] Root `README.md` — hero README for the public repo (what, why, setup, quick start)
- [ ] `LICENSE` — for original course content
- [ ] `ATTRIBUTION.md` — credits to both upstream authors with their licenses
- [ ] `CONTRIBUTING.md` — how to contribute lectures, quizzes, translations
- [ ] Update all internal paths in course files to use `deps/` structure

### Phase 2: Course Content (do this AFTER Phase 1)
Build one module at a time. Each lecture file follows this structure:
```
Pre-Reading → Concept Briefing → Deep Dive → Discussion Prompts →
Server Survival Tie-in → Quiz (3 FIB + 4 MCQ + 3 SA) → Challenge Mission
```

- [ ] Module 1: Lectures 1-5 + Boss Battle 1
- [ ] Module 2: Lectures 6-10 + Boss Battle 2
- [ ] Module 3: Lectures 11-15 + Boss Battle 3
- [ ] Module 4: Lectures 16-20 + Final Boss
- [ ] Update glossary.md after each lecture

## Quality Standards

- Lectures should be detailed and educational — this is a deep-understanding course, not a cheat sheet
- Every concept needs real-world examples and honest trade-off discussion
- Quiz questions must be specific and reference concrete scenarios (not generic "what is X?")
- Challenge Missions are guided: provide constraints, hints, a framework/template — student fills in decisions
- Boss Battles reference the primer's solutions in `deps/system-design-primer/solutions/system_design/`
- Discussion prompts should be Socratic-style (provoke thinking, not just recall)
- Include estimation exercises in every Boss Battle and most Challenge Missions
