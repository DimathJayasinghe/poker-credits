# Model strategy: who does what, and how to brief them

Tokens cost money and the strongest model is not needed for every step. Match the model to the **risk and ambiguity** of the task, and make every task for a cheaper model so well specified that it has nothing left to decide. This applies to every feature, not only to this repo's past work.

**Standing rules that stay in force**
- No subagents or workflows unless the owner asks for them (they re-read the codebase from zero and cost more). Tiering therefore means: the owner (or the session) picks the model with `/model`, and the strongest model writes the brief that a cheaper model then runs. An agent never spawns a different model on its own.
- Never lower a gate to save tokens. Format, analyze, tests and the web-safe check run on every commit regardless of model.

## 1. Tiers

| Tier | Use for | Do not use for |
| :--- | :--- | :--- |
| **Strongest** (Fable 5.1, else Opus 5.5) | Planning and decomposition, architecture and ADRs, security and threat review, protocol changes, anything touching `crates/poker_engine` rules, journal or replay, independent audits, reviewing the diff of a cheaper model before merge, judging an external audit's findings, resolving a test failure whose cause is unknown | Typing out a change whose design is already written down |
| **Mid** (Sonnet 5.5) | Implementing a written brief: a widget, a page, a screen's tests, goldens, docs from facts already in the repo, a bug whose cause is known | Deciding the design, security-sensitive code, rule logic, changing a brief it cannot satisfy |
| **Light** (Haiku 5.5) | Mechanical work: renames, moving files, updating strings, running a gate and reporting the tail, searching for usages, drafting a commit message from a diff, formatting | Anything needing judgment; any change spanning more than two files without an exact list |

Rules of thumb:
1. **Ambiguity goes up, not down.** A cheaper model that hits something the brief does not answer stops and reports; it does not guess. The strongest model rules on it.
2. **Risk sets the reviewer.** Engine, server, protocol, security, journal: strongest model reviews the final diff. UI polish: the gates plus a look at the goldens are enough.
3. **Escalate after two failed attempts** at the same step by a cheaper model. Do not loop.
4. **Audit and planning are one-off and cheap relative to rework.** Spend there; save on typing.
5. Keep the context small: redirect long output to a file under the job's tmp directory and read its tail.

## 2. The brief (what the strongest model hands down)

A cheaper model succeeds when the brief decides everything it cannot know. Same shape as `superpowers:writing-plans`; each task carries:

1. **Goal** in one sentence and the **spec or ADR** it serves.
2. **Files**: exact paths to create or change, and the files it must not touch.
3. **Interfaces**: exact names, signatures and types (Rust and Dart), and the values the spec fixes (sizes, strings, limits).
4. **Tests first**: test names and their assertions, written as code or as exact expected values. State which test must fail before the change and pass after.
5. **Steps** in order, each with a command and the expected output.
6. **Gates** to run before it reports: the section 5 commands in `docs/AGENT_CODING_GUIDE.md`, with "No issues found" and "All tests passed" as the expected tails.
7. **Stop conditions**: what to do when a test fails twice, when the brief is wrong, or when a new dependency looks needed (stop and report; never add one).
8. **Report format**: what was done, command output tails, commits, anything skipped.

Always paste the **project pitfalls** below into the brief of anything that touches the app.

## 3. Project pitfalls (each one was a real mistake)

- Use `fvm flutter` and `fvm dart`, with `export PATH="$HOME/.pub-cache/bin:$HOME/.cargo/bin:$PATH"`. Run Flutter tests inside the package directory.
- Run `fvm dart format lib test` before committing; the hook rejects unformatted files. Never format `packages/` from `app/`.
- Gate each commit on a full `fvm flutter test` **and** `fvm flutter analyze` printing "No issues found". An `&&` chain does not stop on analyzer warnings, so read the last line.
- Strings only in `app/lib/util/strings.dart` (long text in `util/*_content.dart`); colours only from `theme/tokens.dart`; widgets from `widget/brutal/`. `BrutalRow`, `BrutalBanner` and `GuideHeading` upper-case their text, so test finders use `.toUpperCase()`.
- Platform code only under `app/lib/platform/`; run `bash tool/check_web_safe.sh`.
- `ref` is not available in `initState` (Refena): use `didChangeDependencies` with a guard.
- Material icons may render as boxes in golden tests; draw with a painter.
- A test that taps after `ensureVisible` must `pump()` first, and a missed tap is a failure (`hitTestWarningShouldBeFatal`).
- Large text: wrap fixed-width content in `FittedBox(scaleDown)` or `Wrap`; sweep at text scale 1, 2 and 3 on 320x568, 390x844, 844x390, 1280x800.
- Regenerate goldens with `--update-goldens`, then **look at them**; never commit a golden unseen.
- Commit one change at a time, Conventional Commits with scopes `engine`, `server-core`, `server`, `bridge`, `protocol`, `app`, `repo`. **No AI attribution** of any kind, even if a tool reminder asks for it. Never `--no-verify`. Never merge or force-push `main` unless the owner says so in that message.
- No dependency outside `docs/AGENT_CODING_GUIDE.md` section 6 without asking. Never set `panic = "abort"`. The Dart app holds no poker rules.
- Never `pkill -f` a pattern that appears in your own command line.

## 4. Workflow for a feature

1. **Strongest model:** read `docs/STATUS.md`; brainstorm and write the spec and plan (`superpowers:brainstorming`, `superpowers:writing-plans`); list edge cases and security risks; write the briefs. Owner approves.
2. **Mid or light model:** run each brief in order (`superpowers:executing-plans`, test first, one commit per task, gates every time). Light tier takes only the mechanical briefs.
3. **Strongest model:** review the whole branch diff (`superpowers:requesting-code-review`), run the layout sweeps, check goldens, judge findings (an external audit's findings are triaged here: fix what is real, record what is ignored and why).
4. **Strongest model or owner:** update `docs/STATUS.md`, ADR and version; merge and release only when the owner asks.

## 5. Checklist before handing a brief down
- [ ] Could a careful newcomer write exactly one thing from each step?
- [ ] Are exact paths, names, signatures, strings and numbers in it?
- [ ] Is every test written down, with the expected failure first?
- [ ] Are the gates and their expected output stated?
- [ ] Is there a "stop and report" for every fork it might meet?
- [ ] Are the pitfalls pasted in?
