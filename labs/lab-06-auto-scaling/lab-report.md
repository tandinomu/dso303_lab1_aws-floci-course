# Lab 06: Implementing Auto Scaling for an ECS Based Application

## 1. Aim / Objective

To configure Application Auto Scaling for the USMS enrolment ECS service using the AWS CLI on Floci, so that the number of running tasks changes automatically based on CPU usage, request count, a custom queue metric and a schedule, within a floor of 2 and a ceiling of 10 tasks.

## 2. Introduction

Application Auto Scaling is an AWS service that automatically adjusts the capacity of scalable resources such as ECS services, DynamoDB tables and Lambda concurrency. For an ECS service it changes only one value: the desired task count. Its key features are scalable targets (which set the minimum and maximum capacity), target tracking policies (which keep a metric near a chosen value), step scaling policies (which add capacity in steps based on how far a CloudWatch alarm is breached), and scheduled actions (which change capacity at set times). It is important in cloud computing because it matches capacity to demand, improving availability during busy periods and reducing cost during quiet ones. It is typically used for web applications, APIs and background workers with changing traffic.

## 3. Use Case

1. Adding ECS tasks automatically when CPU usage or request traffic rises.
2. Scaling a worker service based on the depth of a work queue.
3. Raising capacity before a known busy period, such as university enrolment week.
4. Reducing tasks during quiet hours to save cost.

## 4. System Architecture / Design

```
  CloudWatch metrics                           Application Auto Scaling
  ┌──────────────────────────────┐            ┌────────────────────────────────────┐
  │ CPU utilisation (ECS)        │──alarms──→ │ Target tracking policy: CPU 50%    │
  │ Requests per target (ALB)    │──alarms──→ │ Target tracking policy: 1000/min   │
  │ Custom queue depth metric    │──alarm───→ │ Step scaling policy: +1 / +3 tasks │
  └──────────────────────────────┘            │ Scheduled: 07:45 min 4, 20:00 min 2│
                                              │ Scalable target: min 2, max 10     │
                                              └────────────────┬───────────────────┘
                                                               │ writes ONE number
                                                               ↓
                                              ECS service: desired task count
                                                               │
                                                               ↓
                              ECS starts or stops Fargate tasks in the private subnets
                                                               │
                                                               ↓
                     Service registers new task IPs in the ALB target group → traffic
```

**Data flow:** Metric → CloudWatch alarm → scaling policy → desired count on the ECS service → ECS starts tasks → tasks are registered in the target group → the load balancer sends them traffic.

## 5. Implementation Procedure

1. Started Floci, loaded the env files from Labs 01 to 05, and confirmed the service was at its baseline of 2 tasks.
2. Probed which Application Auto Scaling and CloudWatch features the Floci build supports.
3. Created the service linked role that Application Auto Scaling uses to update the ECS service.
4. Built the resource ID from the service ARN and registered the scalable target with a minimum of 2 and a maximum of 10.
5. Re-registered the target to raise the ceiling to 12, then set it back to 10, to learn how updates work.
6. Created a CPU target tracking policy with a target of 50%, a scale out cooldown of 60 seconds and a scale in cooldown of 300 seconds.
7. Inspected the two CloudWatch alarms that target tracking created automatically.
8. Built the ResourceLabel from the ALB and target group ARNs and created a request count target tracking policy with a target of 1000 requests per target.
9. Published a custom queue depth metric, created a step scaling policy (+1 task and +3 tasks), and created an alarm that triggers it at a value of 100.
10. Created two scheduled actions on weekdays in the Asia/Thimphu time zone: raise the floor to 4 at 07:45 and lower it to 2 at 20:00.
11. Pushed the queue metric to 260 (forcing the alarm state where needed) and checked whether the desired count changed and what the scaling activity recorded.
12. Returned the metric and the service to the baseline.
13. Suspended scale in, confirmed the policies were unchanged, then resumed all scaling.
14. Restarted Floci and confirmed the whole scaling configuration persisted.
15. Traced the full chain from a request to a new serving task.
16. Saved the Lab 06 env file, built the verification and cleanup scripts, and committed to Git.

## 6. Results and Evidence

### 6.1 CLI / SDK Output

*Insert screenshot(s) here:*

1. Scalable target output showing min 2, max 10 and the role filled in by AWS
2. The two managed target tracking alarms
3. Scaling policies list showing the CPU, request count and step policies
4. Scheduled actions list
5. Scaling activity with its cause string, or the fallback proof file
6. Suspended state output, while suspended and after resuming
7. `PERSISTENCE PROVEN` line
8. Verification script result (`PASS=42 FAIL=0`)

### 6.2 AWS Management Console Verification

Not applicable. The lab was performed on Floci (a local AWS emulator), which has no Management Console. All verification was done through AWS CLI output (Section 6.1).

## 7. Analysis and Discussion

**What was achieved:** The enrolment service now has a scalable target, two target tracking policies, one step scaling policy with its own alarm, and two scheduled actions. The task definition, service and load balancer were not changed.

**Expected outcome:** The configuration matched the expected outcome and persisted after a restart. Whether the desired count actually moved on its own depends on the Floci build: *[state whether you saw the count change from 2 to 5 with a cause string, or used the fallback proof]*.

**Errors and resolution:**

1. Some Floci builds do not run the full alarm to policy loop. Where the alarm did not fire, its state was forced, or the configuration chain was proven step by step instead.
2. After the scaling test, the metric was lowered first and the count was then reset to 2, so that the policy would not scale out again.
3. The step that repairs the cleanup script hints needed care, because a blind find and replace also changes lines that correctly refer to the Lab 04 cleanup script.

**Observations:**

1. Auto scaling only changes the desired count; ECS and the load balancer do the rest.
2. Target tracking silently creates and owns two alarms.
3. Step scaling bounds are measured relative to the alarm threshold.
4. A suspension gives no warning and must be checked deliberately.

## 8. Reflection

1. **What I learned:** Application Auto Scaling works through scalable targets, policies and scheduled actions, and CloudWatch alarms make the actual decisions. Requests per target is a better signal than CPU for a web API.
2. **Challenges:** Building the resource ID and the ResourceLabel correctly, understanding the step scaling bounds, and getting the time zone right for the cron schedules.
3. **Real world application:** I would use target tracking for normal traffic and scheduled scaling for known peaks, such as enrolment week. I would also keep a suspension runbook ready for incidents.
4. **Further exploration:** Load testing to choose real target values, scaling on memory, and comparing this with the Kubernetes HorizontalPodAutoscaler in Lab 07.

## 9. Conclusion

The objectives of this practical were achieved. Application Auto Scaling was configured on the ECS enrolment service with a floor of 2 and a ceiling of 10. Target tracking, step scaling and scheduled scaling were each set up, tested and shown to persist, and none of the underlying ECS or load balancer resources had to be modified.

Through this lab I learned how reactive scaling responds to metrics through alarms, why it always reacts with a delay, and why scheduled scaling is needed for predictable peaks. Auto scaling is essential in the cloud because it keeps applications available under changing load while controlling cost.