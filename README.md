# Discovery Drill

An AI-powered discovery-skills trainer for technical sales engineers. Trainees
practice real customer discovery calls against an AI stakeholder persona, then
receive a coaching debrief and an emailed report card scoring how well they ran
the conversation.

Built on [ElevenLabs Agents](https://elevenlabs.io/docs/eleven-agents) for the
voice experience, with a serverless AWS backend for session continuity and
reporting.

---

## Why this exists

In technical sales, deals rarely stall on the demo — they stall in discovery.
Jumping to a pitch before understanding a customer's real constraints leads to
POCs that solve the wrong problem, security reviews that blow past deadlines,
and stakeholders who were never bought in. Strong discovery is the
highest-leverage skill a field engineer has, and it's one you can only build by
doing it repeatedly against realistic pushback.

Discovery Drill gives engineers a safe, repeatable place to practice — with an
AI stakeholder that reveals information only as deep as your questions go, and a
coach that grades you on what you missed.

---

## How it works

1. The trainee signs in (Cognito-gated) and lands on the practice page.
2. A host agent greets them, looks up their past sessions, and helps them pick
   a stakeholder persona.
3. They run a live voice discovery call against the chosen persona — a
   **Developer** or a **CTO/VP** — each with distinct priorities, communication
   styles, and layered pain points that only surface with good questions.
4. When the roleplay ends, the agent steps out of character and delivers a
   coaching debrief: what went well, the biggest gap, and one concrete thing to
   practise next time.
5. A post-call webhook scores the session, stores it for continuity, and emails
   the trainee a report card.

---

## Architecture

**Voice layer — ElevenLabs Agent (a multi-node workflow):**
- **Base** — greets the trainee, calls `get_session_history` for continuity
- **Select** — helps pick a persona and announces the handoff
- **Developer** / **CTO/VP** — the roleplay personas, each grounded in its own
  knowledge base
- **Evaluator** — delivers the coaching debrief and ends the call

Supporting agent config lives in version-controlled folders so it can be
reviewed and restored:
- `system_prompts/` — the prompt for each node
- `knowledge_base_documents/` — persona facts and the scoring checklist
- `data_collection/` — the fields the agent extracts from each conversation
- `evaluation_crieteria/` — the session success rubric
- `edges/` — the workflow routing conditions between nodes
- `tests/` — simulation, next-reply, and tool-call tests for each node

**Backend — AWS, fully provisioned by Terraform (`infra/`):**
- **Two Lambda functions** — `get-session-history` (read) and `log-debrief`
  (score, store, email), each behind a public Function URL
- **DynamoDB** — session continuity, keyed by trainee email
- **SES** — sends the report-card email
- **Cognito** — user pool, hosted-UI login, and seeded users
- **Elastic Beanstalk** — hosts the auth-gated frontend
- **CloudFront + ACM + Route53** — HTTPS on a custom domain

See [`infra/README.md`](infra/README.md) for the full backend deploy guide.

---

## Repository layout

```
.
├── system_prompts/            # Prompt for each agent node
├── knowledge_base_documents/  # Persona facts + scoring checklist
├── data_collection/           # Fields extracted from each conversation
├── evaluation_crieteria/      # Session success rubric
├── edges/                     # Workflow routing conditions
├── tests/                     # Agent test definitions
└── infra/                     # AWS backend + frontend (Terraform)
    ├── frontend/              # Auth-gated web app + widget host
    ├── lambdas/               # Lambda source, one folder per function
    └── terraform/             # All infrastructure as code
```

---

## Getting started

The backend is deployed with Terraform; the ElevenLabs agent is configured in
the ElevenLabs dashboard using the prompts and documents in this repo.

1. **Deploy the backend** — follow [`infra/README.md`](infra/README.md). You'll
   need an AWS account and a domain in Route53.
2. **Configure the ElevenLabs agent** — create a workflow agent and populate
   each node using the files in `system_prompts/`, `knowledge_base_documents/`,
   `data_collection/`, `evaluation_crieteria/`, and `edges/`.
3. **Wire the webhook** — point the agent's post-call webhook at the
   `log-debrief` Function URL from the Terraform outputs.

---

## Configuration & secrets

No secrets are committed to this repository. Copy the example variables file and
fill in your own values:

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`, Terraform state files, and provider binaries are all
gitignored. See [`.gitignore`](.gitignore) for the full list.

---
