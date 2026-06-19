---
name: writing-plans-html
description: Use when you have a spec or requirements for a multi-step task and want the implementation plan as a live, browseable web page instead of a raw markdown file. Triggers when the user asks for a plan "as HTML", "as a web page", wants a "clickable"/"served"/"localhost" plan, or wants to "open it in the browser to review the changes". Produces the same rigorous task-by-task plan as writing-plans, then renders it to a styled HTML page and serves it on a local URL that gets attached to the response. Prefer this over writing-plans whenever the user signals they want to view/click the plan in a browser rather than read a file.
---

# Writing Plans (HTML)

## Overview

Write a comprehensive implementation plan — same rigor as a markdown plan — then render it as a styled, navigable HTML page and serve it on a local HTTP server so the user can click a URL and review the plan in their browser. The plan content rules are identical to ordinary plan-writing; only the **output medium** changes.

Write the plan assuming the engineer has zero context for the codebase and questionable taste. Document everything: which files to touch per task, the actual code, how to test, docs to check. Bite-sized tasks. DRY. YAGNI. TDD. Frequent commits. Assume a skilled developer who knows almost nothing about this toolset, problem domain, or good test design.

**Announce at start:** "I'm using the writing-plans-html skill to create the implementation plan and serve it as a web page."

**Context:** If working in an isolated worktree, it should have been created via `superpowers:using-git-worktrees` at execution time.

## How this works (output pipeline)

You write the plan as a markdown file (your normal workflow), then run the bundled script which converts it to a self-contained HTML page and serves it:

```bash
python3 <skill-dir>/scripts/serve_plan.py <plan>.md --title "<Feature> Plan"
```

The script inlines marked.js + CSS + your markdown into one HTML file (renders offline, no CDN), starts a detached `http.server` on a free port, and prints three lines:

```
HTML: /abs/path/to/plan.html
URL:  http://127.0.0.1:<port>/plan.html
PID:  <server-pid>
```

The rendered page gives the user: a sticky outline/TOC built from headings, syntax-friendly code blocks with copy buttons, and **interactive task checkboxes** (click to track progress; state persists in the browser via localStorage) with a progress bar. You do **not** hand-write any HTML — the script and template own all rendering.

## Save the markdown source to

`docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` (user preferences override). The `.html` lands next to it. The markdown is the source of truth you edit; re-run the script to regenerate the page.

---

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest splitting into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. One clear responsibility per file.
- You reason best about code you can hold in context at once, and edits are more reliable when files are focused. Prefer smaller, focused files.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. Don't unilaterally restructure — but if a file you're modifying has grown unwieldy, a split in the plan is reasonable.

This structure informs task decomposition. Each task should produce self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate. Fold setup, configuration, scaffolding, and documentation into the task whose deliverable needs them; split only where a reviewer could meaningfully reject one task while approving its neighbor. Each task ends with an independently testable deliverable.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" — step
- "Run it to make sure it fails" — step
- "Implement the minimal code to make the test pass" — step
- "Run the tests and make sure they pass" — step
- "Commit" — step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

---
```

The `- [ ]` checkboxes matter twice here: they drive execution tracking **and** they become the clickable progress checkboxes in the rendered HTML. Keep every actionable step as a `- [ ]` item.

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter
  and return types. A task's implementer sees only their own task; this
  block is how they learn neighboring tasks' names and types.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may read tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Remember
- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. Run this checklist yourself — not a subagent dispatch.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for the red flags above. Fix them.

**3. Type consistency:** Do types, method signatures, and property names in later tasks match what you defined earlier? `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

Fix issues inline. If a spec requirement has no task, add the task.

## Render & Serve

After the markdown plan is written, self-reviewed, and saved:

1. **Run the server script** from the plan's markdown:
   ```bash
   python3 <skill-dir>/scripts/serve_plan.py docs/superpowers/plans/<file>.md --title "<Feature> Plan"
   ```
2. **Capture the `URL:` line** the script prints.
3. **Attach the URL to your response** so the user can click it. Present it plainly, e.g.:

   > **Plan ready — review it here: http://127.0.0.1:<port>/<file>.html**
   >
   > Markdown source: `docs/superpowers/plans/<file>.md` · server PID `<pid>` (kill it with `kill <pid>` when done).

If you regenerate the plan after edits, re-run the script (it reuses a free port unless you pass `--port`) and give the user the fresh URL.

## Execution Handoff

After serving the plan, offer execution choice:

**"Plan complete and live at the URL above. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Fresh subagent per task + two-stage review

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:executing-plans
- Batch execution with checkpoints for review

As tasks complete, the user can tick the boxes on the served page to track progress visually (state persists in their browser).
