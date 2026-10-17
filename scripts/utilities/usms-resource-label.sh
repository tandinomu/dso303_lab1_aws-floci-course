#!/usr/bin/env bash
# usms-resource-label.sh [load-balancer-name] [target-group-name]
# Prints the ResourceLabel that Application Auto Scaling's ALBRequestCountPerTarget needs:
#     app/<lb-name>/<lb-id>/targetgroup/<tg-name>/<tg-id>
# Both ARNs are derived from the API on every run. This script never reads
# configs/lab-05.env for them: a script that reads the answer from a file it helped
# write proves nothing.
#
# Why the two suffixes need DIFFERENT parameter expansions:
#   load balancer ARN  ...:loadbalancer/app/<name>/<id>
#     The part we want already starts with "app/", but it sits AFTER the word
#     "loadbalancer/", which we must drop. So strip the shortest prefix ending in
#     ":loadbalancer/":   ${ALB_ARN#*:loadbalancer/}
#   target group ARN   ...:targetgroup/<name>/<id>
#     Here the part we want INCLUDES the word "targetgroup/", so we must keep it and
#     strip only up to the last colon:   ${TG_ARN##*:}
#   Using ##*: on the load balancer ARN would wrongly keep "loadbalancer/".
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/configs/course.env"

LB_NAME="${1:-usms-enrolment-alb}"
TG_NAME="${2:-usms-enrolment-tg}"

ALB_ARN=$(aws elbv2 describe-load-balancers --names "$LB_NAME" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_NAME" \
  --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)

case "$ALB_ARN" in
  arn:aws:elasticloadbalancing:*:loadbalancer/*) ;;
  *) echo "ERROR: no load balancer named $LB_NAME" >&2; exit 1 ;;
esac
case "$TG_ARN" in
  arn:aws:elasticloadbalancing:*:targetgroup/*) ;;
  *) echo "ERROR: no target group named $TG_NAME" >&2; exit 1 ;;
esac

ALB_SUFFIX="${ALB_ARN#*:loadbalancer/}"
TG_SUFFIX="${TG_ARN##*:}"
LABEL="${ALB_SUFFIX}/${TG_SUFFIX}"

# Validate before printing: 6 segments, "app" first, both names present, "targetgroup" fourth.
SEGS=$(printf '%s' "$LABEL" | awk -F/ '{print NF}')
IFS=/ read -r s1 s2 s3 s4 s5 s6 <<< "$LABEL"
if [ "$SEGS" = 6 ] && [ "$s1" = app ] && [ "$s2" = "$LB_NAME" ] \
   && [ "$s4" = targetgroup ] && [ "$s5" = "$TG_NAME" ]; then
  echo "$LABEL"
else
  echo "ERROR: implausible ResourceLabel: $LABEL" >&2
  exit 1
fi
