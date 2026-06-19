---
name: spoken-plans
description: Use when you have a spec or requirements for a multi-step task and want the implementation plan ALSO read aloud when it's done. Same rigorous task-by-task plan as writing-plans, then auto-generates a spoken summary of the key changes and plays it through macOS `say`. Triggers when the user asks for a plan they can "listen to", wants the plan "read aloud"/"spoken"/"narrated", says "tell me the plan", wants a voice/audio summary of what will be built, or just wants the normal planning flow with an audible wrap-up. Prefer this over writing-plans whenever the user signals they want to hear the plan, not only read it.
---

# Spoken Plans

## Overview

This is `writing-plans` plus a mandatory spoken wrap-up. You produce the exact same comprehensive, task-by-task implementation plan, then — without being asked again — generate a short narrated summary of the key changes and play it through macOS `say` so the user can hear what's coming while they skim the file.

The point: planning output is long and easy to skim past. A 20-30 second spoken summary forces the important shape of the work — what's being built, the main pieces, how many tasks — into the user's ears, which catches "wait, that's not what I meant" moments before any code is written.

**Announce at start:** "I'm using the spoken-plans skill to create the plan and read its summary aloud."

## Configuration

```
VOICE=system          # OS default system voice (portable — works on any Mac). Or a name: Ava, Zoe, Daniel, Samantha. Or `personal` for the user's Personal Voice.
RATE=                  # 0.0–1.0 for the helper (default ~0.5). Empty = default.
BACKGROUND=true        # play speech detached so it doesn't block the turn
```

`VOICE=system` (or empty) pins nothing — the helper speaks with whatever voice the user set in **System Settings → Accessibility → Read & Speak → System voice**. That's the right default for a shared/published skill: no assumption about which voices are installed. Users who want a specific voice set `VOICE=<name>`; names are prefix-matched and prefer the Premium tier (so `Ava` → "Ava (Premium)"). `VOICE=personal` selects the first Personal Voice if the user created and authorized one.

**Why a helper, not `say`:** the macOS `say` CLI silently falls back to a default voice for any name it can't resolve (proven: even a bogus name exits 0), and it cannot reach Personal Voice or Siri voices at all. `scripts/speak.swift` uses `AVSpeechSynthesizer`, which honors the system default voice, resolves named/Premium voices reliably, and can speak Personal Voice after a one-time authorization. A compiled `scripts/speak` binary sits alongside it for speed.

## Step 1: Write the plan

Follow the **`superpowers:writing-plans` skill in full** — invoke it and obey everything it says: scope check, file structure, task right-sizing, bite-sized steps, the required plan header, task structure, no placeholders, self-review. Save to its default location (`docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`) unless the user set another.

Do not shortcut the plan to get to the speaking part. The spoken summary is worthless if the plan under it is thin.

## Step 2: Write the spoken summary (mandatory — do not skip)

After the plan is saved and self-reviewed, write a plain-prose summary built for the ear, not the eye. Save it next to the plan as `…-<feature-name>.summary.txt`.

What makes a good spoken summary:
- **3 to 6 sentences.** This is a trailer, not the movie. If it runs past ~45 seconds spoken, it's too long.
- **Lead with the goal in one sentence** — what the user actually gets when this is done.
- **Name the 2-4 key changes**, the ones that carry the design. Skip the scaffolding, config, and test-wiring tasks — those matter in the plan, not in the trailer.
- **End with the shape of the work**: roughly how many tasks, and the first concrete action (e.g. "Eight tasks; we start by writing the failing test for the auth guard.").

Write for the voice, because `say` reads literally:
- No markdown, no bullets, no code blocks, no headings — just sentences.
- Expand or drop things that sound like noise out loud: file paths, `snake_case`/`camelCase` identifiers, symbols, version strings. Say "the auth middleware" not "src/auth/mw.ts". If a literal name must be spoken, render it as words.
- Spell out numbers and units the way you'd say them ("about three hundred lines", "two endpoints").
- Short declarative sentences. Commas and periods are your pacing; the voice pauses on them.

**Example (good):**

```
Here's the plan. We're adding rate limiting to the public API so one client can't exhaust the database. Three key pieces: a token-bucket limiter held in Redis, a middleware that checks it before each request, and a clear error response when a client is over the limit. Existing routes don't change, they just gain a guard in front. Six tasks total. We start by writing the failing test for the limiter's refill logic.
```

**Example (bad — reads terribly aloud):**

```
Implements RateLimiter in src/middleware/rate_limit.ts (≈320 LOC), wiring INCR/EXPIRE via ioredis@5, + 6 TDD tasks. See plan.md §2.
```

## Step 3: Speak it

Play the summary through the bundled helper, piping the file in so there's no shell-escaping pain with a multi-sentence string. The helper lives next to this skill; resolve `SKILL_DIR` to this skill's own directory.

```bash
SPEAK="$SKILL_DIR/scripts/speak"                       # native binary (fast)
[ -x "$SPEAK" ] || SPEAK="swift $SKILL_DIR/scripts/speak.swift"   # fallback: run source
cat "docs/superpowers/plans/<...>.summary.txt" | $SPEAK --voice "$VOICE" ${RATE:+--rate $RATE} &
```

- Pipe the file in (`cat … | $SPEAK`), not an inline string — long summaries with apostrophes and commas break inline.
- `--voice personal` reaches the Personal Voice. Any other name (Samantha, Tara, Grandpa) matches a system voice; unknown names fall back to en-US default.
- Background it (`&`) when `BACKGROUND=true` so the turn isn't blocked while it talks. In your text reply, give the re-listen command and the summary path so the user can replay or swap voice.
- **If the binary is stale or missing** (first run on a new machine), build it once: `swiftc -O "$SKILL_DIR/scripts/speak.swift" -o "$SKILL_DIR/scripts/speak"`. The `swift <source>` fallback also works with no build step, just slower (~1–2s compile each run).
- **Non-macOS / no Swift:** skip speech silently — still write the `.summary.txt` and tell the user it's there to read.

## Step 4: Execution handoff

Hand off exactly as `writing-plans` does — offer Subagent-Driven (recommended) vs Inline Execution and route into the chosen sub-skill. The spoken summary is a wrap-up on the *plan*, not a replacement for the handoff.
