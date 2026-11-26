# Human Touch recipes

All examples are `ask_human` arguments. Add `max_coins` only if your human approved a budget.

## Gate an outgoing email

```json
{"agent": "support-bot", "max_coins": 60, "items": [{
  "ref": "refund-mail-1042", "kind": "approve_action",
  "context": "Customer asked for a refund of a damaged tea order. Policy: refunds within 30 days, no return needed.",
  "spec": {"action": "Send this refund confirmation email", "risk": "medium",
           "details": "Hi ⟦NAME_1⟧,\n\nwe refunded 24.90 EUR to your card…"}
}]}
```

Act only if `result.answer.decision` is `approve`. If it is `edit`, send `result.answer.edited` instead.

## Classify uncertain tickets (batch)

One item per ticket:

```json
{"items": [
  {"ref": "t-1", "kind": "choose", "spec": {"question": "What does the customer want?", "content": "…", "options": ["refund", "replacement", "information", "complaint only"]}},
  {"ref": "t-2", "kind": "choose", "spec": {"question": "What does the customer want?", "content": "…", "options": ["refund", "replacement", "information", "complaint only"]}}
]}
```

## Pick the better LLM output (eval)

```json
{"items": [{"ref": "prompt-v2-vs-v3/case-17", "kind": "compare",
  "spec": {"question": "Which answer helps the user more?", "a": "<output v2>", "b": "<output v3>"}}]}
```

Aggregate `winner` over many cases. Sides are randomized per reviewer.

## Is a brand name OK in another market?

```json
{"items": [{"ref": "name-pl", "kind": "ask", "skill": "lang:pl",
  "spec": {"question": "We want to name our tea brand 'Kurka'. Does it sound odd, funny or offensive in Polish?",
           "answer_schema": {"properties": {"problem": {"type": "boolean", "description": "Is there a problem?"}, "why": {"type": "string"}}, "required": ["problem"]}}}]}
```

## Check a page as a user in a given country

Only send pages you have verified are safe. `attest_safe: true` makes the account owner responsible, and a URL flagged by Google Web Risk bans the account.

```json
{"items": [{"ref": "pricing-de", "kind": "verify_web", "skill": "country:de",
  "spec": {"url": "https://example.com/pricing", "question": "What monthly price is shown for the Pro plan, and in which currency?",
           "checklist": ["Page loads without errors", "Cookie banner can be dismissed", "Prices are in EUR"],
           "attest_safe": true}}]}
```

## Rate support replies on a rubric

```json
{"items": [{"ref": "reply-88", "kind": "rate",
  "spec": {"question": "Rate this support reply", "content": "…",
           "criteria": [{"id": "correct", "label": "Factually correct"}, {"id": "tone", "label": "Friendly, not robotic"}, {"id": "complete", "label": "Answers everything asked"}]}}]}
```

## Native check of a locale file

```json
{"items": [{"ref": "locales/de.json", "kind": "native_check", "target_lang": "de", "source_lang": "en",
  "content": {"cta": "Jetzt Tee bestellen", "empty": "Dein Warenkorb ist leer"},
  "context": "E-commerce app, casual tone, du-form"}]}
```

Attach screenshots of the screens: run `upload_image`, then add `images`.

## Mark hallucinations in an answer before showing it

```json
{"items": [{"ref": "answer-17", "kind": "span_tag",
  "context": "Source document: <paste or summarise the source here>",
  "spec": {"question": "Mark every statement not supported by the source", "content": "…your answer…", "labels": ["unsupported", "contradicts source"]}}]}
```

Then rewrite or drop each returned span.

## Check extracted invoice fields

Upload the invoice page, then:

```json
{"items": [{"ref": "inv-2041", "kind": "doc_fields", "images": [{"id": "IMAGE_ID", "caption": "invoice page 1"}],
  "spec": {"fields": [{"name": "invoice_number", "value": "INV-2041"}, {"name": "date", "value": "2026-11-02"}, {"name": "total", "value": "249.00 EUR"}, {"name": "vat_id", "value": ""}]}}]}
```

Use `answer.fields[].value` as the corrected record; `answer.wrong` lists what changed.

## Review your diff before merging

```json
{"items": [{"ref": "pr-311", "kind": "code_review", "skill": "code:go",
  "spec": {"title": "Retry webhook delivery with backoff", "question": "Any bugs, races or security problems?", "diff": "<git diff output>"}}]}
```

Merge only on `verdict: approve`. Fix every `blocker` comment first.

## Can a new user sign up?

```json
{"items": [{"ref": "signup-test", "kind": "usability", "skill": "country:us",
  "spec": {"url": "https://example.com", "task": "Create a free account and reach the dashboard. Use a made-up name and test@example.com. Stop before any payment.",
           "questions": ["What almost made you give up?"], "max_minutes": 10, "attest_safe": true}}]}
```

## Fix a transcript

Upload the audio, then:

```json
{"items": [{"ref": "call-88", "kind": "media_review", "skill": "lang:de", "images": [{"id": "MEDIA_ID"}],
  "spec": {"question": "Correct the transcript so it matches exactly what is said", "duration_seconds": 95, "transcript": "…STT output…"}}]}
```
