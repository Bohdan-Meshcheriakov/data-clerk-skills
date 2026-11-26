# Human Touch task catalog

Live schemas and prices are at `GET /api/v1/kinds` (MCP: `task_kinds`). This file maps real needs to kinds.

## Live kinds

### approve_action

A human approves, edits or denies an action before you take it.

- `spec`: `action` (required, one line), `details`, `diff`, `risk` (low|medium|high), `rule` (all|majority)
- `result.answer`: `{decision: approve|deny|edit, edited?, reasons[]}`
- `rule: all` (the default) approves only if everyone asked approves; any deny wins.
- Reviewers are adults only.

### choose

Humans pick one label, or several when `multi` is set.

- `spec`: `question`, `options` (2–20), `content`, `multi`
- `result.answer`:
  - single: `{choice, index, votes[]}`
  - multi: `{choices[], votes[]}`

### rate

Humans score content on criteria.

- `spec`: `question`, `content`, `criteria` (`[{id, label, min, max}]`, default overall 1–5)
- `result.answer`: `{scores: {id: median}, comments[]}`

### compare

Humans pick A or B. Sides are randomized per reviewer.

- `spec`: `question`, `a`, `b`, `no_tie`
- `result.answer`: `{winner: a|b|tie, votes, reasons[]}`

### ask

Humans answer a free question, optionally typed.

- `spec`: `question`, `content`, `answer_schema` (`{properties: {name: {type: string|number|integer|boolean, enum?, description?, minimum?, maximum?}}, required[]}`, max 8 fields), `max_chars`
- `result.answer` holds one value per field:
  - majority for enums, booleans and short strings
  - median for numbers

### verify_web

A human opens a public URL and answers.

- `spec`: `url`, `question`, `checklist[]`, `attest_safe: true` (required)
- `result.answer`: `{verdict: yes|no|unsure|cant_access, answer, quotes[], checks[]}`
- Use `skill: country:xx` to get reviewers in a specific country.
- Reviewers are adults only.
- **URL rules:**
  - https only, on the default port
  - a public domain name: no IP addresses, localhost or internal hosts
  - no credentials in the URL, no link shorteners, no file downloads
- **`attest_safe: true` is your statement** that the URL is a normal, safe page: no malware, phishing, login or payment traps, tracking aimed at reviewers, or illegal content. The account owner is responsible for it.
- Every URL is checked against Google Web Risk at quote time. A malicious URL **suspends the account immediately**: API keys are revoked and open tasks stop. Only send URLs you have verified yourself.

### span_tag

Humans select parts of a text and label them.

- `spec`: `content`, `labels[]` (1–12), optional `question`
- `result.answer`: `{spans: [{start, end, label, text, votes}]}`, offsets in Unicode code points; only spans marked by a majority
- Use for hallucination spotting (labels like `unsupported`, `wrong`), entities, PII or policy violations.

### fact_check

Humans research each claim on the web.

- `spec`: `claims[]` (1–10, one self-contained claim each), optional `sources[]` as hints
- `result.answer`: `{claims: [{claim, verdict: true|false|misleading|unverifiable, votes, sources[], notes[]}]}`
- Every verdict except `unverifiable` comes with a source URL. Price is per claim.

### rank

Humans order 3–10 options, best first. Options are shuffled for each reviewer.

- `spec`: `question`, `items[]`
- `result.answer`: `{ranking: [{index, item, score}]}` (Borda count)

### doc_fields

Humans compare the values your agent extracted with the document image and fix them.

- Needs at least one image of the document in `images[]`.
- `spec`: `fields: [{name, value}]` (1–30), optional `question`
- `result.answer`: `{fields: [{name, status: ok|fixed|missing, value}], wrong: [names]}`

### annotate

Humans draw boxes or points on your images and label them.

- Needs images.
- `spec`: `question`, `labels[]`, `shape: box|point` (default box), `max_marks` (default 20)
- `result.answer`: `{marks: [{img, label, x, y, w, h, votes}]}`. Coordinates are 0–1 relative to the image; `img` is the index in `images[]`. Only marks made by a majority are kept.

### ui_review

Humans tap visual problems on UI screenshots.

- Needs images.
- `spec`: all optional: `question`, `checks[]` (issue types). Default checks: cut-off or overlapping text, untranslated text, broken image, broken layout, hard to read, typo, broken-looking button.
- `result.answer`: `{ok, issues: [{img, label, x, y, votes, notes}]}`
- Use `skill: lang:xx` for localized screens.

### media_review

Humans listen to or watch your file and answer.

- Needs exactly one audio or video file in `images[]`: MP3, M4A, WAV, OGG, MP4 or WebM, up to 25 MB, uploaded like an image.
- Media is stored as sent: strip metadata (GPS, device) yourself.
- `spec`: `question`, `duration_seconds`, and any of:
  - `options[]`: reviewers pick one
  - `transcript`: reviewers correct it
  - `mark_labels[]`: reviewers mark moments with timestamps
- `result.answer`: `{choice, choice_index, transcript, marks: [{t, label, votes}], comments}`
- The transcript returned is the one closest to all reviewers' versions.
- Price is per started minute, doubled when there is a transcript to correct.

### code_review

A developer reviews a unified diff.

- `spec`: `diff` (max 60 000 characters; remove secrets first), optional `title`, `question`, `language`. Use `skill: code:<lang>`.
- `result.answer`: `{verdict: approve|request_changes|reject, votes, summaries, comments: [{line, code, severity: blocker|issue|nit, texts, votes}]}`
- `line` is the 0-based line index in your diff.

### usability

Real people try a task on your public site, time it, rate how easy it was and describe where they got stuck.

- `spec`: `url`, `task`, `attest_safe: true` (same URL rules and Web Risk screening as `verify_web`), optional `questions[]` (up to 5), `max_minutes` (default 10)
- `result.answer`: `{completed: {yes, partly, no}, completion_rate, median_seconds, median_ease (1–5), problems, steps, answers, proof}`
- `proof` holds the reviewers' screenshot ids. Fetch them with `GET /api/v1/images/{id}`.
- Tell reviewers to stop before payment. They use made-up test data.

### native_check

Native speakers fix a translated or generated text.

- Item fields: `target_lang`, `content` (text, HTML or a JSON object of strings), plus optional `source`, `source_lang`, `format`, `doubt`, `doubt_note`
- Returns `final` / `final_json` and per-sentence `changes`. Apply them in one pass and show your human the final text once (see SKILL.md).

### proofread

Same as native_check, but for original text with no source. `target_lang` defaults to `en`.

## What people use it for → which kind

**Text and language**
- Native check of translations, UI strings, app store listings → `native_check`
- Proofread blog posts, release notes, emails → `proofread`
- Tone or brand-voice fit → `rate` (criteria: tone, on-brand)
- "Does this sound AI-written?" → `rate` or `choose`
- Clarity and readability → `rate`
- Summary faithful to the source? → `choose` (faithful / minor issues / wrong), with notes
- Mark hallucinated or unsupported sentences → `span_tag`
- Check facts and statistics before publishing → `fact_check`
- Cultural sensitivity in market X → `ask` with `skill: lang:xx`
- Brand or product name check in language X → `ask` with `skill: lang:xx`
- SEO title or meta pick → `compare` or `choose`

**Approvals (human in the loop)**
- Send email / message / DM → `approve_action`
- Payments, refunds, purchases → `approve_action` (risk high)
- Delete or migrate data, run a destructive shell command → `approve_action` with `diff`
- Publish a post, merge a PR, deploy → `approve_action`
- Contract clause or policy wording OK? → `approve_action` with `skill: domain:legal`

**Preference and quality**
- Which LLM output is better (RLHF-style) → `compare`
- Rank N options → `rank`
- Rubric scoring for evals → `rate`
- Headline, subject line, CTA, logo or design preference → `compare` (attach images)
- TTS or voice naturalness, pronunciation by natives → `media_review` with `options` and `skill: lang:xx`

**Labels and classification**
- Intent, sentiment, topic → `choose`
- Spam, fraud, abuse triage → `choose`
- Search relevance (query ↔ result) → `choose` or `rate`
- Is the LLM answer correct? Did it follow the instructions? → `choose`
- Duplicate or same-entity check (two records) → `choose` (same / different / unsure)

**Data**
- Do extracted fields match the document (invoice, receipt, form)? → `doc_fields`
- Is this row valid? Fill a missing value → `ask`

**Visual**
- Generated image QA (hands, text, prompt match) → `rate` or `choose` with images; `annotate` to point at the defects
- Bounding boxes or points for detection data → `annotate`
- UI screenshot review (overlap, truncation, untranslated text) → `ui_review`
- Alt-text quality → `rate`

**Audio and video**
- Fix a speech-to-text transcript → `media_review` with `transcript`
- Mark glitches, desync or wrong content in a video → `media_review` with `mark_labels`

**Web and real world**
- Is this price, opening hours or stock info still right? → `verify_web`
- Does the page work in country X? → `verify_web` with `skill: country:xx`
- Try the signup or checkout flow (no payment) → `usability` (time, ease, where people get stuck, screenshots)
- Find the official website of X → `ask`

**Code**
- "Is this command safe to run?" → `approve_action` with `skill: code:<lang>`
- Review an agent-written diff with line comments → `code_review` with `skill: code:<lang>`
- Does the SQL result look plausible? → `ask` with `skill: code:sql`

**Evals and data creation**
- Write a gold answer → `ask`
- Prompt regression check → `compare` (old vs new)

**Opinion**
- Quick poll of people (by country or language) → `ask` (repeat items for a bigger sample)

