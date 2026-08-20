# Lab 01 — IAM

## Summary

This lab set up a local AWS environment using Floci (run through Docker
Compose) and built the IAM foundation for the USMS project on top of it.

Part A made sure the environment keeps its data across restarts — Floci
defaults to in-memory storage, so I configured `docker-compose.yml` to use
`FLOCI_STORAGE_MODE=hybrid` with a real folder bound to the container, and
proved it works by creating a user, restarting, and confirming it survived.

Part B built the actual IAM structure: three groups, three users, several
policies controlling access, and three roles for different purposes (an EC2
server role, a Lambda role, and a role developers can temporarily assume).

## Environment setup

![Project structure created](../../screenshots/part1/5.1.png)
*Folder structure created before Floci was started, as required.*

![.gitignore blocking a test secret](../../screenshots/part1/6.3.png)
*Proved `outputs/*` correctly ignores files before any real secret existed.*

![Floci running via Compose, healthy](../../screenshots/part1/9.4.png)
*Container started through `docker-compose.yml`, health check passing.*

![whoami.sh — account 000000000000](../../screenshots/part1/13.png)
*Confirms the AWS CLI is talking to Floci, not real AWS.*

![Persistence proof](../../screenshots/part1/14.5.png)
*A user created before a container restart still existed after it.*

![floci-storage-check.sh — all checks pass](../../screenshots/part1/15.4.png)
*Full diagnostic confirming durable storage is correctly configured.*

## IAM foundation

![Groups created](../../screenshots/part2/18.png)
*`usms-admins`, `usms-developers`, `usms-auditors`.*

![Users created and tagged](../../screenshots/part2/19.png)
*`usms-admin-01`, `usms-dev-01`, `usms-audit-01`.*

![Roles and instance profile](../../screenshots/part2/28.png)
*`usms-ec2-app-role` created with a trust policy and wrapped in an instance profile.*

![Temporary credentials via sts assume-role](../../screenshots/part2/30.4.png)
*Assumed `usms-developer-role` and obtained short-lived credentials.*

![Access key created and Git-ignored](../../screenshots/part2/31.png)
*Confirmed the key file is excluded from version control.*

## Exercises

![Exercise 1 — QA identity](../../screenshots/exercises/e1.png)
![Exercise 2 — Reporting read-only policy](../../screenshots/exercises/e2.png)
![Exercise 3 — Analytics partner role](../../screenshots/exercises/e3.png)
![Exercise 4 — Backup operator policy](../../screenshots/exercises/e4.png)
![Exercise 5 — Policy version 3](../../screenshots/exercises/e5.png)

## Final verification

![verify-lab-01.sh — PASS=34, FAIL=0](../../screenshots/verification/verification.png)
*All 34 automated checks pass: environment, persistence, groups, users,
policies, roles, and Git hygiene.*

## Checklist
- [x] whoami.sh shows account 000000000000
- [x] Persistence proven (user survived a restart)
- [x] verify-lab-01.sh — FAIL=0
- [x] Exercises 1–5 completed
