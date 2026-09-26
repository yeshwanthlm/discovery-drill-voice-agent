import json
import os
import boto3
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
ses = boto3.client("ses")
table = dynamodb.Table("ReadyCheckSessions")

SENDER_EMAIL = os.environ["SENDER_EMAIL"]
NOTIFY_EMAIL = os.environ["NOTIFY_EMAIL"]

CATEGORIES = [
    "integration_asked",
    "scale_asked",
    "compliance_asked",
    "success_metric_asked",
    "stakeholders_asked",
    "timeline_asked",
]


def extract_fields(body):
    """
    ElevenLabs post-call webhooks nest Data Collection results under
    body["data"]["analysis"]["data_collection_results"][field]["value"].
    transcript_summary is different — a plain, flat, auto-generated
    string at body["data"]["analysis"]["transcript_summary"], always
    present for every conversation, confirmed from ElevenLabs' own docs.
    """
    dc_results = {}
    transcript_summary = ""
    try:
        analysis = body["data"]["analysis"]
        dc_results = analysis.get("data_collection_results", {})
        transcript_summary = analysis.get("transcript_summary", "") or ""
    except (KeyError, TypeError):
        pass

    def get(key, default=""):
        if key in dc_results:
            entry = dc_results[key]
            if isinstance(entry, dict) and "value" in entry:
                return entry["value"]
            return entry
        return body.get(key, default)

    return {
        "trainee_email": get("trainee_email"),
        "trainee_name": get("trainee_name"),
        "scenario_type": get("scenario_type"),
        "stakeholder_type": get("stakeholder_type"),
        "communication_style": get("communication_style"),
        "integration_asked": get("integration_asked", False),
        "scale_asked": get("scale_asked", False),
        "compliance_asked": get("compliance_asked", False),
        "success_metric_asked": get("success_metric_asked", False),
        "stakeholders_asked": get("stakeholders_asked", False),
        "timeline_asked": get("timeline_asked", False),
        "critical_detail_asked": get("critical_detail_asked", False),
        "adaptive_follow_up": get("adaptive_follow_up", False),
        "flagged_quote": get("flagged_quote"),
        "key_takeaway": get("key_takeaway"),
        # debrief_summary (our custom field) kept as a secondary source —
        # transcript_summary (auto-generated, always present) is primary.
        "debrief_summary": get("debrief_summary"),
        "transcript_summary": transcript_summary,
    }


def score_session(data):
    covered = sum(1 for c in CATEGORIES if data.get(c) is True)
    completeness_pct = round((covered / len(CATEGORIES)) * 100)
    adaptive_follow_up = bool(data.get("adaptive_follow_up", False))
    missing = [c.replace("_asked", "") for c in CATEGORIES if not data.get(c)]
    ready_for_poc = completeness_pct >= 66 and adaptive_follow_up

    return {
        "discovery_completeness_pct": completeness_pct,
        "adaptive_follow_up": adaptive_follow_up,
        "ready_for_poc": ready_for_poc,
        "missing_categories": missing,
    }


def write_to_dynamodb(trainee_email, first_name, data, result):
    item = {
        "trainee_email": trainee_email,
        "first_name": first_name,
        "scenario_type": data.get("scenario_type", ""),
        "stakeholder_type": data.get("stakeholder_type", ""),
        "communication_style": data.get("communication_style", ""),
        "flagged_quote": data.get("flagged_quote", ""),
        "key_takeaway": data.get("key_takeaway", ""),
        "debrief_summary": data.get("debrief_summary", ""),
        # bool must be excluded from Decimal conversion — isinstance(True, int)
        # is True in Python, so without this exclusion booleans would hit
        # Decimal(str(v)) -> Decimal("True"), which raises InvalidOperation.
        **{k: (Decimal(str(v)) if isinstance(v, (int, float)) and not isinstance(v, bool) else v)
           for k, v in result.items() if k != "missing_categories"},
        "missing_categories": result["missing_categories"],
    }
    table.put_item(Item=item)


def send_email(display_name, data, result):
    verdict = "READY FOR POC" if result["ready_for_poc"] else "NOT YET READY"
    missing_str = ", ".join(result["missing_categories"]) or "none"
    transcript_summary = (data.get("transcript_summary") or "").strip()
    debrief_summary = (data.get("debrief_summary") or "").strip()

    # Priority: auto-generated transcript_summary (always present, most
    # reliable) > our custom debrief_summary Data Collection field
    # (fragile, has been coming back empty) > a plain templated fallback
    # built from the deterministic score, so the email is never blank.
    if transcript_summary:
        summary_section = transcript_summary
    elif debrief_summary:
        summary_section = debrief_summary
    else:
        summary_section = (
            f"You covered {result['discovery_completeness_pct']}% of the key "
            f"discovery areas this session. Next time, focus on: {missing_str}."
        )

    body = f"""Ready Check — Your Discovery Report Card

{summary_section}

--- Session Detail ---
Scenario: {data.get('scenario_type', '')} ({data.get('stakeholder_type', '')})
Discovery Completeness: {result['discovery_completeness_pct']}%
Verdict: {verdict}
"""

    ses.send_email(
        Source=SENDER_EMAIL,
        Destination={"ToAddresses": [NOTIFY_EMAIL]},
        Message={
            "Subject": {"Data": f"Your Ready Check report card, {display_name}"},
            "Body": {"Text": {"Data": body}},
        },
    )


def lambda_handler(event, context):
    raw_body = json.loads(event.get("body") or "{}")
    data = extract_fields(raw_body)

    trainee_email = (data.get("trainee_email") or "").strip().lower()
    if not trainee_email:
        # Never let an empty partition key value reach put_item — that
        # crashes with ValidationException and blocks everything,
        # including the email. Fall back to a synthetic key and log
        # loudly so the real cause (payload shape mismatch, or Data
        # Collection never capturing this field) is visible and fixable.
        conversation_id = raw_body.get("data", {}).get("conversation_id", "")
        trainee_email = f"unknown-{conversation_id or 'no-id'}"
        print(
            "WARNING: trainee_email was empty in the incoming payload — "
            "using fallback key. Raw body top-level keys:",
            list(raw_body.keys()),
        )
        # Dump the full real payload so we can see EXACTLY where the
        # nested structure differs from what extract_fields assumes,
        # without needing a separate webhook.site inspection.
        print("FULL RAW BODY FOR DEBUGGING:")
        print(json.dumps(raw_body, default=str)[:6000])

    first_name = data.get("trainee_name", "")
    display_name = first_name or trainee_email
    result = score_session(data)

    write_to_dynamodb(trainee_email, first_name, data, result)

    try:
        send_email(display_name, data, result)
        email_status = "sent"
    except Exception as e:
        # DynamoDB write already succeeded — don't let an SES failure
        # turn a partial success into a total failure.
        print("send_email failed:", e)
        email_status = f"failed: {e}"

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"status": "ok", "email_status": email_status, **result}),
    }
