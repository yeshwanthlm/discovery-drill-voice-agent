import json
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("ReadyCheckSessions")


def lambda_handler(event, context):
    body = json.loads(event.get("body") or "{}")
    trainee_email = body.get("trainee_email", "").strip().lower()

    if not trainee_email:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "trainee_email is required"}),
        }

    resp = table.get_item(Key={"trainee_email": trainee_email})
    item = resp.get("Item")

    if not item:
        result = {
            "has_history": False,
            "weakest_area": "",
            "last_completeness_pct": 0,
            "last_stakeholder_type": "",
        }
    else:
        weakest = item.get("missing_categories", [])
        result = {
            "has_history": True,
            "weakest_area": weakest[0] if weakest else "none",
            "last_completeness_pct": int(item.get("discovery_completeness_pct", 0)),
            "last_stakeholder_type": item.get("stakeholder_type", ""),
        }

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(result),
    }
