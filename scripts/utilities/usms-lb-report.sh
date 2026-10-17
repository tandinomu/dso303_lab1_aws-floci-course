#!/usr/bin/env bash
# usms-lb-report.sh - print the decision table of every ALB whose name starts with usms-
# No arguments. Discovers everything from the API: no ARN, listener, rule or target group
# is hard-coded. Writes a machine-readable copy to outputs/lab-05-lb-report.json.
#
# set -uo pipefail WITHOUT -e: this is a report tool. A load balancer with no listeners,
# or an API call this Floci build does not support, must be reported as a row and the
# tool must carry on to the next object. With -e the first failing call would abort the
# script and print half a table, which hides exactly the faults a report exists to show.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/configs/course.env"
OUT="$REPO_ROOT/outputs/lab-05-lb-report.json"

python3 - "$OUT" << 'PY'
import json, subprocess, sys

def aws(*args):
    r = subprocess.run(["aws", *args, "--output", "json"], capture_output=True, text=True)
    if r.returncode != 0:
        return None
    try:
        return json.loads(r.stdout or "null")
    except ValueError:
        return None

tg_cache = {}
def tg_info(arn):
    if arn in tg_cache:
        return tg_cache[arn]
    tgs = (aws("elbv2", "describe-target-groups", "--target-group-arns", arn) or {}).get("TargetGroups") or []
    name = tgs[0].get("TargetGroupName") if tgs else arn.split("/")[-2]
    th = (aws("elbv2", "describe-target-health", "--target-group-arn", arn) or {}).get("TargetHealthDescriptions") or []
    healthy = sum(1 for t in th if (t.get("TargetHealth") or {}).get("State") == "healthy")
    tg_cache[arn] = {"name": name, "arn": arn, "targets": len(th), "healthy": healthy}
    return tg_cache[arn]

def cond_summary(conds):
    if not conds:
        return "-", "-"
    fields, values = [], []
    for c in conds:
        vals = ((c.get("PathPatternConfig") or {}).get("Values")
                or (c.get("HostHeaderConfig") or {}).get("Values")
                or (c.get("HttpRequestMethodConfig") or {}).get("Values")
                or (c.get("SourceIpConfig") or {}).get("Values")
                or c.get("Values") or [])
        fields.append(c.get("Field", "?"))
        values.append(",".join(vals) or "-")
    return " & ".join(fields), " & ".join(values)

def action_summary(actions):
    # A non-forward action prints its own summary instead of an empty target group column.
    if not actions:
        return "(no action)", None
    a = actions[0]
    t = a.get("Type")
    if t == "forward":
        arn = a.get("TargetGroupArn") or (((a.get("ForwardConfig") or {}).get("TargetGroups") or [{}])[0]).get("TargetGroupArn")
        if not arn:
            return "forward (no target group)", None
        i = tg_info(arn)
        return f'{i["name"]}  ({i["targets"]} targets, {i["healthy"]} healthy)', i
    if t == "fixed-response":
        c = a.get("FixedResponseConfig") or {}
        return f'fixed-response {c.get("StatusCode", "?")}', None
    if t == "redirect":
        c = a.get("RedirectConfig") or {}
        return f'redirect {c.get("StatusCode", "?")} -> {c.get("Protocol", "#{protocol}")}://{c.get("Host", "#{host}")}{c.get("Path", "/#{path}")}', None
    return t or "?", None

# Priority is a STRING, and the default action's priority is the literal word "default".
# A text sort puts "5" after "10" (character by character, "5" > "1"). So sort on a key:
# (0, the priority as an integer) for real rules, and (1, 0) for the default, which
# therefore always comes last, exactly as the load balancer evaluates it.
def prio_key(r):
    p = r.get("Priority", "default")
    if r.get("IsDefault") or p == "default":
        return (1, 0)
    try:
        return (0, int(p))
    except ValueError:
        return (0, 10**9)

lbs = (aws("elbv2", "describe-load-balancers") or {}).get("LoadBalancers") or []
lbs = sorted([l for l in lbs if l.get("LoadBalancerName", "").startswith("usms-")],
             key=lambda l: l["LoadBalancerName"])

lines, report = [], []
if not lbs:
    lines.append("no load balancer whose name starts with usms-")

for lb in lbs:
    azs = len(lb.get("AvailabilityZones") or [])
    sgs = len(lb.get("SecurityGroups") or [])
    state = (lb.get("State") or {}).get("Code", "?")
    lines.append(f'{lb["LoadBalancerName"]:<22} {lb.get("Scheme", "?"):<16} {lb.get("Type", "?"):<12} {state:<8} AZs={azs}  SGs={sgs}')
    entry = {"name": lb["LoadBalancerName"], "arn": lb["LoadBalancerArn"], "scheme": lb.get("Scheme"),
             "type": lb.get("Type"), "state": state, "azs": azs, "securityGroups": sgs, "listeners": []}

    listeners = (aws("elbv2", "describe-listeners", "--load-balancer-arn", lb["LoadBalancerArn"]) or {}).get("Listeners") or []
    if not listeners:
        lines.append("  (no listeners: this load balancer answers nothing)")

    for li in sorted(listeners, key=lambda x: x.get("Port", 0)):
        lines.append(f'  {li.get("Protocol", "?")}:{li.get("Port", "?")}')
        rules = (aws("elbv2", "describe-rules", "--listener-arn", li["ListenerArn"]) or {}).get("Rules") or []
        if not rules:
            # describe-rules unavailable or empty: the listener still has its default action.
            rules = [{"Priority": "default", "IsDefault": True, "Conditions": [],
                      "Actions": li.get("DefaultActions") or []}]
        lrep = {"protocol": li.get("Protocol"), "port": li.get("Port"), "rules": []}
        for r in sorted(rules, key=prio_key):
            field, vals = cond_summary(r.get("Conditions"))
            act, tg = action_summary(r.get("Actions"))
            prio = r.get("Priority", "default")
            lines.append(f'    prio  {prio:<8} {field:<13} {vals:<30} -> {act}')
            lrep["rules"].append({"priority": prio, "field": field, "values": vals,
                                  "action": (r.get("Actions") or [{}])[0].get("Type"),
                                  "summary": act, "targetGroup": tg})
        entry["listeners"].append(lrep)
    report.append(entry)

print("\n".join(lines))
json.dump(report, open(sys.argv[1], "w"), indent=2)
print(f"\nmachine-readable copy: {sys.argv[1]}")
PY
