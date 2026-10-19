#!/usr/bin/env bash
# usms-scaling-history.sh - export the enrolment service's complete scaling configuration
# and history as ONE JSON document: outputs/lab-06-scaling-history.json
# No arguments. Every identifier is discovered from the API: the scalable target is found by
# its usms- cluster prefix, and the resourceId is re-derived from the ECS service ARN.
# No access keys are read or referenced; the AWS CLI uses the profile from course.env.
#
# set -uo pipefail without -e: describe-scheduled-actions and describe-scaling-activities are
# unsupported on some builds. Each is recorded in the document as "unsupported" rather than
# aborting the export, because a partial history with the gap named is still a true record.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/configs/course.env"
OUT="$REPO_ROOT/outputs/lab-06-scaling-history.json"

python3 - "$OUT" << 'PY'
import json, subprocess, sys, datetime

def aws(*args):
    r = subprocess.run(["aws", *args, "--output", "json"], capture_output=True, text=True)
    if r.returncode != 0:
        return None, ("UnsupportedOperation" in r.stderr or "not supported" in r.stderr)
    try:
        return json.loads(r.stdout or "null"), False
    except ValueError:
        return None, False

data, _ = aws("application-autoscaling", "describe-scalable-targets", "--service-namespace", "ecs")
targets = [t for t in (data or {}).get("ScalableTargets", [])
           if len(t.get("ResourceId", "").split("/")) == 3 and t["ResourceId"].split("/")[1].startswith("usms-")]
if not targets:
    sys.exit("no ecs scalable target whose cluster begins usms-")
t = sorted(targets, key=lambda x: x["ResourceId"])[0]
_, cluster, service = t["ResourceId"].split("/")

svc, _ = aws("ecs", "describe-services", "--cluster", cluster, "--services", service)
s = ((svc or {}).get("services") or [{}])[0]
service_arn = s.get("serviceArn", "")
rid = service_arn.split(":")[-1] if service_arn else t["ResourceId"]   # final colon-separated field

pol, _ = aws("application-autoscaling", "describe-scaling-policies", "--service-namespace", "ecs", "--resource-id", rid)
policies = (pol or {}).get("ScalingPolicies", [])
policy_arns = {p["PolicyARN"] for p in policies}

# Alarms involved: those listed on the policies, PLUS any alarm whose actions name one of the
# policy ARNs (some builds leave a step policy's own Alarms list empty).
al, _ = aws("cloudwatch", "describe-alarms")
alarms = [a for a in (al or {}).get("MetricAlarms", [])
          if a["AlarmName"] in {x["AlarmName"] for p in policies for x in (p.get("Alarms") or [])}
          or policy_arns.intersection(a.get("AlarmActions") or [])]

sch, sch_unsup = aws("application-autoscaling", "describe-scheduled-actions", "--service-namespace", "ecs", "--resource-id", rid)
act, act_unsup = aws("application-autoscaling", "describe-scaling-activities", "--service-namespace", "ecs",
                     "--resource-id", rid, "--include-not-scaled-activities")

doc = {
  "generated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
  "resourceId": rid,
  "serviceArn": service_arn,
  "service": {"desiredCount": s.get("desiredCount"), "runningCount": s.get("runningCount"),
              "taskDefinition": s.get("taskDefinition")},
  "scalableTarget": {"resourceId": t["ResourceId"], "dimension": t.get("ScalableDimension"),
                     "minCapacity": t.get("MinCapacity"), "maxCapacity": t.get("MaxCapacity"),
                     "roleArn": t.get("RoleARN"), "suspendedState": t.get("SuspendedState")},
  "policies": policies,
  "alarms": [{"name": a["AlarmName"], "state": a.get("StateValue"), "namespace": a.get("Namespace"),
              "metric": a.get("MetricName"), "comparison": a.get("ComparisonOperator"),
              "threshold": a.get("Threshold"), "evaluationPeriods": a.get("EvaluationPeriods"),
              "actions": a.get("AlarmActions")} for a in sorted(alarms, key=lambda a: a["AlarmName"])],
  "scheduledActions": (sch or {}).get("ScheduledActions", []) if sch is not None else ("unsupported" if sch_unsup else "error"),
  "scalingActivities": (act or {}).get("ScalingActivities", []) if act is not None else ("unsupported" if act_unsup else "error"),
}
json.dump(doc, open(sys.argv[1], "w"), indent=2, default=str)
print(f"wrote {sys.argv[1]}")
print(f"resourceId {rid}  policies={len(policies)}  alarms={len(doc['alarms'])}  "
      f"scheduled={doc['scheduledActions'] if isinstance(doc['scheduledActions'], str) else len(doc['scheduledActions'])}  "
      f"activities={doc['scalingActivities'] if isinstance(doc['scalingActivities'], str) else len(doc['scalingActivities'])}")
PY
