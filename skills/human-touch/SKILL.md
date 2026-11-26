---
name: human-touch
description: Ask real humans to check what you can't be sure of, through the Human Touch MCP server or API. Use before irreversible or outward-facing actions (sending emails or messages, payments, deleting data, publishing, deploying), when a label, rating or choice is uncertain, when you need people's opinion or taste (A/B, naming, tone), when a public web page or signup flow must be tried by a person (optionally in a given country), to fact-check claims, review code diffs, check extracted document fields, annotate images, review UI screenshots or audio/video, and when text in a language you can't verify must be checked by native speakers.
---

# Human Touch

Human Touch is a pool of paid human reviewers that you can call like a tool. You send tasks, humans answer within minutes to hours, and you get structured results with an agreement score.

- MCP server: `https://humantouch.data-clerk.com/mcp`. Tools: `task_kinds`, `ask_human`, `quote_task`, `place_order`, `check_order`, `collect_order`, `ack_order`, `upload_image`, `request_approval`, `balance`.
- REST API: `https://humantouch.data-clerk.com/api/v1`, with `Authorization: Bearer ht_…`.

## Getting access

Set yourself up. Your human only approves once in the browser: they sign in, set a spending cap and click Allow. Pick the first that applies. Never ask your human to paste a key into the chat if another option works.

1. **MCP tools already available** (`ask_human` etc.): just use them. If a call says authorization is required, your MCP client starts OAuth and your human approves in the browser.
2. **Key file exists**: `~/.config/humantouch/api_key`. Send it as `Authorization: Bearer $(cat ~/.config/humantouch/api_key)`.
3. **You can make HTTP requests** (any coding agent): use device login.
   1. `POST /api/v1/auth/device` with `{"client_name": "<your name>"}`.
   2. Show your human `verification_uri_complete` and `user_code`: they open it, log in, set a cap and approve.
   3. Poll `POST /api/v1/auth/device/token` with `{"device_code": "…"}` every `interval` seconds. HTTP 202 means keep waiting.
   4. Save the returned `api_key` (it is shown once) to `~/.config/humantouch/api_key` with mode 600, or to your secrets store.
4. **You are Claude Code** and want the MCP tools for later sessions too: run `claude mcp add --transport http --scope user humantouch https://humantouch.data-clerk.com/mcp` (no key needed, OAuth runs on first use). The tools appear after Claude Code restarts, so tell your human, and use device login (3) until then.
5. **You are a chat app without shell or HTTP** (Claude.ai, ChatGPT, …): ask your human to add the connector `https://humantouch.data-clerk.com/mcp` in the app's connector settings (Claude.ai: Settings → Connectors → Add custom connector). OAuth runs on first use.

Full API reference: `https://humantouch.data-clerk.com/llms-full.txt`.

## When to call a human

Call a human when a wrong answer would cost more than about $1 and a minute of waiting:

1. **Before acts you can't undo, or that others will see**: send, pay, delete, publish, deploy, merge. Use `approve_action`.
2. **When your confidence is low**: you'd guess on a label, or two options look equally good. Use `choose` or `compare`.
3. **When the answer is a matter of taste or culture**: is a name embarrassing in Polish, which headline is better, does this sound robotic. Use `ask`, `compare` or `rate`.
4. **When it needs the real world**: does the page show this price in Germany (`verify_web` with `skill: country:xx`), can a new user actually sign up (`usability`).
5. **When the text is in a language you can't verify**, or will be published. Use `native_check` (translations) or `proofread`.
6. **For evals and data**: grade your outputs, build gold answers and labels. Use `rate`, `rank`, `span_tag`, `annotate`, or `ask`.
7. **Before you ship what you generated**: facts (`fact_check`), code (`code_review`), screens (`ui_review`), extracted data (`doc_fields`), audio (`media_review`).

Do **not** call a human for things you can verify yourself (run the tests, read the docs, fetch the page).

## How to call

1. If you haven't yet in this session, call `task_kinds` once to get the schemas and prices.
2. Batch all your tasks into **one** `ask_human` call: `items[]`, each with `kind`, `spec`, `ref`, and optionally `skill`.
3. Budget:
   - If your human gave you a budget, pass `max_coins` (1 coin = $0.01). The order is placed at once if the price fits.
   - Otherwise show `quote.summary_for_human`, wait for their OK, then call `place_order`.
   - If the quote says `needs_limit_approval` (or `place_order` fails with "spending cap"), the price is above what your connection may spend. Call `request_approval` with the `quote_id`, show your human `message_for_human` with `approval_url`, and call `request_approval` again with `wait_seconds: 50` until it's `approved`. Then call `place_order`. Their limits stay the same. Never split an order to get under the limit.
4. Waiting:
   - Follow `wait_plan`. Don't block the conversation: tell your human the ETA, keep working on other things, then call `check_order` with `wait_seconds: 50` until `ready`.
   - If you can't keep running, save `order_id` in memory or notes and check later.
5. Call `collect_order`, then `ack_order`.

## Reading results

`items[].result` = `{answer, agreement, notes}`. `agreement` (0–1) is how much the people agreed.

| agreement | What to do |
|---|---|
| ≥ 0.8 | Act on `answer`. |
| 0.5–0.8 | Act carefully: mention the split to your human, read `notes`. |
| < 0.5 | Don't act. Escalate to your human, or re-ask with a clearer `spec`. |

- `approve_action`: act only if `answer.decision == "approve"`. If it's `"edit"`, use `answer.edited` instead of your version. If it's `"deny"`, stop and tell your human the `reasons`.
- Text kinds return `final` (or `final_json`) plus per-sentence `changes`. Apply them in one pass:
  - Replace your text by `ref` with the final version.
  - You may fix leftover typos and broken formatting (markup, spacing, quotes, placeholders). When you do, carry the checkers' style (word choice, tone, punctuation) through the whole text, not just the lines they touched, so it reads as one voice.
  - Don't nitpick or second-guess their wording, and don't re-ask about small choices. Native speakers made those calls.
  - Show your human the final updated text once, not a list of diffs or questions about each change. Mention only real problems, like a lost placeholder.

## Writing good tasks

- Make each `spec` self-contained: the reviewer sees only the item (plus `context` and screenshots), never your conversation.
- Use `context` for the purpose, audience and constraints.
- Ask one question per item, with concrete options. Don't ask "is this good?"; ask "would you open this email: yes / no".
- For UI, designs, pages or documents, attach screenshots with `upload_image`, then pass `images: [{id, caption}]`. `doc_fields`, `annotate` and `ui_review` require images; `media_review` requires one audio or video file (same upload). See Screenshots below.
- Use `skill` to target people:
  - `lang:de` for native German speakers
  - `country:us` for people living in the US
  - `code:go`, `domain:legal`, `device:ios` for other expertise
  - Narrower skills mean slower answers.
- Use `sla_seconds < 900` only when truly urgent. It doubles the price.

## Screenshots

Take them yourself, using the first tool you have:

1. Playwright MCP: `browser_resize` to 1280×800, then `browser_take_screenshot` with a `filename` (an element, or `fullPage`).
2. Playwright CLI: `npx -y playwright screenshot --viewport-size="1280,800" <url> shot.png` (add `--full-page`, or `--device="iPhone 13"`).
3. Headless Chrome: `google-chrome --headless=new --window-size=1280,800 --screenshot=shot.png <url>`.
4. Other tools (shot-scraper, simulators, OS screenshot tools), or ask your human.

Keep them cheap:
- Use width 1280 at scale 1; images are stored at most 1600 px wide.
- Capture only the part that matters.
- Upload with `upload_image` and its `curl` command, never as base64 in your context.
- Put shared screenshots in the top-level `images`.

Screenshots are not redacted: use test data and hide personal details. Details: `references/screenshots.md`.

## Privacy (important)

- Reviewers never see who you or your human are.
- Before any human sees your content, these are replaced with placeholders like `⟦EMAIL_1⟧`, and restored in your delivery:
  - emails, phone numbers, card numbers, IBANs, IP addresses
  - tokens and API keys, secrets in URLs, wallet addresses
- **Names of private people and street addresses are NOT reliably detected.** Replace them yourself with `⟦NAME_1⟧`, `⟦ADDRESS_1⟧` before sending, and map them back afterwards.
- Send the minimum. Never include passwords, health or financial records, or customer lists unless the task truly needs them.
- `pii: "share"` (unredacted) works only if the account owner opted in in the wallet. Never ask for it unless your human says so.
- Model training is a separate opt-in in the wallet (off by default). Only redacted orders placed while it's on are kept, without account identity.

## Not allowed

Don't send these. They are rejected and can get the key suspended:

- CAPTCHA solving
- account, phone or KYC verification for you
- fake reviews, likes or votes
- collecting personal data about people
- harassment, illegal or sexual content involving minors
- links to malware, phishing, downloads, or pages that ask reviewers to log in, pay or enter data

For `verify_web` you must set `attest_safe: true`, which confirms you checked the URL is a safe public page. URLs are screened with Google Web Risk; a malicious URL **suspends the account immediately**. Reviewers can also report harmful pages, and confirmed reports ban the requester.

## Kinds at a glance

| kind | what humans do |
|---|---|
| `approve_action` | approve / edit / deny something you're about to do |
| `choose` | pick one or more labels/options |
| `rate` | score on rubric criteria (1–5) |
| `compare` | pick the better of A vs B (randomized sides) |
| `ask` | answer a free question, optionally into a typed `answer_schema` |
| `verify_web` | open a public URL, answer, quote what they saw |
| `span_tag` | mark and label spans in a text (hallucinations, entities) |
| `fact_check` | research claims, verdict + source URL |
| `rank` | order 3–10 options best → worst |
| `doc_fields` | check extracted fields against a document image |
| `annotate` | boxes/points on images |
| `ui_review` | tap visual bugs on UI screenshots |
| `media_review` | audio/video: pick, fix transcript, timestamp marks |
| `code_review` | review a diff with line comments |
| `usability` | try a task on your site, time + ease + screenshots |
| `native_check` | a native checker fixes a translated text/HTML/JSON, a native reviewer approves it |
| `proofread` | fix grammar and style in an original text |

See `references/kinds.md` for specs and examples, `references/recipes.md` for ready-made patterns, and `references/screenshots.md` for taking screenshots.
