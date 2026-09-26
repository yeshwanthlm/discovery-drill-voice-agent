# Discovery Calibration Checklist
Used only by the Evaluator node for scoring and debrief guidance.
Persona nodes must never see this document.

---

## Coverage Categories
Tracked via Data Collection. Mark True only if the trainee asked directly
— not if the persona volunteered the information unprompted.

1. integration_asked
   Did the trainee ask about the current integration surface, existing APIs,
   webhooks, or technical infrastructure?
   True: "How does your current support stack connect to your order system?"
   False: Trainee only heard the persona mention webhooks but never asked.

2. scale_asked
   Did the trainee ask about order volume, ticket volume, or peak-load behaviour?
   True: "What does your volume look like during peak season?"
   False: Trainee heard "40% headcount growth" but never asked about volume.

3. compliance_asked
   Did the trainee ask about PCI, security, data governance, or vendor
   access constraints?
   True: "Are there any compliance or security requirements we'd need to
   factor into the integration?"
   False: Trainee asked about "requirements" in a general features sense only.

4. success_metric_asked
   Did the trainee explicitly ask what a good outcome would look like —
   in the persona's own terms, not ElevenLabs' terms?
   True: "What would success actually look like for you at the end of a pilot?"
   False: Trainee assumed success = fewer tickets without confirming.

5. stakeholders_asked
   Did the trainee ask who else needs to be involved or has sign-off authority?
   True: "Who else would need to be part of this conversation before you
   could move forward?"
   False: Trainee only spoke to the single persona without asking about others.

6. timeline_asked
   Did the trainee ask about the real deadline and why it matters — not
   just "what's your timeline?"
   True: "Is there a specific date driving this, or a reason the timing matters?"
   False: Trainee asked "what's your timeline?" and accepted the surface
   answer without exploring why.

---

## Critical Detail (weighted higher than the six categories above)

critical_detail_asked
Did the trainee surface the specific hidden risk for the persona they
were working with?

Developer persona: security/compliance review timeline
True if the trainee asked about vendor security review, data access scope,
or compliance sign-off timeline — surfacing the 6–8 week security review
risk that could blow past the Black Friday deadline.

CTO/VP persona: board meeting / budget deadline
True if the trainee asked about internal urgency, what happens if the
initiative stalls, or why the timing matters — surfacing the 10–12 week
board meeting deadline and budget risk.

Mark False if the trainee only asked a general timeline question without
exploring the underlying reason for urgency.

---

## Adaptive Follow-Up (separate weighted dimension)

adaptive_follow_up
Did the trainee build on what the persona actually just said, rather than
moving to the next scripted question regardless of the answer?

True: Trainee heard a specific detail and asked a follow-up question that
only makes sense given that exact answer.
Example: Persona says "it's cheaper to hire than fix systems" → trainee
asks "what would it take to get that prioritised internally?"

False: Trainee covered every topic on the list but never visibly connected
one answer to the next question. Every question could have been asked in
any order regardless of what the persona said.

This dimension exists specifically to prevent checklist selling —
covering every topic on paper while never actually listening.

---

## Debrief Guidance for the Evaluator

Strengths to highlight:
- Any moment the trainee asked a layered follow-up that reached Layer 2
  or Layer 3 of a persona issue
- Any question that uncovered the critical detail
- Any phrasing that felt natural and conversational rather than scripted

Gaps to call out (in priority order):
1. critical_detail_asked = False → highest priority gap, always mention
2. adaptive_follow_up = False → second priority, call out checklist pattern
3. Any of the six categories missed → mention the 1–2 most important ones,
   not all of them. Pick the ones most relevant to the conversation.

Tone guidance:
- Quote the trainee's actual words for both praise and critique
- For each gap, give the exact alternative phrasing they could have used
- Never mention scores, category names, or variable names out loud
- End on one concrete thing to practise next time
