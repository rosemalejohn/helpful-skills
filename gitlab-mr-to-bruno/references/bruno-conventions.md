# Bruno `.bru` conventions & templates

A `.bru` file is a plain-text request definition. Blocks are `name { … }`.
Order used across this style of collection: `meta`, the HTTP-verb block
(`get`/`post`/`put`/`patch`/`delete`), `params:path`, `headers`, the body block,
optional `script:*`, then `docs`.

Always prefer these repo-wide rules (confirm against the collection's own
`collection.bru` / `CLAUDE.md`, which win if they differ):

- **URLs** start with `{{baseUrl}}` (it already includes the API version prefix
  like `/api/v1`). Never hardcode a host.
- **Auth** is set once at the collection level (`mode: bearer`,
  `token: {{accessToken}}`). So:
  - authed user endpoints → `auth: inherit`
  - public endpoints (login, register, forgot-password, webhooks) → `auth: none`
  - admin endpoints → reference `{{adminToken}}` explicitly rather than inherit.
- **Nested resources** use path params: `url: .../projects/:project/events`
  paired with a `params:path` block mapping `project: {{projectId}}`. Reuse
  existing env-var IDs, not literals.
- **Response envelope**: success is `{ "data": { … } }`; errors are
  `{ "message", "error_code" }`. Note in `docs` when an endpoint deviates
  (e.g. returns fields at the top level, or a non-2xx-wrapped payload).
- **`meta { seq: N }`** controls ordering within a folder — give a new request
  the next number after the current last one in that folder.
- Keep the **`docs { }`** block current: it documents field validation rules and
  is the collection's primary human reference.

---

## Template: public request (no auth), JSON body, token-capturing script

```
meta {
  name: Login
  type: http
  seq: 2
}

post {
  url: {{baseUrl}}/auth/login
  body: json
  auth: none
}

headers {
  Accept: application/json
  Content-Type: application/json
}

body:json {
  {
    "username": "jane.doe@example.com",
    "password": "Password1!"
  }
}

script:post-response {
  if (res.body && res.body.data && res.body.data.access_token) {
    bru.setEnvVar("accessToken", res.body.data.access_token);
  }
}

docs {
  Authenticate with a `username` (email or phone number).

  | Field | Rules |
  |-------|-------|
  | `username` | required, valid email or phone number |
  | `password` | required when username is an email |

  On success returns `data.access_token`, `data.token_type`, `data.expires_in`.
}
```

Only add a `script:post-response` when the endpoint issues a token the rest of
the collection needs (login/register write `accessToken`; admin login writes
`adminToken`). Guard on `res.body.data` before reading it.

## Template: authed request that inherits the Bearer token

```
meta {
  name: Update Profile
  type: http
  seq: 3
}

patch {
  url: {{baseUrl}}/profile
  body: json
  auth: inherit
}

headers {
  Accept: application/json
  Content-Type: application/json
}

body:json {
  {
    "name": "Jane Doe"
  }
}

docs {
  Update the authenticated user's profile.

  | Field | Rules |
  |-------|-------|
  | `name` | required, string, max 255 |

  Returns the updated user under `data`.
}
```

## Template: nested resource with path params (no body)

```
meta {
  name: Delete Event
  type: http
  seq: 4
}

delete {
  url: {{baseUrl}}/projects/:project/events/:event
  body: none
  auth: inherit
}

params:path {
  project: {{projectId}}
  event: {{eventId}}
}

headers {
  Accept: application/json
}

docs {
  Delete a project event.
}
```

## Template: multipart file upload

```
meta {
  name: Scan Receipt
  type: http
  seq: 1
}

post {
  url: {{baseUrl}}/receipt-scanner
  body: multipartForm
  auth: none
}

headers {
  Accept: application/json
}

body:multipart-form {
  receipt: @file(/absolute/path/to/sample.png) @contentType(image/png)
}

docs {
  Extract structured data from a receipt.

  `receipt`: required, file, one of jpg/jpeg/png/webp/heic/pdf, max 10 MB.

  This endpoint is **public** (no Bearer auth required). The response is **not**
  wrapped in a `data` envelope — fields are returned at the top level with a
  `201 Created`.
}
```

## Admin endpoint note

Admin routes authenticate against a separate guard. Instead of `auth: inherit`,
set the bearer token explicitly to the admin var:

```
get {
  url: {{baseUrl}}/admin/users
  body: none
  auth: bearer
}

auth:bearer {
  token: {{adminToken}}
}
```

Run the collection's **Admin > Login** request first to populate `{{adminToken}}`.
