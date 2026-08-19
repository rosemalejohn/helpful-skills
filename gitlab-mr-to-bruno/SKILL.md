---
name: gitlab-mr-to-bruno
description: >-
  Read a GitLab merge request and create or update the matching Bruno API
  documentation (the `.bru` request files in a Bruno collection). Use this
  whenever the user hands you a GitLab MR / merge-request URL (or a bare MR
  number in a Bruno collection repo) and wants the API collection kept in sync
  with backend changes — phrasings like "document this MR", "update Bruno for
  this PR", "add Bruno requests for these endpoints", "sync the collection with
  this merge request". Trigger even if the user says "PR" instead of "MR" — on
  GitLab they are the same thing — and even if they don't say the word "Bruno",
  as long as the intent is to reflect an MR's API changes in a `.bru` collection.
  Always verifies `glab` is authenticated first and aborts with instructions if
  it is not.
---

# GitLab MR → Bruno API docs

Turn a GitLab merge request into accurate Bruno request files. You read the MR
diff, work out which HTTP endpoints were added, changed, renamed, or removed,
then create/update/delete the corresponding `.bru` files so the collection
matches the backend.

The whole point is that a reviewer or teammate can open the Bruno collection
right after an MR lands and hit the new endpoints without reverse-engineering
the code. So favour correctness and completeness of the request definition —
URL, method, auth, path params, body, and the `docs { }` validation block — over
speed.

## Step 0 — Preflight: is `glab` connected?

This skill cannot do anything useful without an authenticated GitLab CLI, so
check first and **abort early** if it isn't set up. Don't try to work around a
missing auth by scraping the web UI.

```bash
glab auth status
```

- Exit code `0` and a "Logged in to … as …" line → proceed.
- Anything else (not installed, not logged in, expired token) → **stop** and
  tell the user exactly how to fix it, then end. Do not continue to Step 1.
  - Not installed: `brew install glab` (macOS) or see https://gitlab.com/gitlab-org/cli.
  - Not logged in: `glab auth login --hostname <your-gitlab-host>`.

Report which host and user you're authenticated as before moving on — it
confirms you're pointed at the right GitLab instance.

## Step 1 — Fetch the MR

You'll usually get a full URL like
`https://gitlab.example.com/group/subgroup/project/-/merge_requests/482`.
Extract two things from it:

- **REPO** — the project path between the host and `/-/merge_requests/`
  (`group/subgroup/project`).
- **IID** — the merge request number (`482`).

If the user gives a bare number (e.g. "MR 482") and you're inside a repo that
`glab` recognises, you can omit `-R` and let `glab` infer it.

Pull both the metadata (for intent and the source branch) and the diff:

```bash
glab mr view <IID> -R <REPO>        # title, description, branch, author
glab mr diff <IID> -R <REPO>        # the full changed-lines diff
```

Read the MR title and description first — they tell you *what the author
intended* (new feature, rename, bugfix), which frames how you read the diff.

## Step 2 — Find the API surface that changed

Work **from the diff only** — treat the diff as the source of truth; do not
assume access to a full backend checkout. Read the changed Laravel files and
extract the HTTP contract. The signals that matter, and where they live:

| What you need | Where it comes from in the diff |
|---|---|
| Route path, HTTP verb, is it public? | `routes/*.php` (`Route::post('receipt-scanner', …)`, middleware groups, `auth:sanctum` vs none) |
| Path/nested params | Route definition (`/projects/{project}/events/{event}`) |
| Request body fields + **validation rules** | FormRequest `rules()` arrays, or inline `$request->validate([...])` in the controller |
| Response shape | Controller return / API Resource (`return new XResource(...)`, `->response()->setStatusCode(201)`) |
| Auth guard | Middleware (`auth:sanctum` = user token; `auth:admin` = admin token; none = public) |

If the diff genuinely doesn't contain enough to define a request (e.g. it
references a FormRequest that isn't part of the diff), don't invent rules —
write the request with what you can see and add a short `docs` note that the
validation rules should be confirmed against the backend. Flag these gaps in
your final summary rather than guessing.

Classify each affected endpoint as **added**, **changed**, **renamed**, or
**removed** — that decides the file action in Step 4.

## Step 3 — Learn this collection's conventions

Before writing anything, ground yourself in *this* collection's house style so
your files blend in rather than following a generic template:

1. Read `collection.bru` — it holds collection-level auth (usually
   `mode: bearer`, `token: {{accessToken}}`) and default headers. This is why
   most requests only need `auth: inherit`.
2. Read `CLAUDE.md` if present — it documents the auth model, env-var IDs, and
   conventions for the specific collection.
3. Skim a couple of existing `.bru` files near where your change lands, plus
   `environments/` for the reusable IDs (`{{projectId}}`, `{{eventId}}`, …).

`references/bruno-conventions.md` in this skill has the `.bru` block-by-block
format and ready-to-adapt templates (public request, authed request, nested
resource, multipart upload). Read it if you're unsure of the syntax.

## Step 4 — Create, update, or remove `.bru` files

Apply the change that matches each endpoint's classification. Reuse existing
env-var IDs and `{{baseUrl}}` — never hardcode a host or a literal ID.

- **Added** → create a new `.bru` in the folder that groups related endpoints
  (create the folder if the feature is new). Give it the next `meta { seq }` in
  that folder. Fill in URL, method, `auth` (`inherit` for authed, `none` for
  public, `{{adminToken}}` for admin), any `params:path`, the request body, and
  a complete `docs { }` block with the validation table and response shape.
- **Changed** → open the existing `.bru` and update only what moved: new/removed
  body fields, changed validation rules, new params, changed status code. Keep
  the `docs { }` block current — it's the collection's primary reference.
- **Renamed** → rename the `.bru` file / update its `url` to match the new
  route, and update `meta { name }`. (The user chose auto-rename.)
- **Removed** → delete the corresponding `.bru` file. (The user chose
  auto-delete.) Note each deletion in your summary so it's visible.

Match the surrounding files' density and tone. The `docs { }` block should read
like the existing ones: a one-line purpose, a validation table or bullet list of
field rules, auth note if it deviates from the collection default, and the
response shape (including whether it uses the `{ "data": … }` envelope).

## Step 5 — Summarise what changed

Close with a short, skimmable report so the user can review before committing:

- **MR**: number, title, source branch, host/user you fetched as.
- **Files created / updated / renamed / deleted**, each as a clickable path.
- **Gaps or assumptions** — anything you couldn't derive from the diff and had
  to leave for the user to confirm.

Don't commit, push, or open anything unless the user asks — just leave the
working tree updated and let them review.
