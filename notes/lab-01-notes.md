# Lab 01

## What I learned

**Storage mode.** Floci defaults to `memory` mode, so anything I create is
lost when the container stops. Mounting a folder with `--persist` alone does
not fix this — the mode itself has to be set to `hybrid`, otherwise nothing
is ever written to that folder in the first place.

**Attached vs. inline policies.** An attached policy has its own ARN and can
be reused across many identities (e.g. `USMSDeveloperBase` is attached to
both the admins and developers groups). An inline policy belongs to one
identity only, has no ARN, and is deleted along with that identity. I used
this for `USMSSelfManageCredentials`, since it only makes sense for
`usms-dev-01` specifically.

**Key rotation:** create a second key → deploy it → deactivate the old one →
watch for issues → delete the old key once confident.

**Explicit vs. implicit deny.** Both show the same `AccessDenied` error, but
they need different fixes. Implicit deny means the action was never
mentioned in any policy, so adding an `Allow` fixes it. Explicit deny means
a `Deny` statement targets it directly, and that always wins over any
`Allow` — the only fix is to change the `Deny` itself.

## Mistakes I made and how I fixed them

1. **Wrong project path.** My `aws-floci-course` folder was nested inside
   `~/Desktop/SEM7/DAM405/DSO303/`, not directly under `~`, so every
   `~/aws-floci-course/...` command in the lab failed. Fixed by using the
   `$COURSE_ROOT` variable and relative paths instead.

2. **`GetAccountAuthorizationDetails` unsupported.** Returned
   `UnsupportedOperation` on this Floci build. Skipped it — nothing later in
   the lab depends on it.

3. **`floci snapshot save` unsupported.** Used the tar fallback instead:
   `tar -czf ~/floci-data-lab-01.tar.gz -C ~ floci-data`.

4. **`MaxSessionDuration: 1800` rejected.** IAM's real minimum is 3600
   seconds. Created the role with 3600 instead, and enforced the actual
   30-minute limit at assume-time with `--duration-seconds 1800`.

5. **Almost expanded `${aws:username}`.** Used a quoted heredoc (`<< 'EOF'`)
   so the shell wouldn't silently replace the variable before saving it.

---

# Review Questions

**1. Trust vs. permissions policy.**
If permissions are correct but nobody can use the role, the trust policy is
probably missing — nobody is allowed to call `sts:AssumeRole`. IAM keeps
these separate because they answer different questions: trust decides *who*
can become the role, permissions decide *what* it can do.

**2. Explicit vs. implicit deny.**
Both look the same from the outside. Implicit deny means the action was
never allowed anywhere — fix by adding an `Allow`. Explicit deny means a
`Deny` statement blocks it directly, and no amount of `Allow` will override
that — the `Deny` itself has to change.

**3. Roles over keys.**
A role gives temporary, auto-rotating credentials instead of a permanent key
sitting on the server. It can also be scoped tightly to what the server
needs, rather than reusing a developer's broader personal permissions.

**4. The S3 ARN trap.**
`arn:aws:s3:::bucket-name` refers to the bucket, not the objects in it.
`ListBucket` needs the bucket ARN; `GetObject`/`PutObject` need the object
ARN, `arn:aws:s3:::bucket-name/*`. A working policy needs both.

**5. The Floci illusion.**
Commands succeed here no matter how a policy is written, because Floci
doesn't actually enforce IAM policies by default. So success isn't proof a
policy is correct. Better checks: read the JSON for least-privilege issues,
and run `simulate-principal-policy` on real AWS to see the real decision.

**6. The persistence trap.**
Three causes: (1) `--persist` alone doesn't change the storage mode away
from `memory`; (2) a literal `~` in a path is never expanded, so Docker
creates a folder actually named `~`; (3) `floci start` doesn't remember
flags, so a later restart falls back to defaults. A one-minute test that
catches all three: create something, restart, check if it's still there.

**7. Configuration as evidence.**
A committed `docker-compose.yml` lets anyone verify the setup by reading it
— storage mode, bind mount, no hardcoded secrets — without having to trust
that a command was typed correctly at some point. A typed command leaves no
such proof.
