#!/usr/bin/env bash
# lab-03-reachability.sh - classify every running USMS instance by internet reachability.
# Verdicts are computed from route tables and security groups, never from names or tags.
#
# set -e is deliberately NOT used: a missing field or a failed lookup for one instance
# must not abort the report for all the others. Each value is checked explicitly instead.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/configs/course.env"

# Route table for a subnet: its explicit association, or the VPC's main table if none.
route_table_for() {
  local rt
  rt=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$1" \
        --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null </dev/null)
  if [ -z "$rt" ] || [ "$rt" = "None" ]; then
    rt=$(aws ec2 describe-route-tables \
          --filters "Name=vpc-id,Values=$2" "Name=association.main,Values=true" \
          --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null </dev/null)
  fi
  echo "${rt:-None}"
}

printf '%-20s %-15s %-15s %-12s %s\n' NAME PRIVATE PUBLIC VERDICT REASON

aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=USMS" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,PrivateIpAddress,PublicIpAddress,SubnetId,VpcId,SecurityGroups[0].GroupId]' \
  --output text |
while read -r name priv pub subnet vpc sg; do
  rt=$(route_table_for "$subnet" "$vpc")
  igw=$(aws ec2 describe-route-tables --route-table-ids "$rt" \
         --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId | [0]' \
         --output text 2>/dev/null </dev/null)
  sg80=$(aws ec2 describe-security-groups --group-ids "$sg" \
         --query 'SecurityGroups[0].IpPermissions[?FromPort==`80`].IpRanges[].CidrIp' \
         --output text 2>/dev/null </dev/null)

  if [ "$pub" = "None" ]; then pub_shown="-"; else pub_shown="$pub"; fi

  if [[ "$igw" != igw-* ]]; then
    verdict=UNREACHABLE; reason="no igw route on subnet"
  elif [ "$pub" = "None" ]; then
    verdict=NO-ADDRESS;  reason="igw route present but no public address"
  elif grep -q '0\.0\.0\.0/0' <<< "$sg80"; then
    verdict=REACHABLE;   reason="igw route + sg allows 80/tcp from 0.0.0.0/0"
  else
    verdict=BLOCKED;     reason="igw route + public address, but sg does not allow 80/tcp from 0.0.0.0/0"
  fi

  printf '%-20s %-15s %-15s %-12s %s\n' "$name" "$priv" "$pub_shown" "$verdict" "$reason"
done
