# Lab 05: Putting the ECS Service Behind an Application Load Balancer

## 1. Aim / Objective

To place the USMS enrolment ECS Fargate service behind an internet facing Application Load Balancer (ALB) using the AWS CLI on Floci, so that clients reach the service through one stable DNS name, and to cut over the security groups so that the load balancer is the only thing that can reach the tasks.

## 2. Introduction

Elastic Load Balancing distributes incoming traffic across targets such as EC2 instances, IP addresses and containers. An Application Load Balancer works at layer 7 (HTTP and HTTPS), so it can route requests by path, host or header. It is built from four objects: the load balancer (the DNS name, subnets and security group), the listener (one port and protocol with one default action), rules (a condition and an action, checked in priority order) and the target group (the targets plus the health check). It is important in cloud computing because it gives a stable entry point in front of resources whose addresses keep changing, spreads traffic across Availability Zones for high availability, and only sends traffic to healthy targets. It is typically used for web applications, APIs and microservices.

## 3. Use Case

1. Giving containerised services (ECS on Fargate) one stable DNS name.
2. Routing different URL paths to different services from one hostname.
3. Zero downtime deployments using health checks and connection draining.
4. Spreading traffic across several Availability Zones for high availability.

## 4. System Architecture / Design

```
                    Internet (client, and the USMS web server)
                                   │  http://<ALB DNS name>/
                             Internet Gateway
                                   │
 ┌──────────────────────── USMS VPC 10.0.0.0/16 ─────────────────────────┐
 │  Public subnet a (AZ a)                 Public subnet b (AZ b)         │
 │  [ALB node]                             [ALB node]                     │
 │        └──────── enrolment ALB (internet facing) ────────┘             │
 │                   ALB security group: tcp 80 from anywhere             │
 │                   Listener HTTP:80                                     │
 │                    ├ Rule priority 10: /alb health → fixed 200         │
 │                    └ Default action → enrolment target group (type ip) │
 │                                        health check GET / every 30s    │
 │                   tcp 80 allowed ONLY from the ALB security group      │
 │  Private subnet a (AZ a)                Private subnet b (AZ b)        │
 │  [Fargate task 1]                       [Fargate task 2]               │
 │                                                                        │
 │  ECS cluster → enrolment service (desired 2)                           │
 │  The SERVICE registers and deregisters its own task IPs                │
 └────────────────────────────────────────────────────────────────────────┘
```

**Data flow:** Client → ALB node (public subnet) → listener → rule or default action → target group → Fargate task (private subnet).

## 5. Implementation Procedure, with Results and Evidence

Each step is followed by the screenshot that shows its output.

### Step 1: Resume the environment

Started Floci, loaded the env files from Labs 01 to 04, and printed the twelve values this lab needs.

![Step 1 environment](../../screenshots/lab%2D05/1.png)

### Step 2: Confirm Labs 02, 03 and 04 are intact

Ran the Lab 02, 03 and 04 verification scripts and saved the Lab 04 result for comparison after the cutover.

![Step 2 earlier labs verified](../../screenshots/lab%2D05/2.png)

### Step 3: Probe ELBv2 support

Probed which ELBv2 and ECS features the Floci build supports and recorded the support path.

![Step 3 support probe](../../screenshots/lab%2D05/3.png)

### Step 4: Load balancer security group

Created the ALB security group and allowed tcp 80 from anywhere using a JSON document.

![Step 4 security group created](../../screenshots/lab%2D05/4.1.png)

![Step 4 ingress rule](../../screenshots/lab%2D05/4.2.png)

### Step 4 Your turn: HTTPS port

Added a tcp 443 rule from a JSON document; the group now shows ports 80 and 443.

![Step 4 Your turn ports 80 and 443](../../screenshots/lab%2D05/4%28yourturn%29.png)

### Step 5: Create the Application Load Balancer

Created the internet facing ALB across both public subnets, waited for it to become active, and set idle timeout 60 and drop invalid header fields.

![Step 5 ALB created](../../screenshots/lab%2D05/5.1.png)

![Step 5 ALB active](../../screenshots/lab%2D05/5.2.png)

![Step 5 ALB attributes](../../screenshots/lab%2D05/5.3.png)

### Step 6: Create the target group

Created the enrolment target group: type ip, HTTP 80, health check GET / every 30 seconds, matcher 200.

![Step 6 target group created](../../screenshots/lab%2D05/6.1.png)

![Step 6 target group read back](../../screenshots/lab%2D05/6.2.png)

### Step 6 Your turn: widen and restore the matcher

Widened the matcher to 200 to 399 and restored it to 200; the ARN stayed the same, so nothing was recreated.

![Step 6 Your turn matcher](../../screenshots/lab%2D05/6%28yourturn%29.png)

### Step 7: Target group attributes

Set the deregistration delay to 30 seconds and the algorithm to least outstanding requests.

![Step 7 attributes](../../screenshots/lab%2D05/7.png)

### Step 8: Create the listener

Wrote the default action document and created the HTTP:80 listener forwarding to the target group; the target group now shows one attached load balancer.

![Step 8 listener created](../../screenshots/lab%2D05/8.1.png)

![Step 8 listener verified](../../screenshots/lab%2D05/8.2.png)

### Step 9: Let the load balancer reach the tasks

Allowed tcp 80 from the ALB security group into the enrolment security group.

![Step 9 ingress rule](../../screenshots/lab%2D05/9.png)

![Step 9 verification](../../screenshots/lab%2D05/9verification.png)

### Step 10: Attach the service to the target group

Ran update service with the load balancer. Floci returned success but stored nothing, so a test service proved create service works and the real service was recreated from a backup of its settings with the load balancer attached.

![Step 10 service attachment](../../screenshots/lab%2D05/10.png)

### Step 11: Watch the targets register

After the recreate, two targets registered by the service and became healthy, and ECS health and target health were compared side by side.

![Step 11 target health](../../screenshots/lab%2D05/11.1.png)

![Step 11 service view](../../screenshots/lab%2D05/11.2.png)

![Step 11 two health opinions](../../screenshots/lab%2D05/11.3.png)

### Step 11 Your turn: scale to 3 and back

Raised the desired count to 3 and returned it to 2 without registering or deregistering any target by hand.

![Step 11 Your turn scaling](../../screenshots/lab%2D05/11%28yourturn%29.png)

### Step 12: Prove the path

Tried the data path with curl, then recorded the five block control plane proof.

![Step 12 data path attempt](../../screenshots/lab%2D05/12.1.png)

![Step 12 control plane proof](../../screenshots/lab%2D05/12.2.png)

### Step 13: The cutover

Found the old web tier rule, removed it (by permission, because removing by rule ID reported success but did nothing), and compared the Lab 04 verification before and after: exactly one check changed, from 38/0 to 37/1.

![Step 13 rule lookup](../../screenshots/lab%2D05/13.1.png)

![Step 13 rule removed](../../screenshots/lab%2D05/13.2.png)

![Step 13 only the ALB group remains](../../screenshots/lab%2D05/13.3.png)

![Step 13 Lab 04 verification diff](../../screenshots/lab%2D05/13verification.png)

### Step 14: Forced deployment

Recorded the state, forced a new deployment, polled both sides, and confirmed the same task definition and count with new tasks.

![Step 14 before](../../screenshots/lab%2D05/14.1.png)

![Step 14 forced deployment](../../screenshots/lab%2D05/14.2.png)

![Step 14 poll](../../screenshots/lab%2D05/14.3.png)

![Step 14 after](../../screenshots/lab%2D05/14.4.png)

### Step 15: Add a listener rule

Created the priority 10 rule returning a fixed 200 for the ALB health path and read the rules back in order.

![Step 15 rule documents](../../screenshots/lab%2D05/15.1.png)

![Step 15 rule created](../../screenshots/lab%2D05/15.2.png)

![Step 15 rules read back](../../screenshots/lab%2D05/15.3.png)

![Step 15 verification](../../screenshots/lab%2D05/15verification.png)

### Step 16: Persistence after a restart

Stopped and started Floci, derived every ARN again from the API, and compared seven facts before and after.

![Step 16 before restart](../../screenshots/lab%2D05/16.1.png)

![Step 16 restart](../../screenshots/lab%2D05/16.2.png)

![Step 16 persistence proven](../../screenshots/lab%2D05/16.3.png)

### Step 17: Close the loop and audit

Confirmed the cutover, closed the loop back to the web server, and audited everything tagged Lab 05.

![Step 17 audit](../../screenshots/lab%2D05/17.png)

### Step 18: Write the env file

Looked up every value first and wrote the Lab 05 env file with 15 exports.

![Step 18 env file](../../screenshots/lab%2D05/18.png)

### Step 19: Commit

Checked git status and the ignore rule, then committed the lab files.

![Step 19 git check](../../screenshots/lab%2D05/19.1.png)

![Step 19 commit](../../screenshots/lab%2D05/19.2.png)

### Section 9: Verification

Built and ran the verification script after fixing its tracked outputs check: PASS=47 FAIL=2, both caused by the grace period that Floci does not store.

![Section 9 verification result](../../screenshots/lab%2D05/verification.png)

### Exercise 1: A second path

Created the results target group and a priority 20 rule for /results; rules read back as 10, 20, default.

![Exercise 1 rules](../../screenshots/lab%2D05/e1.png)

### Exercise 2: Repair the Lab 04 script

Changed the source check to expect the ALB security group, added a check that the web tier group is no longer a source, tested it from another folder and with the env file missing, and committed with the reason.

![Exercise 2 repaired script](../../screenshots/lab%2D05/ex2%2Dverify%2Dlab%2D04%2Drepaired.png)

![Exercise 2 missing env file test](../../screenshots/lab%2D05/ex2%2D03%2Dmissing%2Denv%2Dtest.png)

![Exercise 2 commit](../../screenshots/lab%2D05/ex2%2Dcommit.png)

### Exercise 3: Load balancer report tool

Ran the report script; it printed the decision table in evaluation order, identically from two folders.

![Exercise 3 report](../../screenshots/lab%2D05/e3.png)

### Exercise 4: Tidy up

Deleted the priority 20 rule and then the results target group; verification stayed at PASS=47 FAIL=2.

![Exercise 4 tidy up](../../screenshots/lab%2D05/e4.png)

### Exercise 5: ResourceLabel hand off

Derived and validated the ResourceLabel, added it to the env file (16 exports), timed a capacity replacement, and wrote the Lab 06 readiness file.

![Exercise 5 ResourceLabel](../../screenshots/lab%2D05/ex5%2Dresource%2Dlabel.png)

![Exercise 5 readiness file](../../screenshots/lab%2D05/ex5%2Dreadiness.png)

## 6. Results and Evidence

### 6.1 CLI / SDK Output

All CLI screenshots are shown with their steps in Section 5.

### 6.2 AWS Management Console Verification

Not applicable. The lab was performed on Floci (a local AWS emulator), which has no Management Console. All verification was done through AWS CLI output (Section 6.1).

## 7. Analysis and Discussion

### 7.1 Outcome

**What was achieved:** The enrolment service now sits behind an internet facing ALB with a listener, a health rule and a target group. The service registers its own targets, and only the ALB security group can reach the tasks.

**Support path:** Path B (control plane only), partly upgraded. ELBv2 objects were created and described correctly; the service could only be attached to the target group by recreating it; after that, targets registered as healthy, but the grace period is not stored.

**Verification:** Lab 05 verification reports PASS=47 FAIL=2. Both failures come from the health check grace period: Floci returned null for it on create and on update, and the env file check fails because the grace period value is read back from the service as None. This is the benign failure listed in Section 9.2 of the lab. Lab 04 verification reports PASS=39 FAIL=0 after Exercise 2 (it was PASS=37 FAIL=1 straight after the cutover). The Lab 05 env file has 16 exports after Exercise 5.

### 7.2 Errors encountered and how they were resolved

1. **Verification count:** my Lab 04 script has 38 checks, not the 49 the document states, so the expected result after the cutover is PASS=37 FAIL=1, not 48/1.
2. **Git check bug:** the "no secret is tracked by git" check matched the outputs gitkeep file, which the course requires to be tracked, so it could never pass. It was changed to ignore the gitkeep file in both the Lab 04 and Lab 05 scripts.
3. **Floci stopped mid lab:** the CLI could not connect, so Floci was restarted with the up script; hybrid storage kept every resource.
4. **Service attachment ignored:** update service with load balancers returned exit code 0 but stored nothing. A test service proved create service does store it, so the service was deleted and recreated from a backup of its own settings, with the load balancer attached.
5. **Empty target group:** caused by the error above. After the recreate, two targets became healthy.
6. **Revoke by rule ID did nothing:** it returned True but the rule stayed. Revoking by protocol, port and source group worked. Floci's two security group views then disagreed (the rules view still listed a stale rule); the verification scripts read the correct view.
7. **Step 14 poll loop bug:** its query asked for the length of deployments at the top level of the response, which is null, so it errored on every poll. The correct query reads the deployments of the first service.
8. **Step 18 env file bug:** the listener ARN came out empty because of nested escaped backticks inside the heredoc. All values were looked up first and then written to the file.
9. **Grace period not stored:** a genuine Floci limitation with no workaround; recorded as benign.

### 7.3 Observed versus conceptual

**Observed:** the ALB, listener, rules and target group as objects; the target group attached to one load balancer; two targets registered by the service and reported healthy; scaling 2 to 3 to 2; the security cutover; a forced deployment replacing task IDs; persistence after restart.

**Conceptual only:** a real HTTP 200 through the load balancer; target states initial and draining during a deployment (Floci deploys instantly); health checks actually being sent; connection draining; the 2 to 4 minute provisioning time; HTTPS. The target IPs were 172.20.x.x Docker addresses rather than 10.0.3.x and 10.0.4.x, and their Availability Zone was None, because Floci runs tasks as local containers.

### 7.4 Your turn answers

**Step 4 (HTTPS):** Opening tcp 443 only lets traffic through the firewall; the load balancer still needs an HTTPS listener on port 443, and that listener needs a TLS certificate. AWS Certificate Manager issues public certificates free, but only for a domain you own and can validate, so the domain name itself must be bought from a registrar.

**Step 6 (a):** A web application that redirects every request for / to a login page (such as a student portal) answers the health check with a 302, so a strict 200 matcher marks it unhealthy forever.

**Step 6 (b):** It would be a bug in my work, because a verification script exists to assert the configuration we deliberately chose; the failure correctly reports drift, and the fix is to restore the setting, or to change the design on purpose and update the script in the same commit. I also observed that modify target group can change the health check and matcher but not the target type, protocol, port or VPC, which are fixed at creation.

**Step 11:** Without self registration, after every scaling event I would have to find each new task's private IP and register it in the target group by hand, and deregister every stopped task, which is impossible to keep up with when Lab 06 scales automatically.

### 7.5 Exercises

**Exercise 1:** Created the results target group (type ip, HTTP 80, matcher 200 to 399, deregistration delay 15, tags Project, Tier, Lab and Service) and a priority 20 rule for /results and /results/* forwarding to it, using JSON documents in templates. The rules read back in order: 10, 20, default. A request to /results would receive HTTP 503, because the rule matches but the target group has no registered targets to send it to. Note: priority is a string, so a text sort puts "5" after "10".

**Exercise 2:** The failing check asserted the property "the enrolment tasks accept traffic only from a named security group, never from an address range". I changed it to expect the ALB security group (read from the Lab 05 env file, with a safe default so the script still runs without it) and added a second check that the web tier security group is no longer a source, because a check on the new state alone would still pass with both rules present. The expected count is now 39, stated in a comment at the top; an undocumented count is worse than none because nobody can tell whether a changed total means a lost check or an added one. Updating a verification script is right when the design changed deliberately and the change is committed together with the reason; it is hiding a regression when the script is edited only to turn a red result green without the design having changed.

**Exercise 3:** Wrote the load balancer report script. It discovers every ALB whose name starts with usms, then its listeners, rules and target groups, and prints them in evaluation order. It uses set uo pipefail without e, because a report tool must keep going and report a missing listener or unsupported call instead of aborting with half a table. Rules are sorted by a key of (0, priority as a number) for real rules and (1, 0) for the default, because priority is text and the default's priority is the word "default". The output was identical from two directories and a JSON copy was written to outputs.

**Exercise 4: the exposure review**

*What changed:* The enrolment service is no longer reached directly by address; clients now connect to an internet facing load balancer in the public subnets, which forwards to the tasks still sitting in the private subnets. The enrolment security group used to admit the web tier security group and now admits only the ALB security group.

*Internal or internet facing:* An internal scheme would change Step 5 to use the internal scheme and the two private subnets. The DNS name would then resolve only to private addresses reachable inside the VPC. The target group, listener, rules, service attachment and the task security group would not change at all. I recommend internal for USMS enrolment, because the portal web server inside the VPC is the only known client. On the other side, an internet facing load balancer lets students or a future mobile app call the API directly, and it is the only option if the portal is ever moved outside the VPC.

*Exposure delta:*

<table>
<tr><th></th><th>Before this lab</th><th>After this lab</th></tr>
<tr><td>What can reach the load balancer</td><td>No load balancer existed</td><td>Anyone on the internet on tcp 80 (443 is open but nothing listens)</td></tr>
<tr><td>What can reach the tasks</td><td>The web server, through the web tier security group</td><td>Only the load balancer, through the ALB security group</td></tr>
<tr><td>What can reach the tasks directly</td><td>Anything carrying the web tier security group</td><td>Nothing; every request must pass through the listener</td></tr>
</table>

*Monthly cost (US East, N. Virginia, 730 hours):*

<table>
<tr><th>Item</th><th>Derivation</th><th>Per month</th></tr>
<tr><td>ALB hourly charge, idle</td><td>$0.0225 × 730</td><td>$16.43</td></tr>
<tr><td>Two public IPv4 addresses (one per node)</td><td>2 × $0.005 × 730</td><td>$7.30</td></tr>
<tr><td>ALB under load</td><td>2 LCU × $0.008 × 730</td><td>$11.68</td></tr>
<tr><td>Two Fargate tasks (0.25 vCPU, 1 GB each)</td><td>2 × ((0.25 × $0.04048) + (1 × $0.004445)) × 730</td><td>$21.26</td></tr>
</table>

Idle, the load balancer costs about $23.73 a month, more than the two tasks it fronts. Under load it costs about $35.41. "Under load" assumes 50 new connections per second, 1 GB processed per hour, 500 active connections per minute and a few rule evaluations. An LCU is billed on the largest of its four dimensions; for a low traffic API with short requests the dominant one is new connections (25 per second per LCU), not processed bytes, so 50 new connections per second gives 2 LCU. Sources: AWS Elastic Load Balancing pricing page (aws.amazon.com/elasticloadbalancing/pricing), AWS Fargate pricing page (aws.amazon.com/fargate/pricing), and VPC pricing for public IPv4.

*HTTPS plan, in order:*

1. A domain name, bought from a registrar (Route 53 or any other). This comes from outside the free tier and costs money.
2. A public certificate requested in AWS Certificate Manager for that domain. This is free.
3. A DNS validation record created in the domain's DNS, so ACM can prove ownership and issue the certificate.
4. A DNS record pointing the domain at the ALB's DNS name.
5. The tcp 443 rule on the ALB security group, which only opens the port (done in Step 4).
6. An HTTPS listener on port 443 with the certificate and a TLS policy, forwarding to the enrolment target group. This is what actually listens on the port.
7. On the port 80 listener, change the default action to type redirect, returning 301 to HTTPS, so no plaintext login flow remains.

Source: AWS Certificate Manager User Guide, "Requesting a public certificate"; Application Load Balancer User Guide, "HTTPS listeners".

*Tidy up:*

Danger note for the priority 20 rule: What will be deleted: the priority 20 listener rule for /results from Exercise 1. What depends on it: nothing; no service sends traffic to the results target group. Reversible: yes, one create rule call with the Exercise 1 templates recreates it. Effect on later labs: none; the health rule at priority 10 and the default action are untouched.

Danger note for the results target group: What will be deleted: the results target group from Exercise 1. What depends on it: only the priority 20 rule, which is deleted first. Reversible: yes, one create target group call recreates it. Effect on later labs: none; Lab 06 uses the enrolment target group only.

Commands: the priority 20 rule ARN was found by filtering the listener's rules on priority 20 and deleted with the elbv2 delete rule command; the results target group ARN was looked up by name and deleted with the elbv2 delete target group command, in that order, because a target group cannot be deleted while a rule forwards to it. Afterwards the report showed only priority 10 and the default, the target group lookup returned not found, and Lab 05 verification stayed at PASS=47 FAIL=2.

**Exercise 5:** Wrote the ResourceLabel script, which derives both ARNs from the API on every run. The load balancer suffix keeps everything after "loadbalancer/" (it already begins with "app/"), while the target group suffix keeps everything after the last colon (it already includes the word "targetgroup"), so the two need different parameter expansions. The label was validated as six slash separated segments, with "app" first, both names present and "targetgroup" fourth, and was added to the env file (16 exports). The first segment is "app" because it is the load balancer type taken from the ARN; for a Network Load Balancer it would be "net". A forced deployment took [ELAPSED] seconds to fully replace capacity on Floci; this is much faster than real Fargate because Floci starts tasks almost instantly. The readiness file was written for Lab 06 (under both names the lab uses), and it recommends ALBRequestCountPerTarget, because requests per target measure the work the API actually does.

### 7.6 Review questions

1. Lab 04's group referenced security group rule and this lab's load balancer solve the same problem: the tasks have no stable addresses, so anything written against an address is wrong as soon as a task is replaced. Both put a stable name in front of a changing set of addresses and give the job of keeping that set up to date to something else: AWS tracks which interfaces carry a security group, and the ECS service keeps the target group's members current. The general problem is addressing things whose location changes, and the general answer is indirection with an owner. A third solution is DNS service discovery, such as Kubernetes Services resolved by CoreDNS, where a name always points at the current healthy pods.

2. An unhealthy target only says the load balancer could not get the expected answer from outside. It cannot tell an application that is broken from a network path that is blocked (a missing security group rule, a wrong health check path, or a matcher that rejects a redirect). The ECS task's healthStatus, from the container health check, separates the two. I would first compare healthStatus with target health: HEALTHY with unhealthy means the network path, so check the security group rule, then the path and matcher; UNHEALTHY in both means the application, so read the container logs.

3. Having no way to change the target type shows that AWS treats some fields as the identity of a target group rather than its configuration: changing them would make it a different object, so you must recreate it. This matches Lab 04, where a task definition revision is immutable and a change means a new revision. In this lab the load balancer scheme and type, and the target group protocol, port and VPC, behave the same way. The ALB's security groups look as if they should be fixed but can be changed after creation with set security groups.

4. When ECS decides to stop the task, it first deregisters it, so the load balancer marks it draining and sends it no new requests. A request already in flight gets up to deregistration_delay.timeout_seconds (30 seconds, set on the target group) to finish. Then ECS sends SIGTERM and waits stopTimeout (set in the Lab 04 task definition) before SIGKILL, while minimumHealthyPercent (set on the service) keeps capacity up. The request succeeds if it finishes within 30 seconds. With the default of 300 seconds the request would still succeed, but every deployment would wait up to five minutes per task, making a two task deployment around ten minutes.

5. Updating the script immediately keeps it a true record of the current design, so a failure always means something real. Leaving it failing and documenting the failure keeps a record of what the earlier lab built and avoids rewriting history just to turn it green. With four other engineers I would update it in the same commit as the change, with the reason, because a permanently red script trains everyone to ignore it. With one engineer, documenting the known failure is acceptable for a while, because the only person reading it already knows why.

6. The load balancer's nodes sit in the public subnets, which route to the internet gateway through the public route table, so the nodes get public addresses. The tasks sit in the private subnets, whose route table goes only to the NAT gateway and the S3 endpoint, and they have no public IP. The two are joined only by the security group chain: the ALB security group admits the internet on tcp 80, and the enrolment security group admits only the ALB security group. An attacker controlling the load balancer's configuration could change listeners and rules and send traffic to the tasks on tcp 80, but could not reach any other port on the tasks, the database server, or anything not admitted by a security group. Had the tasks been given public addresses, they could be reached directly from the internet, bypassing the load balancer, wherever a security group allowed it.

7. Requests per target is a better scaling signal for a web API because it measures the actual work, it means the same thing whatever size the task is (CPU percentage depends on the CPU reserved), and it rises as soon as traffic arrives, while CPU rises only after work has started. CPU is the better signal for a CPU bound workload where requests vary greatly in cost, such as generating transcript PDFs. ALBRequestCountPerTarget would scale the enrolment application badly if its requests differed hugely in cost, or if it were limited by something else such as the database or long lived connections; the TargetResponseTime metric would have shown that before choosing it.

## 8. Reflection

1. **What I learned:** An ALB is built from four objects: load balancer, listener, rule and target group. The health check belongs to the target group, and the ECS service, not me, keeps the target list up to date. A security group is a name that other rules refer to, not a property of an instance.
2. **Challenges:** Floci silently ignored some settings while reporting success (the service attachment, the grace period and revoking by rule ID), so I had to read back every result instead of trusting the command. Several lab commands also had bugs that I had to diagnose and fix.
3. **Real world application:** I would put an ALB in front of any containerised API for a stable endpoint, zero downtime deployments and path based routing. I would use the internal scheme where there is no external client, and always cut over in the order: add the new path, prove it, then remove the old one.
4. **Further exploration:** HTTPS listeners with ACM certificates, scaling on ALBRequestCountPerTarget in Lab 06, and testing the data path on real AWS to see health checks and draining.

## 9. Conclusion

The objectives of this practical were achieved. The enrolment service was placed behind an internet facing Application Load Balancer across two Availability Zones, the service now registers its own tasks as targets, and the security groups were cut over so that only the load balancer can reach the tasks. Verification passed 47 of 49 checks, and both remaining failures are a documented Floci limitation.

Through this lab I learned how load balancing provides indirection in front of changing containers, how health checks and draining make deployments safe, and how to perform a careful security cutover. I also developed the habit of proving every change by reading it back, which mattered on an emulator that sometimes reported success without acting. Load balancers are essential in the cloud because they give applications a stable, highly available entry point that can grow and change behind the scenes.