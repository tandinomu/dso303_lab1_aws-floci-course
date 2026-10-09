#!/usr/bin/env bash
# transcript-upload.sh - runs ON usms-web-01.
# Uploads one student transcript to S3. Credentials come from the instance
# profile (usms-ec2-app-profile) via the instance metadata service; this
# script stores, reads and passes no credentials of any kind.
set -euo pipefail

BUCKET="${USMS_BUCKET_NAME:-usms-student-data}"

usage() {
  echo "usage: $(basename "$0") <student-id> <file-path>" >&2
  echo "example: $(basename "$0") 02230302 ./transcript.pdf" >&2
  exit 2
}

[ "$#" -eq 2 ] || usage
STUDENT_ID="$1"
FILE="$2"

[[ "$STUDENT_ID" =~ ^[A-Za-z0-9_-]+$ ]] \
  || { echo "error: student id '$STUDENT_ID' must be letters, digits, - or _" >&2; exit 2; }
[ -f "$FILE" ] \
  || { echo "error: file not found: $FILE" >&2; exit 2; }

KEY="transcripts/${STUDENT_ID}/$(basename "$FILE")"
aws s3 cp "$FILE" "s3://${BUCKET}/${KEY}"
echo "uploaded: s3://${BUCKET}/${KEY}"
