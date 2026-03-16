# System Design Mastery

**An interactive, gamified course for learning system design from the ground up.**

Learn system design by combining a battle-tested textbook with a playable browser game. Work through 20 structured lectures, test your understanding with quizzes and guided challenge missions, and reinforce concepts by building cloud infrastructure in a real-time strategy game.

This course is designed for developers who want to deeply understand how large-scale systems work — not just memorize answers for interviews.

---

## What You Get

- **20 lectures** across 4 themed modules, each with pre-reading, deep dives, and real-world examples
- **Standardized quizzes** (10 questions per lecture) to check your understanding
- **Guided challenge missions** — design problems with constraints, hints, and frameworks provided
- **4 Boss Battles** — full system design exercises benchmarked against reference solutions
- **Server Survival integration** — a 3D browser game where you build infrastructure and see concepts come alive
- **Company architecture readings** — how Netflix, Twitter, Google, and others solve real problems at scale

---

## Course Structure

```
MODULE 1: "The Request Journey"       Lectures 1-5     + Boss Battle
  Networking, DNS, CDNs, Load Balancers, Reverse Proxies, Estimation

MODULE 2: "The Data Fortress"         Lectures 6-10    + Boss Battle
  RDBMS, NoSQL, Sharding, Consistent Hashing, Caching, Async & Queues

MODULE 3: "The Distributed Mind"      Lectures 11-15   + Boss Battle
  CAP Theorem, Consistency, Availability, Resilience, Protocols, Security

MODULE 4: "The Architect's Trial"     Lectures 16-20   + Final Boss
  Interview Framework, Guided Walkthroughs, Peer Review, Timed Drills
```

---

## How It Works

Each lecture follows a consistent flow:

1. **Pre-Reading** — Read assigned sections from the System Design Primer
2. **Concept Briefing + Deep Dive** — Detailed explanations with trade-offs and real-world examples
3. **Discussion Prompts** — Open-ended questions to deepen your thinking
4. **Server Survival Tie-in** — Connect the theory to the game mechanics
5. **Quiz** — 3 fill-in-the-blank + 4 multiple choice + 3 short answer = /10
6. **Challenge Mission** — A guided design problem you solve yourself

The course is self-paced. At an intensive pace (10+ hours/week), expect about 3-4 weeks to complete everything.

---

## Prerequisites

- **git** — to clone this repo and the dependencies
- **A web browser** — to play Server Survival (no install needed, just open a file)
- **Python** (optional) — only needed if you want to run the Jupyter notebook exercises

That's it. No frameworks, no build tools, no accounts to create.

---

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/YOUR_USERNAME/system-design-game.git
cd system-design-game

# 2. Run the setup script (clones the textbook and game into deps/)
./setup.sh
# Or: make setup
# Or on Windows: powershell -ExecutionPolicy Bypass -File setup.ps1

# 3. Start learning
# Open course/README.md in your editor or on GitHub
```

---

## Manual Setup

If you prefer not to run scripts, you can clone the dependencies yourself:

```bash
# Clone this repo
git clone https://github.com/YOUR_USERNAME/system-design-game.git
cd system-design-game

# Create the deps directory
mkdir deps

# Clone the textbook
git clone https://github.com/donnemartin/system-design-primer.git deps/system-design-primer

# Clone the game
git clone https://github.com/pshenok/server-survival.git deps/server-survival
```

Then open `course/README.md` to begin.

---

## Built On

This course stands on the shoulders of two excellent open-source projects:

### System Design Primer
by [Donne Martin](https://github.com/donnemartin)

A comprehensive guide to system design with 280,000+ stars on GitHub. Covers everything from networking fundamentals to distributed systems, complete with reference solutions and flashcards. Used here as the course textbook — every lecture assigns pre-reading from it.

Repository: [github.com/donnemartin/system-design-primer](https://github.com/donnemartin/system-design-primer)
License: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) (Creative Commons Attribution)

### Server Survival
by [Kostyantyn Pshenychnyy](https://github.com/pshenok)

A Three.js browser game where you build cloud infrastructure — firewalls, load balancers, caches, queues, databases — to survive incoming traffic. The game's components map directly to system design concepts, making it a perfect hands-on learning tool.

Repository: [github.com/pshenok/server-survival](https://github.com/pshenok/server-survival)
License: [MIT](https://opensource.org/licenses/MIT)

See [ATTRIBUTION.md](ATTRIBUTION.md) for full license details.

---

## Start the Course

Ready to begin? Open **[course/README.md](course/README.md)** for the full module map and learning path.

---

## Contributing

Found a typo? Have a better example? Want to add a translation? See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Original course content is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See [LICENSE](LICENSE) for details.
