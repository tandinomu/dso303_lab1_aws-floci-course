# Lab 06: Implementing Auto Scaling for an ECS Based Application

## 1. Aim / Objective

To hand the enrolment service's desired task count to Application Auto Scaling using the AWS CLI on Floci, so that it can move between a floor of 2 and a ceiling of 10 through target tracking (CPU and requests per target), step scaling (a custom queue metric) and scheduled scaling, and to prove that the configuration is wired correctly and survives a restart.

## 2. Introduction

Application Auto Scaling is the AWS service that adjusts the capacity of scalable resources such as ECS services, DynamoDB tables and Lambda concurrency. For an ECS service it changes exactly one number, the desired task count; ECS and the load balancer built in Labs 04 and 05 do everything else. Its key features are the scalable target (a registration holding the floor and ceiling), target tracking policies (keep a metric near a set value), step scaling policies (add or remove capacity in steps depending on how far a CloudWatch alarm is breached), scheduled actions (change the floor and ceiling at set times) and suspension switches. It matters in cloud computing because it matches capacity to demand, keeping an application available at busy times and cheap at quiet ones. Typical applications are web APIs, background workers and any service with predictable peaks such as university enrolment.

## 3. Use Case

1. Adding tasks automatically when CPU or requests per task rise.
2. Scaling a worker service on the depth of a work queue.
3. Raising capacity before a known event, such as enrolment opening at 08:00.
4. Freezing scale in during a deployment or incident without deleting any policy.

## 4. System Architecture / Design

```
  CloudWatch metrics                              Application Auto Scaling
  ┌─────────────────────────────────┐            ┌────────────────────────────────────────┐
  │ CPU utilisation (Container       │──2 alarms─→│ Target tracking: CPU 50%               │
  │ Insights, Lab 04)                │            │                                        │
  │ Requests per target (ALB, Lab 05)│──2 alarms─→│ Target tracking: 1000 requests/min     │
  │ Custom queue depth metric        │──1 alarm──→│ Step scaling: +1 (100 to 200), +3 (200+)│
  └─────────────────────────────────┘            │ Scheduled: 07:45 min 4, 20:00 min 2    │
                                                 │ Scalable target: min 2, max 10         │
                                                 │ Suspension switches: in, out, scheduled│
                                                 └───────────────────┬────────────────────┘
                                                                     │ writes ONE number
                                                                     ↓
                                                  ECS service: desired task count
                                                                     ↓
                                     ECS starts or stops Fargate tasks in the private subnets
                                                                     ↓
                               The service registers each task in the ALB target group (Lab 05)
                                                                     ↓
                                    After health checks and grace, the task takes traffic
```

**Data flow:** metric → CloudWatch alarm → scaling policy → desired count (clamped to 2 to 10) → ECS starts tasks → the service registers them in the target group → the load balancer sends them requests. A service linked role is the identity Application Auto Scaling uses to change the service.

## 5. Implementation Procedure, with Results and Evidence

Each step is followed by the screenshot that shows its output.

### Step 1: Resume the environment

Started Floci and loaded the six env files from Labs 01 to 05.

![Step 1 environment](../../screenshots/lab%2D06/1.png)

### Step 2: Confirm earlier labs are intact

Ran the verification scripts for Labs 02 to 05 (33/0, 36/0, 39/0 and 47/2, the last with its two documented grace period failures) and confirmed the service was at desired 2 with one deployment.

![Step 2 earlier labs](../../screenshots/lab%2D06/2.png)

### Step 3: Probe what this build supports

Probed Application Auto Scaling and CloudWatch and recorded the support path (Path B: configuration stored, control loop not executed).

![Step 3 probe](../../screenshots/lab%2D06/3.png)

### Step 4: Service linked role

Tried to create the service linked role. Floci reported it already exists under its own name, AWSServiceRoleForEcsApplicationAutoscaling, rather than the real AWS name; reading it under that name showed the aws service role path and trust in the ECS Application Auto Scaling principal.

![Step 4 create attempt](../../screenshots/lab%2D06/4.1.png)

![Step 4 role read back](../../screenshots/lab%2D06/4.2.png)

### Step 5: Register the scalable target

Built the resource ID from the service ARN (three segments, first segment service), registered the target with min 2 and max 10, and confirmed the dimension, the bounds, all suspension switches false and desired still 2.

![Step 5 resource ID](../../screenshots/lab%2D06/5.1.png)

![Step 5 register](../../screenshots/lab%2D06/5.2.png)

![Step 5 service unchanged](../../screenshots/lab%2D06/5.3.png)

![Step 5 verify](../../screenshots/lab%2D06/5verify.png)

### Step 6: Change the bounds by registering again

Raised the ceiling to 12 passing only the maximum, observed the floor survive at 2, then set the ceiling back to 10.

![Step 6 ceiling 12](../../screenshots/lab%2D06/6.1.png)

![Step 6 ceiling restored](../../screenshots/lab%2D06/6.2.png)

### Step 6 Your turn: floor of 5

Registered again with min 5 while two tasks ran. The target stored min 5 but desired stayed 2 for 30 seconds, and describe scaling activities returned UnsupportedOperation. Restored min 2 and set desired back to 2 separately.

![Step 6 Your turn](../../screenshots/lab%2D06/6%28yourturn%29.png)

### Step 7: CPU target tracking policy

Created the CPU policy: target 50, scale out cooldown 60, scale in cooldown 300.

![Step 7 document](../../screenshots/lab%2D06/7.1.png)

![Step 7 policy created](../../screenshots/lab%2D06/7.2.png)

![Step 7 verify](../../screenshots/lab%2D06/7verify.png)

### Step 8: Read the managed alarms

Read the two alarms target tracking created: high (greater than 50, 3 periods of 60 seconds) and low (15 periods). Worked out the Your turn delay arithmetic from them.

![Step 8 alarms](../../screenshots/lab%2D06/8.1.png)

![Step 8 alarm detail](../../screenshots/lab%2D06/8.2.png)

![Step 8 Your turn alarm table](../../screenshots/lab%2D06/8verify.png)

### Step 9: Request count policy

Used the ResourceLabel from Lab 05 Exercise 5, validated it (six segments, app first, targetgroup fourth) and created the requests per target policy at 1000.

![Step 9 ResourceLabel](../../screenshots/lab%2D06/9.1.png)

![Step 9 document](../../screenshots/lab%2D06/9.2.png)

![Step 9 policy created](../../screenshots/lab%2D06/9.3.png)

![Step 9 verify](../../screenshots/lab%2D06/9verify.png)

### Step 10: Step scaling policy and its alarm

Published the custom queue depth metric, created the step policy (+1 for a backlog of 100 to 200, +3 above 200, cooldown 60) and the queue high alarm at 100 whose action is that policy.

![Step 10 metric](../../screenshots/lab%2D06/10.1.png)

![Step 10 step policy](../../screenshots/lab%2D06/10.2.png)

![Step 10 alarm](../../screenshots/lab%2D06/10.3.png)

### Step 11: Scheduled actions

Tried to create the morning (07:45, min 4) and evening (20:00, min 2) weekday actions in Asia/Thimphu, then in UTC. Both create and describe scheduled actions returned UnsupportedOperation, so scheduled scaling is a recorded limitation.

![Step 11 unsupported](../../screenshots/lab%2D06/11.1.png)

### Step 11 Your turn: one off results night action

Tried an at() action ten minutes ahead raising the floor to 6; it was rejected as unsupported, and min and desired stayed at 2.

![Step 11 Your turn](../../screenshots/lab%2D06/11%28yourturn%29.png)

### Step 12: Fire the alarm

Predicted 2 to 5 (breach 160 selects +3). Pushed the metric to 260; the alarm stayed INSUFFICIENT_DATA, so it was forced to ALARM, but desired stayed 2. The six block fallback proof showed the full chain (metric, alarm, policy ARN, +3 step, bounds 2 to 10). Returned the metric down first, then the count.

![Step 12 fallback proof](../../screenshots/lab%2D06/12.png)

### Step 13: Suspend and resume

Suspended scale in only, confirmed the policies were unchanged, then resumed so all three switches were false.

![Step 13 suspended](../../screenshots/lab%2D06/13.1.png)

![Step 13 policies unchanged](../../screenshots/lab%2D06/13.2.png)

![Step 13 resumed](../../screenshots/lab%2D06/13.3.png)

### Step 14: Persistence after restart

Recorded the target, switches, policies and alarm, restarted Floci, derived every identifier again from the API and diffed: persistence proven (scheduled actions absent from both records because they cannot be read).

![Step 14 before](../../screenshots/lab%2D06/14.1.png)

![Step 14 restart](../../screenshots/lab%2D06/14.2.png)

![Step 14 persistence proven](../../screenshots/lab%2D06/14.3.png)

### Step 15: Close the loop

Traced the nine line chain from a student clicking Register to a task serving traffic and confirmed the task definition and load balancer were untouched.

![Step 15 chain](../../screenshots/lab%2D06/15.png)

### Step 16: Write the env file

Wrote the Lab 06 env file (22 exports). The resource ID line came out empty and was corrected afterwards (see Section 7).

![Step 16 env file](../../screenshots/lab%2D06/16.png)

### Step 17: Repair and commit

Repaired the cleanup order hints, fixed the lines the blanket replace broke, and committed.

![Step 17 repair](../../screenshots/lab%2D06/17.1.png)

![Step 17 commit](../../screenshots/lab%2D06/17.2.png)

### Section 9: Verification

Built the verification script, fixed its tracked outputs check, and ran it: PASS=39 FAIL=3, all three failures being the scheduled action checks.

![Section 9 verification](../../screenshots/lab%2D06/verification.png)

### Exercise 1: Memory policy, scale out only

Created the memory policy (target 70, cooldowns 60 and 600, scale in disabled). Managed alarms went 4 to 6 instead of 4 to 5; verification stayed 39/3.

![Exercise 1](../../screenshots/lab%2D06/e1.png)

### Exercise 2: Scale in step policy

Created the scale in step policy and the queue low alarm, pushed the metric to 5 and forced the alarm; desired stayed 2. Deleted the alarm first, then the policy.

![Exercise 2 test](../../screenshots/lab%2D06/e2.1.png)

![Exercise 2 deletion](../../screenshots/lab%2D06/e2.2.png)

### Exercise 3: Scaling report tool

Wrote the scaling report script; identical output from two folders, FROZEN while suspended, PINNED at min and max 3, restored afterwards.

![Exercise 3 report](../../screenshots/lab%2D06/e3.png)

### Exercise 4: Tidy up

Deleted the Exercise 1 memory policy (the Exercise 2 objects were already gone); three policies and four managed alarms remained, verification 39/3.

![Exercise 4 tidy up](../../screenshots/lab%2D06/e4.png)

### Exercise 5: Hand off to Lab 10

Exported the scaling history (7961 bytes), recorded latency as not observed with a cited figure, added two exports (24 total), and wrote the Lab 10 readiness file including the failed head bucket check.

![Exercise 5 readiness](../../screenshots/lab%2D06/e5.png)

## 6. Results and Evidence

### 6.1 CLI / SDK Output

All CLI screenshots are shown with their steps in Section 5.

### 6.2 AWS Management Console Verification

Not applicable. Floci has no Management Console, so all verification was done through the AWS CLI (Section 5).

## 7. Analysis and Discussion

### 7.1 Outcome

The enrolment service now has a scalable target (floor 2, ceiling 10), a CPU policy, a requests per target policy, a step policy with its own alarm, and suspension switches. Nothing in the task definition, load balancer or security groups changed.

**Support path:** Path B. Floci stores and persists the target, policies and alarms, but does not evaluate alarms, run alarm actions, enforce the floor, or support scheduled actions, scaling activities and alarm history.

**Verification:** PASS=39 FAIL=3. All three failures are the scheduled action checks, caused by scheduled actions being unsupported. Every check the lab calls never benign (no suspension, desired 2, floor 2) passed.

### 7.2 Errors and how they were resolved

1. **Service linked role:** Floci uses its own role name; the role was found under that name with the correct path and trust.
2. **Floor not enforced:** min 5 was stored but desired stayed 2. Lowering the floor also does not lower the count, so desired was reset separately.
3. **Scheduled actions unsupported:** create and read both fail; recorded, with the schedules documented on paper.
4. **Alarm loop not executed:** the alarm was forced to ALARM but desired stayed 2, so the six block fallback proof was used.
5. **Empty resource ID in the env file:** the escaped awk field in the heredoc failed, and the lab's empty value check missed it because macOS grep does not support \|. Corrected to match the API.
6. **Cleanup script replace:** Step 17's blanket replace broke three Lab 04 references; the order Lab 06, Lab 05, Lab 04 was restored by hand.
7. **Git:** the Step 17 commit named files not yet built, so nothing was staged; the tracked outputs check also matched the gitkeep file and was fixed as in Labs 04 and 05.

### 7.3 Observed versus conceptual

**Observed:** the target and bounds, registering again keeping omitted values, the four managed alarms (3 and 15 evaluation periods), the alarm action naming the step policy, suspension, and persistence.

**Conceptual only:** the floor raising desired, alarms firing, policies changing desired, scaling activities, scheduled actions, task start time and the grace period.

### 7.4 Your turn answers

**Step 6 (floor of 5):** (a) The scalable target makes the change by enforcing its floor; no policy is involved, and ECS only carries out the count. (b) The service would run 5 tasks instead of 2 all night at two and a half times the cost, and could not scale in below 5; describe scalable targets would have shown MinCapacity 5.

**Step 8 (delay):** 180 s (alarm, 60 × 3) + about 0 (policy) + about 45 (task start) + 60 (grace) = about 285 s. I would shorten the alarm term first, using a step policy on a one period alarm; the cost is scaling out on short spikes that would pass by themselves.

**Step 11 (one off action):** could not be created on this build. After an at() action fires, the record and the raised floor both stay, so months later the service still runs 6 tasks with nobody knowing why; the runbook needs the delete scheduled action command and the call that puts the floor back to 2. Thimphu has no daylight saving, so a schedule converted to UTC by hand stays correct here.

### 7.5 Exercises

**Exercise 1:** Memory policy at 70, cooldowns 60 and 600, scale in disabled. On real AWS alarms go 4 to 5 because a scale out only policy needs no low alarm; this build created 6. Whether memory or CPU scales out first depends on real usage figures from Container Insights. Disabling scale in on one policy does not change the others, since scale in needs every policy able to scale in to agree.

**Exercise 2:** Scale in steps are measured as metric minus threshold, so bounds are 0 or negative and adjustments negative: minus 1 for a metric of 10 to 20, minus 2 below 10. The cooldown (300) is longer than scale out's (60) to avoid removing capacity that is needed again. Forcing the alarm changed nothing: alarm actions do not run here, and on real AWS 2 minus 2 is below the floor, so the minus 2 step is unreachable from the baseline. Deleted alarm first, then policy. A CPU step policy at 60 alongside CPU target tracking at 50 makes them fight: the step policy adds tasks, CPU falls below 50, and target tracking removes them. I would keep target tracking alone.

**Exercise 3:** The scaling report script discovers every usms target, its policies, alarms (one batched lookup), scheduled actions and activities, and computes a verdict in the order PINNED, FROZEN, AT CEILING, AT FLOOR, ELASTIC. FROZEN outranks AT CEILING because a suspended target is not scaling at all, and calling it "at ceiling" would hide that. It uses no e flag so unsupported calls become lines, not crashes. It gave identical output from two folders, FROZEN when suspended and PINNED at min and max 3. At baseline it shows AT FLOOR, which is what the lab's own rules give.

**Exercise 4: enrolment week plan**

*Is it solved:* Reactive scaling will handle the double traffic of the three weeks well. It handles sudden spikes badly, because every scale out waits for an alarm, a task start and a grace period, and it stops at 10. In the first twenty minutes of a cohort day it cannot help: the first new task serves about five minutes after the surge begins.

*Why 40 times is not a scaling problem:* target tracking reaches 10 tasks in about 285 s; the step policy alone takes about 405 s (180 + 60 + 60 + 45 + 60). Ten tasks at 1000 requests per target per minute is 10,000 per minute, about 167 per second. If normal traffic is 2,000 per minute, 40 times is 80,000 per minute and needs 80 tasks, so the ceiling of 10 covers only 5 times normal.

*Addresses:* each private /24 has 256 addresses minus 5 reserved by AWS = 251; subnet a also holds the database, so about 501 task addresses in total. The real limit is the Fargate vCPU quota (6 vCPUs by default for new accounts, only 24 tasks of 0.25 vCPU).

*Plan (Asia/Thimphu, assuming enrolment opens 14 November 2026):*

<table>
<tr><th>Action</th><th>When</th><th>Bounds</th></tr>
<tr><td>Window opens</td><td>at() 14 November, 07:30</td><td>min 4, max 20</td></tr>
<tr><td>Each cohort morning</td><td>at() 07:30 on each cohort date</td><td>min 80, max 90</td></tr>
<tr><td>Cohort morning ends</td><td>at() 09:30 on each cohort date</td><td>min 4, max 20</td></tr>
<tr><td>Window closes</td><td>at() 5 December, 20:00</td><td>min 2, max 10</td></tr>
</table>

The requests target drops from 1000 to 800 during the window. Every change is reversible in one command.

*Cost (0.25 vCPU, 1 GB per task = $0.014565 per hour):*

<table>
<tr><th>Item</th><th>Derivation</th><th>Cost</th></tr>
<tr><td>Floor of 4 for three weeks</td><td>2 × 24 h × 21 days = 1,008 task hours</td><td>$14.68</td></tr>
<tr><td>Cohort mornings</td><td>76 × 2 h × 3 days = 456 task hours</td><td>$6.64</td></tr>
<tr><td>CloudWatch</td><td>5 alarms × $0.10 + 1 custom metric × $0.30</td><td>$0.80</td></tr>
<tr><td><b>Total</b></td><td>(excludes load balancer charges)</td><td><b>about $22.12</b></td></tr>
</table>

*Needed from the project lead:* the exact cohort dates and times; approval for a Fargate quota increase and the budget; and a load test showing how many requests one task can serve, the measurement nobody has taken.

*Tidy up:* each deletion is reversible in one command and affects no later lab. The low alarm went first (it names its policy), then the scale in policy, then the memory policy; three policies and four alarms remained and verification stayed 39/3.

**Exercise 5:** The history script exports the target, policies, alarms (also found through their actions), scheduled actions and activities as one JSON document (7,961 bytes). Latency was not observed because the floor is not enforced, so the figure of about 20 to 60 seconds per Fargate task was cited instead. Two exports were added (24 total). The readiness file records the task role, the bucket ARN read from the policy, and head bucket failing with exit 254 (404); after Lab 10 creates the bucket it returns 0. The policy also grants DeleteBucket, broader than a task needs.

### 7.6 Review questions

1. The nine lines run from a student clicking Register, through a metric rising, an alarm firing, a policy setting desired, ECS starting a task, the task getting a private address, the security group admitting it, the service registering it, to the load balancer sending it traffic. This lab owns three: the metric, the alarm and the policy. The other six needed no change because they already worked on a count rather than on particular tasks. Auto scaling changes who sets the task count, not how the application runs.

2. The resource ID is a short constructed name, not an ARN, so one format works across many services: service/cluster/service for ECS, table/name for DynamoDB, function:name:alias for Lambda. The other identifiers are the cluster and service names, the full service ARN for tagging, and the ResourceLabel built from the load balancer and target group ARNs.

3. The scalable target makes the change by enforcing its floor, while a policy acts only on an alarm. At night an engineer might raise the floor to survive an incident and forget it; the next person finds only a higher floor and bill unless it was written down.

4. Managed alarms belong to the policy and are changed or removed with it; my custom alarm belongs to me, can be shaped freely, and deleting it silently stops the policy. Breaching is better for queue depth because missing data means the application stopped publishing; the risk is scaling to the ceiling during a long outage of the metric.

5. Alarm evaluation, policy, task start and grace period add up to about five minutes, so the floor is a latency decision (floor 2), scale out should be fast and scale in slow (60 and 300), and known peaks need scheduled scaling.

6. Scale out follows whichever policy asks for more; scale in needs both to agree, because scaling in too early causes outages. Two policies on one metric fight each other, and a step policy plus target tracking on one metric is the same mistake.

7. Requests per target measures the real work, means the same at any task size, and rises immediately. CPU is better for CPU heavy work with very uneven request cost, such as PDF rendering. Requests per target would mislead if requests varied hugely in cost or the database was the bottleneck; TargetResponseTime would have shown that.

## 8. Reflection

1. **What I learned:** Auto scaling changes one number; the delays matter more than the thresholds; and suspensions or raised floors stay invisible unless checked.
2. **Challenges:** much of the service was unsupported on Floci, so I had to probe each operation and prove the wiring instead of the behaviour, and fix several bugs in the lab commands.
3. **Real world application:** target tracking on requests for normal load, scheduled actions before known peaks, and scale in suspension during deployments, with targets chosen from a load test.
4. **Further exploration:** load testing, predictive scaling for EC2, and the Kubernetes Horizontal Pod Autoscaler.

## 9. Conclusion

The objectives were largely achieved. The enrolment service has a scalable target with CPU, request and step scaling policies and suspension controls, all proven to persist. Scheduled scaling was unsupported on Floci and the alarm loop could not run, so the scaling was proven through its wiring; verification passed 39 of 42 checks, all three failures from scheduled actions.

I learned why reactive scaling always lags a spike, why the floor is a latency decision and why scheduled scaling is needed for predictable peaks. I also developed skills in configuring auto scaling from the CLI and in honestly separating what was observed from what was only configured. Auto scaling keeps applications available under changing load while controlling cost.

Sources: [AWS Fargate pricing](https://aws.amazon.com/fargate/pricing/), [Amazon CloudWatch pricing](https://cloudburn.io/blog/amazon%2Dcloudwatch%2Dpricing), [Fargate default vCPU quota](https://cloudburn.io/blog/aws%2Dfargate%2Dpricing), [AWS re:Invent 2023 CON307](https://d1.awsstatic.com/events/Summits/reinvent2023/CON307_Reducing%2DAWS%2DFargate%2Dstartup%2Dtimes%2Dby%2Dlazy%2Dloading%2Dcontainer%2Dimages.pdf), [VPC subnet reserved addresses](https://notes.kodekloud.com/docs/AWS%2DSolutions%2DArchitect%2DAssociate%2DCertification/Services%2DNetworking/Subnets/page).