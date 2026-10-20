#!/usr/bin/env bash
# usms-scaling-report.sh - print the scaling decision table of every ECS scalable target
# whose resource ID names a cluster beginning usms-, with a computed verdict.
# No arguments. Discovers every target, policy, alarm and scheduled action from the API.
# Writes a machine-readable copy to outputs/lab-06-scaling-report.json.
#
# set -uo pipefail WITHOUT -e: this is a report tool. On some builds describe-scheduled-actions
# and describe-scaling-activities are unsupported, and a target may have no policies at all.
# Each of those must become a line in the report ("unsupported", "none"), not a reason to
# abort halfway and print half a table. With -e the first unsupported call would kill the run.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/configs/course.env"
OUT="$REPO_ROOT/outputs/lab-06-scaling-report.json"

python3 - "$OUT" << 'PY'
import json, subprocess, sys

def aws(*args):
    """Return (data, unsupported). data is None on any failure."""
    r = subprocess.run(["aws", *args, "--output", "json"], capture_output=True, text=True)
    if r.returncode != 0:
        return None, ("UnsupportedOperation" in r.stderr or "not supported" in r.stderr)
    try:
        return json.loads(r.stdout or "null"), False
    except ValueError:
        return None, False

# Verdict rules, evaluated top to bottom; the FIRST match wins.
#   PINNED first: if min == max nothing can move the count, so every other verdict is moot.
#   FROZEN before AT-CEILING: a suspended target is not scaling at all, whatever its count.
#     A target sitting at its ceiling while suspended would be reported AT-CEILING ("add
#     capacity") when the real fault is that scaling is switched off and nobody said so.
#     The suspension is the silent production hazard, so it must never be hidden by a
#     count-based verdict.
#   AT-CEILING before AT-FLOOR: being unable to grow under load is the urgent condition.
#   AT-FLOOR only means something when there are policies that could move it.
def verdict(t, desired, n_policies):
    mn, mx = t.get("MinCapacity"), t.get("MaxCapacity")
    sus = t.get("SuspendedState") or {}
    if mn is not None and mn == mx:
        return "PINNED"
    if any(sus.get(k) for k in ("DynamicScalingInSuspended", "DynamicScalingOutSuspended", "ScheduledScalingSuspended")):
        return "FROZEN"
    if desired is not None and desired == mx:
        return "AT-CEILING"
    if desired is not None and desired == mn and n_policies > 1:
        return "AT-FLOOR"
    return "ELASTIC"

def signed(steps):
    adj = [s.get("ScalingAdjustment") for s in steps if s.get("ScalingAdjustment") is not None]
    return " / ".join(f"{a:+d}" for a in adj) if adj else "-"

METRIC_SHORT = {"ECSServiceAverageCPUUtilization": "CPU", "ECSServiceAverageMemoryUtilization": "Mem",
                "ALBRequestCountPerTarget": "ALBReq"}

data, _ = aws("application-autoscaling", "describe-scalable-targets", "--service-namespace", "ecs")
targets = [t for t in (data or {}).get("ScalableTargets", [])
           if t.get("ResourceId", "").split("/")[1:2] and t["ResourceId"].split("/")[1].startswith("usms-")]
targets.sort(key=lambda t: t["ResourceId"])

lines, report = [], []
if not targets:
    lines.append("no scalable target in the ecs namespace whose cluster begins usms-")

for t in targets:
    rid = t["ResourceId"]
    _, cluster, service = rid.split("/")[:3]
    svc, _ = aws("ecs", "describe-services", "--cluster", cluster, "--services", service)
    s = ((svc or {}).get("services") or [{}])[0]
    desired, running = s.get("desiredCount"), s.get("runningCount")

    pol, _ = aws("application-autoscaling", "describe-scaling-policies", "--service-namespace", "ecs", "--resource-id", rid)
    policies = sorted((pol or {}).get("ScalingPolicies", []), key=lambda p: p["PolicyName"])

    # Every alarm name we need, looked up in ONE batched call (describe-alarms takes up to 100 names).
    alarm_names = sorted({a["AlarmName"] for p in policies for a in (p.get("Alarms") or [])})
    states = {}
    if alarm_names:
        al, _ = aws("cloudwatch", "describe-alarms", "--alarm-names", *alarm_names)
        states = {a["AlarmName"]: a for a in (al or {}).get("MetricAlarms", [])}

    v = verdict(t, desired, len(policies))
    sus = t.get("SuspendedState") or {}
    on = [k.replace("Suspended", "") for k in ("DynamicScalingInSuspended", "DynamicScalingOutSuspended",
          "ScheduledScalingSuspended") if sus.get(k)]

    lines.append(f"{rid:<45} {t.get('ScalableDimension','?')}")
    lines.append(f"  bounds       min={t.get('MinCapacity')}  max={t.get('MaxCapacity')}   desired={desired}   running={running}   {v}")
    lines.append(f"  suspended    {', '.join(on) if on else 'none'}")
    entry = {"resourceId": rid, "dimension": t.get("ScalableDimension"), "min": t.get("MinCapacity"),
             "max": t.get("MaxCapacity"), "desired": desired, "running": running, "verdict": v,
             "suspended": on, "policies": [], "scheduled": None, "lastActivity": None}

    if not policies:
        lines.append("  policies     none")
    for p in policies:
        name, ptype = p["PolicyName"], p.get("PolicyType")
        alarms = p.get("Alarms") or []
        if ptype == "TargetTrackingScaling":
            c = p.get("TargetTrackingScalingPolicyConfiguration") or {}
            m = (c.get("PredefinedMetricSpecification") or {}).get("PredefinedMetricType") \
                or ("custom" if c.get("CustomizedMetricSpecification") else "?")
            lines.append(f"  target-track {name:<42} {METRIC_SHORT.get(m, m)}/{c.get('TargetValue')}"
                         f"   out={c.get('ScaleOutCooldown', '-')}  in={c.get('ScaleInCooldown', '-')}"
                         + ("  scale-in DISABLED" if c.get("DisableScaleIn") else ""))
            if alarms:
                parts = []
                for a in alarms:
                    kind = "AlarmHigh" if "AlarmHigh" in a["AlarmName"] else "AlarmLow" if "AlarmLow" in a["AlarmName"] else a["AlarmName"]
                    parts.append(f"{kind}={(states.get(a['AlarmName']) or {}).get('StateValue', '?')}")
                lines.append(f"                 alarms  {'  '.join(parts)}")
            else:
                lines.append("                 alarms  none recorded on the policy")
        elif ptype == "StepScaling":
            c = p.get("StepScalingPolicyConfiguration") or {}
            lines.append(f"  step         {name:<42} {signed(c.get('StepAdjustments') or []):<15} cooldown={c.get('Cooldown', '-')}")
            if alarms:
                for a in alarms:
                    al = states.get(a["AlarmName"]) or {}
                    op = {"GreaterThanOrEqualToThreshold": ">=", "GreaterThanThreshold": ">",
                          "LessThanThreshold": "<", "LessThanOrEqualToThreshold": "<="}.get(al.get("ComparisonOperator"), "?")
                    lines.append(f"                 alarm   {a['AlarmName']} = {al.get('StateValue', '?')}"
                                 f"  ({al.get('Namespace', '?')} {al.get('MetricName', '?')} {op} {al.get('Threshold', '?')})")
            else:
                lines.append("                 alarm   none attached")
        else:
            lines.append(f"  {ptype or 'policy':<12} {name}")
        entry["policies"].append({"name": name, "type": ptype, "alarms": [
            {"name": a["AlarmName"], "state": (states.get(a["AlarmName"]) or {}).get("StateValue")} for a in alarms]})

    sch, unsupported = aws("application-autoscaling", "describe-scheduled-actions", "--service-namespace", "ecs", "--resource-id", rid)
    if sch is None:
        lines.append("  scheduled    unsupported on this build" if unsupported else "  scheduled    could not be read")
        entry["scheduled"] = "unsupported" if unsupported else "error"
    else:
        acts = sorted(sch.get("ScheduledActions", []), key=lambda a: a["ScheduledActionName"])
        if not acts:
            lines.append("  scheduled    none")
        for a in acts:
            sta = a.get("ScalableTargetAction") or {}
            lines.append(f"  scheduled    {a['ScheduledActionName']:<34} {a.get('Schedule')}  {a.get('Timezone') or 'UTC'}  min={sta.get('MinCapacity', '-')}")
        entry["scheduled"] = [a["ScheduledActionName"] for a in acts]

    act, unsupported = aws("application-autoscaling", "describe-scaling-activities", "--service-namespace", "ecs",
                           "--resource-id", rid, "--max-items", "1")
    if act is None:
        lines.append("  last activity  unsupported on this build" if unsupported else "  last activity  could not be read")
        entry["lastActivity"] = "unsupported" if unsupported else "error"
    else:
        acts = act.get("ScalingActivities", [])
        if acts:
            a = acts[0]
            lines.append(f"  last activity  {a.get('StartTime')}  {a.get('StatusCode')}  {a.get('Description')}")
            entry["lastActivity"] = {"start": a.get("StartTime"), "status": a.get("StatusCode"), "cause": a.get("Cause")}
        else:
            lines.append("  last activity  none recorded")
    report.append(entry)

print("\n".join(lines))
json.dump(report, open(sys.argv[1], "w"), indent=2, default=str)
print(f"\nmachine-readable copy: {sys.argv[1]}")
PY
