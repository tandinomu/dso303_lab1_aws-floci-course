#!/usr/bin/env bash
# lab-04-ecs-inventory.sh: one line per service in the USMS ECS cluster.
# Verdicts are computed from the API, never from names or tags.
#
# set -e is deliberately NOT used: a missing field or failed lookup for one
# service must not stop the report for every other service. Each value is
# checked explicitly instead, and anything missing is printed as N/A.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/configs/course.env"
source "$REPO_ROOT/configs/lab-04.env" 2>/dev/null || true
CLUSTER="${USMS_ECS_CLUSTER:-usms-ecs-cluster}"
JSON_OUT="$REPO_ROOT/outputs/lab-04-ecs-inventory.json"

# Print N/A for empty, None or null, otherwise the value itself.
na() {
  if [ -z "${1:-}" ] || [ "$1" = "None" ] || [ "$1" = "null" ]; then echo "N/A"; else echo "$1"; fi
}

rows="[]"
for arn in $(aws ecs list-services --cluster "$CLUSTER" \
               --query 'serviceArns[]' --output text 2>/dev/null </dev/null); do
  svc=$(aws ecs describe-services --cluster "$CLUSTER" --services "$arn" \
          --query 'services[0]' --output json 2>/dev/null </dev/null)
  if [ -z "$svc" ] || [ "$svc" = "null" ]; then continue; fi

  name=$(jq -r '.serviceName // empty' <<< "$svc")
  desired=$(na "$(jq -r '.desiredCount // empty' <<< "$svc")")
  running=$(na "$(jq -r '.runningCount // empty' <<< "$svc")")
  td_full=$(jq -r '.taskDefinition // empty' <<< "$svc")
  td=$(na "${td_full##*/}")

  # publicip: computed from assignPublicIp; N/A when there is no awsvpc configuration
  pub=$(jq -r '.networkConfiguration.awsvpcConfiguration.assignPublicIp // empty' <<< "$svc")
  case "$pub" in
    ENABLED)  pubv=RISK ;;
    DISABLED) pubv=OK ;;
    *)        pubv=N/A ;;
  esac

  # roles: computed by comparing the two role ARNs in the task definition
  roles=N/A
  if [ -n "$td_full" ]; then
    exec_r=$(aws ecs describe-task-definition --task-definition "$td_full" \
               --query 'taskDefinition.executionRoleArn' --output text 2>/dev/null </dev/null)
    task_r=$(aws ecs describe-task-definition --task-definition "$td_full" \
               --query 'taskDefinition.taskRoleArn' --output text 2>/dev/null </dev/null)
    if [ "$(na "$exec_r")" != "N/A" ] && [ "$(na "$task_r")" != "N/A" ]; then
      if [ "$exec_r" = "$task_r" ]; then roles=SAME; else roles=SEPARATE; fi
    fi
  fi

  printf '%-22s desired=%-3s running=%-3s taskdef=%-20s roles=%-9s publicip=%s\n' \
    "$name" "$desired" "$running" "$td" "$roles" "$pubv"

  rows=$(jq -c --arg n "$name" --arg d "$desired" --arg r "$running" --arg t "$td" \
              --arg ro "$roles" --arg p "$pubv" \
         '. + [{service:$n, desired:$d, running:$r, taskdef:$t, roles:$ro, publicip:$p}]' <<< "$rows")
done

jq . <<< "$rows" > "$JSON_OUT"
