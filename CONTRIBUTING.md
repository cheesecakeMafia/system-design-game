# Contributing

Thanks for your interest in improving this course. Contributions of all kinds are welcome — from fixing a typo to adding a new lecture.

---

## Ways to Contribute

### Fix Errors
Spotted a factual mistake, broken link, or typo? Open a pull request with the fix. Small corrections are always appreciated.

### Improve Explanations
If a concept could be explained more clearly, or a real-world example would help, feel free to propose changes. The goal is deep understanding, not brevity — so adding helpful context is encouraged.

### Add Quiz Questions
Each lecture has a standardized quiz format (3 fill-in-the-blank + 4 multiple choice + 3 short answer). If you have a good question that tests a specific concept with a concrete scenario, suggest it.

### Add Challenge Missions
Challenge missions should be guided — provide constraints, hints, and a framework. The student fills in the design decisions. Avoid open-ended "design X" prompts without scaffolding.

### Add Translations
Translating lectures into other languages makes the course accessible to more developers. Create a `course/translations/<language-code>/` directory and translate lecture files, preserving the original file names.

### Report Issues
If something is confusing, incorrect, or missing, [open an issue](../../issues). Include which lecture or section you're referring to and what you expected to find.

---

## How to Submit Changes

1. Fork this repository
2. Create a branch for your change (`git checkout -b fix/lecture-3-typo`)
3. Make your changes
4. Commit with a clear message describing what you changed and why
5. Open a pull request against `main`

---

## Guidelines

- Keep the tone welcoming and educational — this course is aimed at junior developers
- Every concept should include trade-offs, not just "use X"
- Quiz questions must test specific scenarios, not generic recall ("What is caching?" is too vague)
- Do not add content from the System Design Primer or Server Survival directly into this repo — they are external dependencies referenced via `deps/`
- All contributions must be compatible with the **CC BY 4.0** license

---

## Questions?

Open an issue and we'll figure it out together.
