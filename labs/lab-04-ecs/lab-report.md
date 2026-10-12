# Lab 04: Amazon ECS and the USMS Enrolment Service

## 1. Aim / Objective

To run the USMS enrolment service on Amazon ECS with Fargate, using a cluster, a log group, two IAM roles, a security group, a task definition and a service with two tasks in the private subnets from Lab 02.

## 2. Introduction

Amazon ECS runs containers. It has four parts: a **cluster** (a group), a **task definition** (a blueprint that cannot be edited, only replaced by a new revision), a **task** (one running copy), and a **service** (keeps the right number of tasks running). With **Fargate**, AWS provides the servers, but each task still gets its own private IP and security group in the VPC. ECS makes applications self healing and easy to scale.

## 3. Use Case

1. Running APIs such as the USMS enrolment service.
2. Adding tasks for busy periods like enrolment week.
3. Releasing new versions by moving a service to a new revision.

## 4. System Architecture / Design


Only the web server can reach the tasks. The tasks have no public IP and pull images through the NAT gateway.

## 5. Implementation Procedure

1. **Resumed the environment** and loaded the env files from Labs 01 to 03.
2. **Checked Labs 02 and 03** with their verification scripts.
3. **Probed Floci support** for ECS, auto scaling and CloudWatch.
4. **Created the cluster** `usms-ecs-cluster` as the developer role.
5. **Created the log group** `/usms/ecs/enrolment` with 7 day retention.
6. **Created the execution role** `usms-ecs-exec-role`.
7. **Created the task role** `usms-ecs-task-role` with Lab 01's S3 policy.
8. **Created the security group** `usms-enrolment-sg`, allowing port 80 only from the web tier.
9. **Registered the task definition** `usms-enrolment:1`.
10. **Created the service** `usms-enrolment-svc` with 2 tasks.
11. **Checked the service**, and scaled it 2 to 3 to 2 by hand (Your turn).
12. **Saved outputs** to `configs/lab-04.env`.
13. **Committed** the lab files.

**Exercises:** (1) created a second service, (2) moved the service to a new revision, (3) wrote an inventory script, (4) planned enrolment week capacity and deleted the second service, (5) linked the security group back to Lab 03.

## 6. Results and Evidence

### 6.1 CLI Output

**Step 1: Environment loaded**
![1](../../screenshots/lab-04/1.png)

**Step 2: Earlier labs verified**
![2](../../screenshots/lab-04/2.png)

**Step 3: Floci support probe**
![3](../../screenshots/lab-04/3.png)
![3.2](../../screenshots/lab-04/3.2.png)

**Step 4: Cluster created**
![4.1](../../screenshots/lab-04/4.1.png)
![4.2](../../screenshots/lab-04/4.2.png)
![4.3](../../screenshots/lab-04/4.3.png)
![4.4](../../screenshots/lab-04/4.4.png)

**Step 5: Log group**
![5](../../screenshots/lab-04/5.png)

**Step 6: Execution role**
![6.1](../../screenshots/lab-04/6.1.png)
![6.2](../../screenshots/lab-04/6.2.png)
![6.3](../../screenshots/lab-04/6.3.png)

**Step 7: Task role**
![7](../../screenshots/lab-04/7.png)

**Step 8: Security group**
![8](../../screenshots/lab-04/8.png)

**Step 9: Task definition**
![9.1](../../screenshots/lab-04/9.1.png)
![9.2](../../screenshots/lab-04/9.2.png)

**Step 10: Service created**
![10](../../screenshots/lab-04/10.png)

**Step 11: Service counts**
![11](../../screenshots/lab-04/11.png)

**Step 11: Your turn, scaling by hand**
![11 your turn 1](<../../screenshots/lab-04/11(myturn)-1.png>)
![11 your turn 2](<../../screenshots/lab-04/11(myturn)-2.png>)

**Step 12: Env file**
![12](../../screenshots/lab-04/12.png)

**Step 13: Commit**
![13.1](../../screenshots/lab-04/13.1.png)
![13](../../screenshots/lab-04/13.png)

**Verification script**
![verify](../../screenshots/lab-04/verify.png)
![verify 2](../../screenshots/lab-04/verify-2.png)

**Cleanup script (not run)**
![cleanup](../../screenshots/lab-04/cleanup.png)

### 6.2 Exercises

**Exercise 1: Second service**
![ex1 create](../../screenshots/lab-04/ex1-create.png)
![ex1 verify](../../screenshots/lab-04/ex1-verify.png)

**Exercise 2: Revision 2**
![ex2 diff](../../screenshots/lab-04/ex2-diff.png)
![ex2 update](../../screenshots/lab-04/ex2-update.png)
![ex2 revisions](../../screenshots/lab-04/ex2-revisions.png)

**Exercise 3: Inventory report**
![ex3](../../screenshots/lab-04/ex3.png)

**Exercise 4: Second service deleted**
![ex4 delete](../../screenshots/lab-04/ex4-delete.png)
![ex4 verify](../../screenshots/lab-04/ex4-verify.png)

**Exercise 5: Link to Lab 03**
![ex5 lookup](../../screenshots/lab-04/ex5-lookup.png)
![ex5 linkage](../../screenshots/lab-04/ex5-linkage.png)

### 6.3 AWS Management Console Verification

Floci has no AWS Console, so all resources were checked with AWS CLI `describe` commands.

## 7. Analysis and Discussion

**Results.** Everything was built and verified. Floci ran the containers: the inventory showed `running=2`. The verification script reported `PASS=37 FAIL=1`. The one failure is a false positive: Git tracks only the empty file `outputs/.gitkeep`, which the course commits on purpose, and no secrets are tracked.

**Floci support.** Path A: ECS and auto scaling work, but scheduled scaling does not. The probe showed `describe-services` as not available only because the test cluster does not exist.

**Errors fixed.**
1. **Step 7:** attaching the S3 policy failed because `USMS_POLICY_S3_RW` already held the full ARN, so the prefix was added twice. The variable was used directly.
2. **Step 13:** the verify and cleanup scripts had to be created before committing.

**Floci limitations.**
1. Scheduled scaling actions are not supported.
2. A service created with only a family name shows `usms-enrolment` instead of a revision number.
3. The security group filter in Exercise 5 also returned the database servers, which use a different group.

**Exercise answers.**
1. **Exercise 2:** the service's `taskDefinition` changed from `:1` to `:2`, but revision 1 stayed the same and `ACTIVE`, because revisions cannot be edited.
2. **Exercise 3:** `set -e` is not used, so one service with missing data does not stop the whole report.
3. **Exercise 5:** the security group rule traces back to `usms-web-01`, which matches `lab-03.env`, so the verdict is **LOOP CLOSED**. This rule is temporary, because Lab 05 replaces it with the load balancer.

**Exercise 4: Enrolment week plan.** A fixed count of 2 cannot handle the 08:00 rush, because nothing changes it except a person. Assuming a peak of 250 requests per second and 25 per task:

| Setting | Value | Reason |
|---|---|---|
| Minimum | 2 | One task per Availability Zone |
| Maximum | 12 | 250 ÷ 25 = 10, plus 2 spare |
| Scheduled floor | 10, Monday 07:45 to 09:00 | Tasks must be running before the rush |

Cost per task is about $10.63 per month (Fargate: $0.0405 per vCPU-hour and $0.00445 per GB-hour). The options compare like this:

| Option | Monthly cost |
|---|---|
| Fixed at 2 tasks | $21.27 |
| Fixed at 12 tasks | $127.59 |
| Proposed plan | about $21.85 |

The plan costs almost the same as today but covers the peak. Deleted: `usms-results-svc`, scaled to 0 and then removed, with verification unchanged.

## 8. Reflection

**1. What was learned about this AWS service?** ECS has four separate parts, and scaling only changes a service's desired count. The execution role starts the task, and the task role is what the app runs as.

**2. What challenges were encountered?** Telling the two roles apart, the network and tag syntax, and the doubled ARN in Step 7.

**3. How would this service be applied in a real world cloud environment?** Run APIs as Fargate services in private subnets behind a load balancer, with auto scaling for busy times.

**4. What additional concepts or features warrant further exploration?** Load balancers (Lab 05), auto scaling (Lab 06) and Fargate Spot.

## 9. Conclusion

The USMS enrolment service now runs on ECS with Fargate, in two private subnets and reachable only from the web tier. All steps and five exercises were completed, so the objectives were met. The key lesson is that a service keeps a fixed number of tasks running, and auto scaling in Lab 06 is what will let it react to demand.

## 10. Appendix

### Review Questions

**1. A colleague says "I put auto scaling on the task definition." Explain, in three or four sentences, every way that sentence is wrong: name what auto scaling will actually be attached to in Lab 06, what it actually modifies, and which of ECS's four objects does the work of making reality match. Then say what observable consequence follows from the fact that ECS itself will know nothing about the scalable target.**

Auto scaling is not attached to the task definition, which is an immutable blueprint that never changes. In Lab 06 it is attached to the **service** (`usms-enrolment-svc`), registered as a scalable target. It only changes one number, the service's `desiredCount`. The **service** then does the real work, starting or stopping tasks until the running count matches. Because ECS knows nothing about the scalable target, `describe-services` shows no scaling settings at all; the only visible sign is the desired count changing, and the scaling settings can only be seen through the Application Auto Scaling commands.

**2. Lab 1 wrote USMSStudentDataReadWrite for a bucket that did not exist. Lab 3 attached it to an EC2 instance via an instance profile. This lab attached the same policy, unchanged, to a Fargate task via a task role. Explain in a full paragraph what each of the two delivery mechanisms actually does at runtime, why neither needs a key on disk, and precisely what changes for both the moment a bucket finally exists at that ARN. This is the most important connection in the course; answer it properly.**

On EC2, the instance profile places `usms-ec2-app-role` on the instance, and the instance metadata service hands short lived credentials for that role to any program on the server. On Fargate, the task role `usms-ecs-task-role` is given to the container, and ECS provides short lived credentials to the application through an endpoint inside the task. In both cases AWS creates the credentials and replaces them automatically before they expire, so no access key is ever written to disk or stored in code. The same policy is attached to both roles without change, because a policy refers to the bucket's ARN, not to an existing bucket. Today that permission does nothing, since nothing exists at `arn:aws:s3:::usms-student-data`. The moment the bucket is created at that ARN, both the web server and the enrolment tasks can read and write it immediately, with no change to either role, the policy, the instance or the task definition.

**3. The interlude before Step 6 distinguishes the task execution role from the task role. Give a one-sentence failure symptom for each that a colleague could use to tell them apart without reading any documentation, and explain why both roles share an identical trust policy despite doing completely different jobs.**

If the **execution role** is wrong, the task never starts, and the stop reason mentions pulling the image or creating the log stream. If the **task role** is wrong, the task starts normally, but the application gets `AccessDenied` when it calls S3. Both trust `ecs-tasks.amazonaws.com` because the same ECS service assumes both of them; the difference is not who uses them, but when and for what: one before the container starts, the other while the application runs.

**4. Step 8 sources the enrolment security group's only inbound rule from usms-app-sg, not from a CIDR block. Explain why this choice would still be correct even if this service's task count never changed, and then explain the additional reason it becomes close to mandatory once Lab 06 lets the task count change on its own.**

Even with a fixed count, a group reference is more precise: it allows only servers carrying `usms-app-sg`, not every address in a subnet range, and it keeps working if the web server is replaced and gets a new IP, as happened in Lab 03. Once Lab 06 adds auto scaling, tasks will be created and removed automatically with new IPs each time, so a rule based on IP addresses would be out of date within minutes. A group reference needs no updating, because it follows whatever carries the group.

**5. Explain what Fargate removes from the EC2 model this course used in Lab 3, and what it explicitly does not remove. Use the fact that a Fargate task in awsvpc mode still has its own security group and still obeys Lab 2's route tables to make the second half of the answer concrete.**

Fargate removes the servers: there are no instances to choose, patch, scale or log in to, no AMIs or key pairs, and payment is per task. It does not remove the network. Each task gets its own network interface in a Lab 02 subnet, protected by its own security group (`usms-enrolment-sg`), and it follows the private route table. That is why the tasks needed the Lab 02 NAT gateway to pull their image; without it, they would fail to start.

**6. Lab 1 Step 14 proved that "the account identity is unchanged after a restart" is not evidence of persistence, because the root ARN is a constant regardless of storage mode. Apply the same scepticism here: name one command against this lab's own resources that would look identical whether Floci is running in memory mode or hybrid mode, and one command that would not, and explain the difference.**

`aws ecs list-clusters` run straight after creating the cluster looks the same in both modes, because the cluster exists in memory until Floci stops. After a Floci restart, `aws ecs describe-services --cluster usms-ecs-cluster --services usms-enrolment-svc` is different: in hybrid mode it still returns the service with a desired count of 2, but in memory mode the cluster is gone and the command fails. Only a check made after a restart proves that data was actually saved.

### Files

1. `templates/lab-04-taskdef.json`, `lab-04-taskdef-rev1.json`, `lab-04-taskdef-rev2.json`
2. `policies/trust-ecs-tasks.json`, `usms-ecs-task-execution-policy.json`, `usms-enrolment-sg-ingress.json`
3. `configs/lab-04.env`
4. `scripts/utilities/verify-lab-04.sh`, `lab-04-ecs-inventory.sh`
5. `scripts/cleanup/lab-04-cleanup.sh` (not run)
6. Pricing source: [AWS Fargate Pricing](https://aws.amazon.com/fargate/pricing/)