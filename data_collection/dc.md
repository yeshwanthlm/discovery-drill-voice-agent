# Data Collection Fields

## stakeholder_type
**Type:** String
Which persona the trainee chose to practice with: return exactly "developer" if they practiced with the Developer persona, or "cto_vp" if they practiced with the CTO/VP persona.

## communication_style
**Type:** String
Which communication style the persona used during the roleplay: "guarded" if the persona was brief and only answered what was directly asked; "open_book" if the persona volunteered extra detail freely; "suspicious" if the persona pushed back and asked "why do you need to know that"; "uninformed" if the persona said things like "I'd have to check with someone else" on non-technical or non-business questions.

## integration_asked
**Type:** Boolean
True if the trainee asked about the current integration surface, API, or existing webhook/technical infrastructure at any point in the conversation. Return False if not raised.

## scale_asked
**Type:** Boolean
True if the trainee asked about order volume, ticket volume, or peak-load/scale at any point. Return False if not raised.

## compliance_asked
**Type:** Boolean
True if the trainee asked about compliance, security, PCI, or data governance requirements at any point. Return False if not raised.

## success_metric_asked
**Type:** Boolean
True if the trainee explicitly asked what success or a good outcome would look like. Return False if not raised.

## stakeholders_asked
**Type:** Boolean
True if the trainee asked who else needs to be involved in the decision or sign-off process. Return False if not raised.

## timeline_asked
**Type:** Boolean
True if the trainee asked about the deadline, timeline, or why the timing matters. Return False if not raised.

## critical_detail_asked
**Type:** Boolean
True if the trainee specifically asked about the compliance/security review timeline (Developer sessions) or the board meeting/budget deadline (CTO/VP sessions) — the single most important risk in this scenario. Return False if not raised.

## adaptive_follow_up
**Type:** Boolean
True if the trainee asked at least one genuine follow-up question building on something the persona had just said, rather than only asking a fixed list of unrelated questions in sequence. Return False if the trainee only asked scripted or unrelated questions.

## flagged_quote
**Type:** String
Extract an exact, verbatim phrase the trainee actually SAID during the roleplay that the Evaluator referenced in the debrief. It must be the trainee's real words from the conversation — never a phrase the Evaluator suggested they "could have said." If no real trainee quote was cited, return an empty string.

## debrief_summary
**Type:** String
The full verbatim coaching debrief text delivered by the Evaluator.

## key_takeaway
**Type:** String
The single most important thing the trainee should improve, in one sentence.
