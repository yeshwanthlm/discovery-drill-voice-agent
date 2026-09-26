# Ready Check — Complete Infrastructure

Everything below is created by ONE `terraform apply`. No manual console
steps for infrastructure. The only thing you configure by hand afterward
is the ElevenLabs agent itself (separate, not part of this Terraform).

---

## What gets created — full resource inventory

### Authentication
- **Cognito User Pool** — the user directory
- **Cognito App Client** — public client, implicit OAuth flow, no secret
- **Cognito Hosted UI domain** — the actual login page
- **3 Cognito Users**, created automatically:
  - You (`admin_email`/`admin_given_name` from your tfvars)
  - `alex.dummy@example.com` ("Alex")
  - `sam.example@example.com` ("Sam")
  - All three share one temporary password: `TempPass123!` — each will be
    prompted to set a real password on first login (normal Cognito
    behavior, not a bug)

### Frontend hosting
- **S3 bucket** — stores the deployable app package
- **2 IAM roles** (+ policy attachments + instance profile) — permissions
  Elastic Beanstalk needs to run
- **Elastic Beanstalk application + environment** — the actual running
  Node.js server, at a predictable URL:
  `http://<eb_cname_prefix>.<aws_region>.elasticbeanstalk.com`
- The frontend's `index.html` is **rendered from a template** at apply
  time, with your real Cognito domain, client ID, and ElevenLabs agent ID
  baked in automatically — you never hand-edit this file

### Backend
- **Lambda function** (`ready-check-backend`) — two routes in one function:
  - `/get-session-history` — reads a trainee's prior session
  - `/log-debrief` — scores a completed session and writes it
- **Lambda Function URL** (public, `NONE` auth) + the explicit
  `aws_lambda_permission` that actually allows public invocation (without
  this, every call returns 403 — this was the entire bug we spent hours
  on earlier tonight, now permanently fixed in code)
- **IAM role**, scoped tightly: only `dynamodb:GetItem`/`PutItem` on this
  one table, plus `ses:SendEmail`/`SendRawEmail` — not a blanket policy

### Data storage
- **DynamoDB table** (`ReadyCheckSessions`)
  - **Partition key: `trainee_email`** (String) — NOT name. This is
    deliberate: spoken names collide ("Jordan" could be two different
    people); email is unique per real user and is never spoken aloud, so
    there's no speech-to-text mangling risk either
  - Billing mode: `PAY_PER_REQUEST` (on-demand) — auto-scales with
    traffic, no manual capacity planning
  - **Read latency is O(1)** regardless of table size or how long ago a
    record was written — a lookup for a user who last used this a year
    ago is exactly as fast as one from 5 seconds ago

  **Full item schema** (written by `log_debrief`, read back by
  `get_session_history`):

  | Field | Type | Written by |
  |---|---|---|
  | `trainee_email` | String | partition key |
  | `first_name` | String | from `trainee_name` in the request |
  | `scenario_type` | String | Data Collection |
  | `stakeholder_type` | String | Data Collection (`developer` / `cto_vp`) |
  | `communication_style` | String | Data Collection |
  | `flagged_quote` | String | Data Collection |
  | `key_takeaway` | String | Data Collection |
  | `discovery_completeness_pct` | Number | computed by `score_session()` |
  | `adaptive_follow_up` | Boolean | computed |
  | `ready_for_poc` | Boolean | computed |
  | `missing_categories` | List of Strings | computed |

  **What `get_session_history` returns** (a subset, reshaped for the
  agent's continuity opening line):
  ```json
  {
    "has_history": true,
    "weakest_area": "compliance",
    "last_completeness_pct": 50,
    "last_stakeholder_type": "developer"
  }
  ```

### Email
- **SES verified sender identity** (`sender_email`) — you still have to
  click the verification link AWS emails you; Terraform can create the
  identity but cannot click a link on your behalf

---

## Known, deliberate simplifications (not bugs — see chat history for why)
- **No server-side JWT verification** — the Lambda trusts the email/name
  the authenticated frontend sends. The real security boundary is "you
  can't even reach the widget without logging in," enforced entirely by
  the frontend. This is a reasonable scope decision for an internal
  enablement tool, not a customer-facing product handling sensitive data.
- **Implicit OAuth flow**, not Authorization Code + PKCE — simpler, no
  backend token-exchange endpoint needed. A production version would
  upgrade this.

## Genuinely unverified — check these, don't assume
- `eb_solution_stack_name` default may not match what's currently
  available in your account/region. Confirm with:
  ```bash
  aws elasticbeanstalk list-available-solution-stacks --query "SolutionStacks[?contains(@,'Node.js')]"
  ```
- The ElevenLabs web widget's `dynamic-variables` attribute shape (in
  `index.html.tpl`) is a best guess, not confirmed against their current
  widget docs — check if the widget doesn't seem to receive the injected
  name/email correctly.

---

## Required folder layout

```
project-root/
├── lambda_function.py
├── frontend/
│   ├── server.js
│   ├── package.json
│   └── public/
│       └── index.html.tpl
└── terraform/
    ├── main.tf
    ├── cognito.tf
    ├── beanstalk.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars   ← you create this, see below
```

---

## Deploy — start to finish

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` — every one of these is required, none have safe
defaults:
```
sender_email          = "you@example.com"
notify_email          = "you@example.com"
elevenlabs_agent_id    = "your_agent_id_here"
cognito_domain_prefix  = "ready-check-yourname"   # must be globally unique
eb_cname_prefix        = "ready-check-yourname"   # must be globally unique per region
admin_email            = "your-real-email@wherever.com"
admin_given_name       = "Yeshwanth"
```

```bash
terraform init
terraform apply
```

Read the outputs when it finishes:
```bash
terraform output
```
You'll get: `function_url`, `dynamodb_table_name`, `cognito_hosted_ui_domain`,
`cognito_client_id`, `frontend_url`, and `cognito_test_accounts` (the 3
usernames + shared temp password).

---

## Verify it's actually working, in order

1. **Check SES** — click the verification link AWS emailed to `sender_email`.
2. **Open `frontend_url`** in a browser — you should see only a "Sign in"
   button, nothing else (proves the gate works before login).
3. **Sign in as yourself** (`admin_email` + `TempPass123!`) — Cognito will
   force a real password change on first login. After that, you land back
   on the page and the ElevenLabs widget should mount.
4. **Test the backend directly**, bypassing the widget, to confirm Lambda/DynamoDB work in isolation:
   ```bash
   curl -i -X POST "<function_url>/get-session-history" \
     -H "Content-Type: application/json" \
     -d '{"trainee_email":"you@example.com"}'
   ```
   Expect `200 OK`, `{"has_history": false, ...}` on a first run.
5. **Log in as Alex, then as Sam** (both `TempPass123!`) — confirm each
   sees their own, separately empty history — proves the email-based
   isolation actually works, not just in theory.

---

## What's NOT covered by this Terraform (by design)
The ElevenLabs agent itself — the workflow graph, personas, knowledge
base documents, guardrails, Data Collection fields, Evaluation Criteria,
and the post-call webhook — is configured separately, directly in the
ElevenLabs dashboard. That's the next step once this infrastructure is
confirmed working end to end.

## Tearing everything down
```bash
terraform destroy
```
Removes every resource listed above, including all 3 Cognito users and
all stored session data.
