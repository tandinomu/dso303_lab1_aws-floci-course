# Lab 01 — Identity and Access Management

## 1. Objective

The purpose of this practical was to set up a local AWS environment using
Floci, an AWS emulator, and to build an IAM identity structure on top of it
for a fictional system called USMS. This covered two parts: making the
local environment reliable enough to keep data between sessions, and
creating the users, groups, policies, and roles needed to manage access
under the principle of least privilege.

## 2. Environment

The environment was built using Docker Compose to run Floci as a container,
with AWS CLI v2 pointed at it through a named profile (`floci`). By default,
Floci stores everything in memory and loses it on restart, so
`docker-compose.yml` was configured with `FLOCI_STORAGE_MODE=hybrid` and a
folder on disk (`~/floci-data`) bound into the container, so state survives
a restart.

## 3. Procedure and Observations

### Step 1–2 — System check and Docker verification

![System identified](../../screenshots/part1/1.png)
*Confirmed OS, shell, and home directory before starting.*

![Docker and Compose verified](../../screenshots/part1/2.png)
*Docker client and daemon both reachable, Compose v2 present.*

### Step 3–4 — Floci CLI and diagnostics

![Floci CLI installed](../../screenshots/part1/3.png)
*Floci CLI installed and on the PATH.*

![floci doctor output](../../screenshots/part1/4.png)
*Environment diagnostics run before starting any container.*

### Step 5 — Project structure

![Directory structure created](../../screenshots/part1/5.png)
*Folder tree created before Floci was started.*

![Structure confirmed](../../screenshots/part1/5.1.png)
*Full folder listing matching the required layout.*

### Step 6 — .gitignore before any secret exists

![.gitignore written](../../screenshots/part1/6.1.png)
*Ignore rules written and Git repository initialised.*

![Git status after staging](../../screenshots/part1/6.2.png)
*`.gitignore` and `.gitkeep` staged as the first commit.*

![Test secret blocked](../../screenshots/part1/6.3.png)
*A fake secret file was correctly ignored by Git before continuing.*

### Step 8 — docker-compose.yml and course.env

![course.env written](../../screenshots/part1/8.1.png)
*Shared, non-secret configuration values defined.*

![docker-compose.yml validated](../../screenshots/part1/8.2.png)
*Compose file parses correctly; the required-variable guard fires as expected.*

### Step 9 — Start scripts and bringing Floci up

![floci-up.sh written](../../screenshots/part1/9.1.png)
*Start script created with preconditions and self-verification.*

![floci-down.sh written](../../screenshots/part1/9.2.png)
*Stop script created; state is preserved on pause.*

![Floci starting](../../screenshots/part1/9.3.png)
*Container pulled and started through Compose.*

![Floci healthy](../../screenshots/part1/9.4.png)
*Health endpoint responding; bind mount verified as real, not a phantom volume.*

### Step 10 — AWS CLI installation

![AWS CLI v2 installed](../../screenshots/part1/10.png)
*`aws --version` confirms CLI v2 is installed.*

### Step 12 — AWS CLI profile

![Profile configured](../../screenshots/part1/12.png)
*`floci` profile created with dummy credentials and `endpoint_url` set.*

### Step 13 — First AWS CLI call

![whoami.sh output](../../screenshots/part1/13.png)
*`sts get-caller-identity` returns account `000000000000`, confirming Floci, not real AWS.*

### Step 14 — Isolation and persistence

![Debug output shows localhost](../../screenshots/part1/14.2.png)
*Request URL confirmed as `localhost:4566`, not `amazonaws.com`.*

![CLI fails when Floci is stopped](../../screenshots/part1/14.3.png)
*Stopping Floci breaks the CLI, proving no fallback to real AWS.*

![Persistence test setup](../../screenshots/part1/14.4.png)
*A test user created before restarting the container.*

![Persistence confirmed](../../screenshots/part1/14.5.png)
*The same user still exists after a full container restart.*

### Step 15 — Storage diagnostics and Part A commit

![floci-storage-check.sh section 1](../../screenshots/part1/15.1.png)
*Container ownership and Compose project verified.*

![floci-storage-check.sh section 2](../../screenshots/part1/15.2.png)
*Storage mode confirmed as durable, not memory.*

![floci-storage-check.sh section 3](../../screenshots/part1/15.3.png)
*Bind mount and host directory verified as real and non-empty.*

![Part A committed](../../screenshots/part1/15.4.png)
*Full diagnostic passing; environment setup committed to Git.*

### Step 17 — Inspecting the empty IAM account

![Empty account confirmed](../../screenshots/part2/17.png)
*`list-users` returns an empty list before any identity is created.*

### Step 18 — Groups

![Groups created](../../screenshots/part2/18.png)
*`usms-admins`, `usms-developers`, `usms-auditors` created.*

### Step 19 — Users

![Users created and tagged](../../screenshots/part2/19.png)
*`usms-admin-01`, `usms-dev-01`, `usms-audit-01` created with ARNs captured.*

![Your turn — intern user](../../screenshots/part2/19(myturn).png)
*Practice user `usms-intern-01` created following the same pattern.*

### Step 20 — Group membership

![Users added to groups](../../screenshots/part2/20.png)
*Membership verified from both the group and user side.*

![Your turn — intern added to auditors](../../screenshots/part2/20(myturn).png)
*`usms-intern-01` added to `usms-auditors`; group now has two members.*

### Step 21 — Managed policy

![ReadOnlyAccess attached](../../screenshots/part2/21.png)
*Read-only policy attached to the auditors group.*

### Step 22 — Developer base policy

![USMSDeveloperBase created and attached](../../screenshots/part2/22.png)
*Customer managed policy written, validated, and attached to two groups.*

### Step 23 — S3 data policy

![USMSStudentDataReadWrite created](../../screenshots/part2/23.png)
*Policy written with separate bucket and object ARNs.*

### Step 24 — CLI skeletons

![create-role skeleton generated](../../screenshots/part2/24.png)
*Parameter template generated without contacting Floci.*

![Your turn — policy and VPC skeletons](../../screenshots/part2/24(myturn).png)
*Additional skeletons generated for `create-policy` and `create-vpc`.*

### Step 25 — Inline policy

![Inline policy on usms-dev-01](../../screenshots/part2/25.png)
*Self-service credentials policy stored using `${aws:username}`.*

### Step 26 — Inspecting what was built

![Full identity inspection](../../screenshots/part2/26.png)
*Groups, attached policies, inline policies, and access keys reviewed for `usms-dev-01`.*

### Step 27 — Policy versions

![New default version set](../../screenshots/part2/27.png)
*`USMSDeveloperBase` updated to v2 without editing the original in place.*

### Step 28 — EC2 role

![EC2 role and instance profile](../../screenshots/part2/28.png)
*Trust policy naming `ec2.amazonaws.com`; role wrapped in an instance profile.*

### Step 29 — Lambda role

![Lambda execution role created](../../screenshots/part2/29.png)
*Trust policy naming `lambda.amazonaws.com`; log-write permissions attached.*

### Step 30 — Human role and STS

![Trust policy and role created](../../screenshots/part2/30.1.png)
*`usms-developer-role` created with an account-principal trust policy.*

![Group given assume permission](../../screenshots/part2/30.2.png)
*Second half of the trust handshake completed for the developers group.*

![Role assumed](../../screenshots/part2/30.3.png)
*Temporary credentials obtained via `sts assume-role`.*

![Identity restored](../../screenshots/part2/30.4.png)
*Returned to the normal identity after using the temporary credentials.*

### Step 31 — Access keys

![Access key created safely](../../screenshots/part2/31.png)
*Key redirected directly to a file, permissions restricted, and confirmed Git-ignored.*

### Step 32 — Policy simulator

![Policy simulation](../../screenshots/part2/32.png)
*Simulated decisions checked against the developer's policy.*

![Your turn — auditor prediction](../../screenshots/part2/32(myturn).png)
*Prediction made and checked for the auditor's read vs. write permissions.*

### Step 33 — Saving lab state

![lab-01.env generated](../../screenshots/part2/33.1.png)
*All ARNs from this lab captured into a reusable configuration file.*

![Snapshot taken](../../screenshots/part2/33.2.png)
*State archived using the tar fallback, since native snapshotting was unsupported.*

![Lab notes written](../../screenshots/part2/33.3.png)
*Lab README completed with a summary of what was built.*

![Part B committed](../../screenshots/part2/33.4.png)
*Final commit for the IAM foundation.*

### Verification

![verify-lab-01.sh — PASS=34, FAIL=0](../../screenshots/verification/verification.png)
*Every required resource and Git-hygiene rule checked automatically, with no failures.*

### Exercises

![Exercise 1 — QA identity](../../screenshots/exercises/e1.png)
*Group and user created; policy attached to the group only.*

![Exercise 2 — Reporting read-only policy](../../screenshots/exercises/e2.png)
*Prefix-restricted read access with explicit deny on write and delete.*

![Exercise 3 — Analytics partner role](../../screenshots/exercises/e3.png)
*Cross-identity role created with both halves of the trust handshake in place.*

![Exercise 4 — Backup operator policy](../../screenshots/exercises/e4.png)
*Least-privilege role designed from a job description, with region restriction.*

![Exercise 5 — Policy version 3](../../screenshots/exercises/e5.png)
*Missing VPC actions identified and added as a new default policy version.*

![Exercise 5 — verification updated](../../screenshots/exercises/e5.1.png)
*`verify-lab-01.sh` updated to check the new default version.*

## 4. Analysis

The main idea running through this lab is separating *who can do
something* from *what they can do*. Trust policies decide who may take on a
role; permissions policies decide what that role can then do. Keeping
identities in groups rather than attaching policies to individuals directly
also makes permissions easier to manage as the number of users grows, since
only group membership needs to change.

A second idea worked through repeatedly was least privilege: policies were
written to list specific actions rather than wildcards, and an explicit
`Deny` was added in one policy to block dangerous actions even if a broader
policy were mistakenly attached later, since an explicit deny always
overrides an allow.

It is also worth noting that Floci does not enforce these policies by
default, so a command succeeding in this lab is not proof the policy is
actually correct — only that its syntax was valid and it was stored. On real
AWS, incorrect policies would be caught at request time; here they had to be
checked by reading the JSON directly.

## 5. Reflection

**What I learned.** How IAM separates identity from permission, why roles
are preferred over long-lived access keys for anything automated, and how a
policy's evaluation logic works (default deny, explicit allow, explicit
deny overriding everything).

**What was difficult.** The project folder ended up nested several
directories deep rather than directly under my home folder, which broke
almost every absolute path given in the lab document. This was diagnosed by
noticing repeated "no such file or directory" errors and confirmed by
searching the filesystem directly; it was fixed by using an environment
variable holding the real project path instead of typing it by hand each
time. A second issue was discovering that `MaxSessionDuration` has a real
minimum of 3600 seconds, lower than the 1800 seconds one exercise called
for; this was fixed by capping the role at 3600 and enforcing the shorter
limit at the point of assuming it instead.

**What would be done differently.** I would check the actual location of
the project folder immediately after creating it, before running any
further commands, rather than assuming it matched the lab document's
example path.

**What remains unclear.** Whether `simulate-principal-policy` would have
returned real results on a different Floci build, since this build did not
support it consistently — this would need testing against real AWS to
confirm.

## 6. References

- AWS CLI Command Reference, `aws iam` — consulted throughout Part B (21 August 2026)
- AWS IAM User Guide, "Policies and permissions in IAM" — consulted for policy evaluation logic (21 August 2026)
- Docker Compose documentation, environment variable interpolation — consulted for the `${VAR:?message}` guard in `docker-compose.yml` (20 August 2026)
