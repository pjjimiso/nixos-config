---
name: to-wiki
description: Write what this session found or did into a Wiki's raw/ folder as a Session Note (Findings Note or Work Log) for later Ingest by the Librarian. Usage - /to-wiki <personal|work> [findings|worklog]. The target Wiki must be named.
argument-hint: <personal|work> [findings|worklog]
disable-model-invocation: true
---

# /to-wiki

Write ONE Session Note into a Wiki's `raw/` folder, then stop. The Librarian ingests it later, after the owner has reviewed it.

Arguments: `$ARGUMENTS`

## 1. Resolve the target Wiki (required)

The first argument must be `personal` or `work`. Nothing else counts, and you must not infer it from the session's content or directory.

- `personal` -> `~/pj_wiki` (unless the owner states a different path for it)
- `work` -> `~/work_wiki` (unless the owner states a different path for it)

If no Wiki is named (or the name is neither), **stop now**: write no file anywhere, run no git command, and ask the owner: "Which Wiki should this go to: personal or work?" Do nothing else until they answer.

If the Wiki directory does not exist, say so and stop.

## 2. Choose the kind

If the second argument is `findings` or `worklog`, use it. Otherwise infer it from the session:

- **findings**: the session set out to answer a specific question.
- **worklog**: the session troubleshot something or set something up.

## 3. Write the note yourself

Summarise the session in your own words, from what actually mattered. Do not dump your context, the transcript, or raw tool output. Include only commands, config and paths that someone repeating the work would need.

Save it as `<wiki>/raw/YYYY-MM-DD-<slug>.md` (today's date from `date +%F`; a short lowercase-hyphen slug of the topic). Never overwrite an existing file; if the name exists, pick a different slug. The header values: `date` is today, `wiki` is `personal` or `work`, `origin` is the repo or directory this session ran in (`pwd`), `kind` is `findings` or `worklog`.

### Findings Note

```markdown
# <topic>
- date: YYYY-MM-DD
- wiki: <personal|work>
- origin: <repo or directory the session ran in>
- kind: findings

## Question
## Findings
<!-- each claim marked [verified] with evidence, or [inferred] -->
## Evidence
<!-- file paths, commands, URLs, doc links -->
## Open questions
```

Mark **every** finding `[verified]` (and give the evidence: you saw it in a file, ran the command, read the doc) or `[inferred]` (a guess or deduction you did not check). When unsure, use `[inferred]`. Guesses must never pass as facts.

### Work Log

```markdown
# <topic>
- date: YYYY-MM-DD
- wiki: <personal|work>
- origin: <repo or directory the session ran in>
- kind: worklog

## Goal
## Environment
<!-- versions, hosts, OS, relevant config -->
## What we did
<!-- steps, with the actual commands and config -->
## What didn't work and why
<!-- required: dead ends are the most expensive thing to rediscover -->
## Final state
## How it was verified
## Follow-ups
```

"What didn't work and why" is required. List every dead end with the reason it failed. If there truly were none, say so explicitly. Keep all seven headings.

## 4. Stop

Do **not** ingest, `git add`, commit or push, and do not touch any other file in the Wiki. Tell the owner the path of the note you wrote and that it is a Pending Source they can review, edit or delete before asking the Librarian to ingest.
