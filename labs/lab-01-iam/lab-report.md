# Lab 01 - Identity and Access Management

## 1. Aim / Objective

To create and manage IAM users, groups, roles, and policies using the AWS CLI against a local AWS emulator (Floci), and to verify that the correct identities, permissions, and access relationships were created.

## 2. Introduction

AWS Identity and Access Management (IAM) is the service that controls who can access an AWS account and what they are allowed to do once inside it.

Its purpose is to manage authentication and authorization separately from the resources themselves. Its key features include users, groups, and roles as different types of identity; policies written in JSON to define permissions; support for both permanent credentials and temporary, auto-expiring credentials through roles; and fine-grained control down to individual actions and resources. IAM is central to cloud computing because almost nothing in a cloud account is meant to be open by default, every resource, from storage to servers, depends on IAM to decide who may touch it. 

Typical applications include giving employees only the access their job requires, letting applications and servers assume roles instead of storing permanent secrets,and separating auditors, developers, and administrators into different permission levels.

## 3. Use Case

- Managing employee identities and permissions using AWS IAM.
- Giving an application server (EC2) temporary, scoped access to storage
  through a role instead of a hardcoded key.
- Allowing a scheduled job (Lambda) to write logs and read specific data
  without being given broad account access.
- Letting an auditor account read everything in an account without being
  able to change anything.

## 4. System Architecture / Design

The lab environment consisted of Floci, a local AWS emulator, run inside
Docker and managed through Docker Compose. The AWS CLI on the host machine was configured with a profile pointing at Floci's endpoint
(`http://localhost:4566`), so every command behaved exactly as it would
against real AWS, without needing an actual AWS account.


## 5. Implementation Procedure

1. Verified Docker and Docker Compose were installed and running.
2. Created the project folder structure before starting any service.
3. Wrote `.gitignore` and initialised Git before any secret could exist,
   and confirmed a test secret was correctly blocked.
4. Wrote `docker-compose.yml` with `FLOCI_STORAGE_MODE=hybrid` and an
   absolute bind mount, since Floci defaults to in-memory storage that does
   not survive a restart.
5. Started Floci through Docker Compose and confirmed it was healthy.
6. Installed AWS CLI v2 and created a named profile (`floci`) pointing at
   the local endpoint.
7. Confirmed the CLI reached Floci and not real AWS, using the account
   number, a debug trace of the request URL, and by stopping Floci and
   observing the CLI fail.
8. Proved persistence by creating a user, restarting the container, and
   confirming the user still existed afterward.
9. Created three IAM groups and three IAM users, and placed each user in
   the correct group.
10. Attached an AWS managed read-only policy to the auditors group.
11. Wrote and attached customer managed policies for developer access and
    for student-data read/write, using correct bucket and object ARNs.
12. Added an inline policy to one user for self-managing their own access
    keys, using the `${aws:username}` policy variable.
13. Created a new version of the developer policy rather than editing it in
    place, keeping the old version available.
14. Created three IAM roles — for an EC2 server, a Lambda function, and a
    human developer — each with its own trust policy, and created an
    instance profile for the EC2 role.
15. Assumed the developer role using STS and obtained temporary
    credentials, then returned to the normal identity.
16. Created a real access key for a user, saved it directly to a file
    rather than displaying it, and confirmed it was excluded from Git.
17. Tested the policy simulator to check whether specific actions would be
    allowed or denied for a given user.
18. Recorded every ARN created into a configuration file for reuse in later
    labs, and archived the environment's state as a backup.
19. Ran an automated verification script checking every resource this lab
    was meant to produce.
20. Completed five independent exercises extending the same identity
    structure: a new group and user, a prefix-restricted read-only policy,
    a cross-identity role with a session limit, a least-privilege role
    designed from a job description, and a new policy version adding
    missing permissions.

## 6. Results and Evidence

### 6.1 CLI / SDK Output

**Environment setup**

![System identified](../../screenshots/part1/1.png)
*OS, shell, and home directory confirmed before starting.*

![Docker and Compose verified](../../screenshots/part1/2.png)
*Docker daemon reachable and Compose v2 present.*

![Floci CLI installed](../../screenshots/part1/3.png)
*Floci CLI installed and available on the PATH.*

![floci doctor diagnostics](../../screenshots/part1/4.png)
*Environment diagnostics run before starting any container.*

![Directory structure created](../../screenshots/part1/5.png)
*Folder tree created before Floci was started.*

![Structure confirmed](../../screenshots/part1/5.1.png)
*Full folder listing matching the required layout.*

![.gitignore written](../../screenshots/part1/6.1.png)
*Ignore rules written and Git repository initialised.*

![First commit staged](../../screenshots/part1/6.2.png)
*`.gitignore` and `.gitkeep` staged as the first commit.*

![Test secret blocked](../../screenshots/part1/6.3.png)
*A fake secret file correctly ignored by Git before continuing.*

![course.env written](../../screenshots/part1/8.1.png)
*Shared, non-secret configuration values defined.*

![docker-compose.yml validated](../../screenshots/part1/8.2.png)
*Compose file parses correctly; required-variable guard fires as expected.*

![floci-up.sh written](../../screenshots/part1/9.1.png)
*Start script created with preconditions and self-verification.*

![floci-down.sh written](../../screenshots/part1/9.2.png)
*Stop script created; state is preserved on pause.*

![Floci starting](../../screenshots/part1/9.3.png)
*Container pulled and started through Compose.*

![Floci healthy](../../screenshots/part1/9.4.png)
*Health endpoint responding; bind mount verified as real, not a phantom volume.*

![AWS CLI v2 installed](../../screenshots/part1/10.png)
*`aws --version` confirms CLI v2 is installed.*

![Profile configured](../../screenshots/part1/12.png)
*`floci` profile created with dummy credentials and `endpoint_url` set.*

![whoami.sh output](../../screenshots/part1/13.png)
*`sts get-caller-identity` returns account `000000000000`, confirming Floci, not real AWS.*

![Debug output shows localhost](../../screenshots/part1/14.2.png)
*Request URL confirmed as `localhost:4566`, not `amazonaws.com`.*

![CLI fails when Floci is stopped](../../screenshots/part1/14.3.png)
*Stopping Floci breaks the CLI, proving no fallback to real AWS.*

![Persistence test setup](../../screenshots/part1/14.4.png)
*A test user created before restarting the container.*

![Persistence confirmed](../../screenshots/part1/14.5.png)
*The same user still exists after a full container restart.*

![Storage check section 1](../../screenshots/part1/15.1.png)
*Container ownership and Compose project verified.*

![Storage check section 2](../../screenshots/part1/15.2.png)
*Storage mode confirmed as durable, not memory.*

![Storage check section 3](../../screenshots/part1/15.3.png)
*Bind mount and host directory verified as real and non-empty.*

![Part A committed](../../screenshots/part1/15.4.png)
*Full diagnostic passing; environment setup committed to Git.*

**IAM foundation**

![Empty account confirmed](../../screenshots/part2/17.png)
*`list-users` returns an empty list before any identity is created.*

![Groups created](../../screenshots/part2/18.png)
*`usms-admins`, `usms-developers`, `usms-auditors` created.*

![Users created and tagged](../../screenshots/part2/19.png)
*`usms-admin-01`, `usms-dev-01`, `usms-audit-01` created with ARNs captured.*

![Practice user created](../../screenshots/part2/19(myturn).png)
*`usms-intern-01` created following the same pattern.*

![Users added to groups](../../screenshots/part2/20.png)
*Membership verified from both the group and user side.*

![Practice user added to group](../../screenshots/part2/20(myturn).png)
*`usms-intern-01` added to `usms-auditors`; group now has two members.*

![ReadOnlyAccess attached](../../screenshots/part2/21.png)
*Read-only policy attached to the auditors group.*

![Developer base policy created and attached](../../screenshots/part2/22.png)
*Customer managed policy written, validated, and attached to two groups.*

![S3 data policy created](../../screenshots/part2/23.png)
*Policy written with separate bucket and object ARNs.*

![CLI skeleton generated](../../screenshots/part2/24.png)
*Parameter template generated without contacting Floci.*

![Additional skeletons generated](../../screenshots/part2/24(myturn).png)
*Skeletons generated for `create-policy` and `create-vpc`.*

![Inline policy stored](../../screenshots/part2/25.png)
*Self-service credentials policy added using `${aws:username}`.*

![Identity inspection](../../screenshots/part2/26.png)
*Groups, attached policies, inline policies, and access keys reviewed.*

![New policy version set as default](../../screenshots/part2/27.png)
*Policy updated to v2 without editing the original in place.*

![EC2 role and instance profile](../../screenshots/part2/28.png)
*Trust policy naming `ec2.amazonaws.com`; role wrapped in an instance profile.*

![Lambda execution role created](../../screenshots/part2/29.png)
*Trust policy naming `lambda.amazonaws.com`; log-write permissions attached.*

![Developer role created](../../screenshots/part2/30.1.png)
*Account-principal trust policy naming `usms-dev-01`.*

![Assume permission granted](../../screenshots/part2/30.2.png)
*Second half of the trust handshake completed for the developers group.*

![Role assumed via STS](../../screenshots/part2/30.3.png)
*Temporary credentials obtained by assuming the developer role.*

![Identity restored](../../screenshots/part2/30.4.png)
*Returned to the normal identity after using the temporary credentials.*

![Access key created safely](../../screenshots/part2/31.png)
*Key redirected to a file, permissions restricted, confirmed Git-ignored.*

![Policy simulation](../../screenshots/part2/32.png)
*Simulated decisions checked against the developer's policy.*

![Auditor prediction checked](../../screenshots/part2/32(myturn).png)
*Prediction verified for the auditor's read vs. write permissions.*

![lab-01.env generated](../../screenshots/part2/33.1.png)
*All ARNs from this lab captured into a reusable configuration file.*

![Snapshot taken](../../screenshots/part2/33.2.png)
*State archived using the tar fallback, since native snapshotting was unsupported.*

![Lab README written](../../screenshots/part2/33.3.png)
*Lab summary completed describing what was built.*

![Part B committed](../../screenshots/part2/33.4.png)
*Final commit for the IAM foundation.*

**Verification**

![verify-lab-01.sh — PASS=34, FAIL=0](../../screenshots/verification/verification.png)
*Every required resource and Git-hygiene rule checked automatically, with no failures.*

**Exercises**

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

### 6.2 AWS Management Console Verification

Floci is a CLI/API-only emulator and does not provide a web console, so no
console screenshots could be taken for this lab. All resource creation was
instead verified directly through the AWS CLI's own read commands (for
example, `aws iam get-group`, `aws iam get-role`, and
`aws iam list-attached-user-policies`), shown above in Section 6.1, which
serve the same verification purpose the console would on real AWS.

## 7. Analysis and Discussion

The objective was achieved: a working local AWS environment was set up with
data that survives a restart, and a full IAM identity structure was built
for USMS, including groups, users, policies, roles, and an instance
profile. The results matched the expected outcomes at each step, confirmed
both manually and by an automated verification script that passed all 34
checks.

A few errors were encountered along the way. The project folder ended up
nested inside several subfolders rather than directly under the home
directory, which broke many of the file paths used throughout the lab; this
was resolved by referencing the project root through a single environment
variable instead of typing the path by hand. Two API calls
(`GetAccountAuthorizationDetails` and the snapshot save feature) were not
supported by this build of Floci and had to be skipped or replaced with a
manual workaround. Creating a role with a 30-minute session limit also
failed at first, since IAM enforces a real minimum of one hour on that
setting; the limit was instead applied at the point of assuming the role.

One observation worth noting is that Floci does not enforce IAM policies by
default — every command succeeded regardless of how strict or loose the
policy was written. This meant correctness had to be judged by reading the
policy documents directly rather than by whether a command worked.

## 8. Reflection

1. **What I learned about this service.** IAM separates identity from
   permission through two different kinds of policy — trust and
   permissions — and evaluates every request using a strict order: deny
   always wins, and nothing is allowed unless something explicitly says so.

2. **Challenges encountered.** Working out that a nested project folder was
   breaking file paths throughout the lab, and discovering that some AWS
   behaviours (like session-duration limits) are stricter than they first
   appear.

3. **Real-world application.** This same structure would be used to manage
   access for an actual team — separating admins, developers, and auditors
   into groups, and giving servers and automated jobs roles instead of
   permanent keys, so that a leaked credential has the smallest possible
   blast radius.

4. **What I would like to explore further.** How IAM policies are actually
   enforced and denied on real AWS, since this could not be observed
   directly in this emulated environment.

## 9. Conclusion

This lab successfully built a durable local AWS environment and a complete
IAM identity foundation for the USMS project, meeting all stated
objectives. The main concepts learned were the separation of trust and
permissions policies, the principle of least privilege, and the difference
between explicit and implicit deny. Practical skills developed included
writing IAM policy JSON by hand, using the AWS CLI's query and output
options to extract and reuse values, and diagnosing configuration issues
methodically rather than guessing. IAM is a foundational AWS service, since
almost every other service depends on it to control who can use it and how.

## 10. Appendix

- IAM policy JSON files: `policies/`
- Environment configuration: `configs/course.env`, `configs/lab-01.env`
- Verification script: `scripts/utilities/verify-lab-01.sh`
- Storage diagnostic script: `scripts/utilities/floci-storage-check.sh`
- Full screenshot set: `screenshots/part1/`, `screenshots/part2/`,
  `screenshots/exercises/`, `screenshots/verification/`
- Detailed conceptual notes and review question answers: `notes/lab-01-notes.md`