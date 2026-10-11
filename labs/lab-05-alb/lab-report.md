# Lab 05: ECS Service Behind an Application Load Balancer

## 1. Aim / Objective

To place the USMS enrolment ECS Fargate service behind an Application Load Balancer (ALB) using the AWS CLI on Floci, so that clients reach the service through one stable DNS name, and to restrict task access so that only the load balancer can reach the tasks.

## 2. Introduction

Elastic Load Balancing (ELB) distributes incoming traffic across multiple targets such as EC2 instances, IP addresses or containers. An Application Load Balancer works at layer 7 (HTTP/HTTPS), so it can route requests based on path, host or headers. Its main features are listeners, listener rules, target groups and health checks, which keep traffic away from unhealthy targets. In cloud computing it provides high availability, fault tolerance across Availability Zones, and a stable entry point in front of resources whose addresses keep changing. It is typically used for web applications, APIs and microservices.

## 3. Use Case

1. Giving containerised services (ECS/Fargate) a single, stable DNS name.
2. Routing different URL paths (for example `/enrolment` and `/results`) to different services from one hostname.
3. Achieving zero downtime deployments through health checks and connection draining.
4. Spreading traffic across multiple Availability Zones for high availability.

## 4. System Architecture / Design

```
              Internet (client / usms web server)
                           │
                       Internet Gateway
                           │
 ┌──────────────────── usms vpc 10.0.0.0/16 ────────────────────┐
 │  Public subnet a (1a)              Public subnet b (1b)       │
 │  [ALB node]                        [ALB node]                 │
 │        └─────── usms enrolment ALB ───────┘                   │
 │                 Listener HTTP:80                              │
 │                  ├ Rule priority 10: /alb_health → 200        │
 │                  └ Default: forward → enrolment target group  │
 │                          (target type ip, GET / health check) │
 │                 tcp/80 allowed only from the ALB security group│
 │  Private subnet a (1a)             Private subnet b (1b)      │
 │  [Fargate task 1]                  [Fargate task 2]           │
 │                                                               │
 │  ECS cluster → enrolment service (desired count 2)            │
 │  The service registers and deregisters its own task IPs       │
 └───────────────────────────────────────────────────────────────┘
```

**Data flow:** Client → ALB (public subnets) → listener → rule or default action → target group → Fargate tasks (private subnets).

## 5. Implementation Procedure

1. Started Floci, loaded the env files from Labs 01 to 04, and confirmed the earlier labs passed their verification scripts.
2. Probed which ELBv2 features the Floci build supports and recorded the support path.
3. Created a security group for the load balancer allowing tcp/80 from `0.0.0.0/0`.
4. Created an internet facing ALB across two public subnets in two Availability Zones.
5. Created the target group (type `ip`, HTTP:80, health check `GET /` every 30 seconds).
6. Set a 30 second deregistration delay and the least outstanding requests algorithm.
7. Created an HTTP:80 listener whose default action forwards to the target group.
8. Allowed tcp/80 from the ALB security group into the enrolment security group.
9. Attached the enrolment service to the target group with a 60 second health check grace period.
10. Checked that the service registered its task IPs into the target group automatically.
11. Verified the request path using curl and a control plane proof.
12. Cutover: removed the old rule that let the web tier reach the tasks directly.
13. Forced a new deployment and observed the target states (initial → healthy → draining).
14. Added a listener rule at priority 10 that returns a fixed 200 response for the ALB health path.
15. Restarted Floci and confirmed all configuration persisted.
16. Saved the Lab 05 env file, created the verification and cleanup scripts, and committed to Git.

## 6. Results and Evidence

### 6.1 CLI / SDK Output

*Insert screenshot(s) here:*

1. ALB creation and `describe-load-balancers` output
2. Target group and `describe-target-health` showing the task IPs
3. `describe-rules` showing the priority 10 rule and the default action
4. Verification script result (`PASS=49 FAIL=0`)
5. `PERSISTENCE PROVEN` and `CUTOVER CONFIRMED` lines

### 6.2 AWS Management Console Verification

Not applicable. The lab was performed on Floci (a local AWS emulator), which has no Management Console. All verification was done through AWS CLI output (Section 6.1).

## 7. Analysis and Discussion

**What was achieved:** The enrolment service is now load balanced behind one ALB, and only the ALB can reach the tasks.

**Expected outcome:** The control plane results matched the expected outcome. The ALB, listener, rule, target group and service attachment were all created and persisted after a restart. The data path (an actual HTTP 200 via curl) depends on the Floci build: *[state whether you got a 200 or used the control plane proof]*.

**Errors and resolution:** After the cutover, the Lab 04 verification script reported one failure, because it still expected the web tier security group as the source. This was expected, since the architecture had changed, and it was documented. Some ELB features, such as health checks actually running, are not emulated by Floci.

**Observations:** The ECS service registers and deregisters targets by itself, so manual registration is never needed. Fargate target groups must use target type `ip`. The container health check and the target group health check are different and can disagree.

## 8. Reflection

1. **What I learned:** An ALB is made of four objects: load balancer, listener, rule and target group. The health check belongs to the target group, and ECS keeps the target list up to date automatically.
2. **Challenges:** Keeping the four ELB objects separate, using the correct heredoc quoting for JSON files, and understanding Floci's limitations on the data path.
3. **Real world application:** I would use an ALB in front of any containerised web API to get a stable endpoint, zero downtime deployments, and path based routing to multiple services.
4. **Further exploration:** HTTPS listeners with ACM certificates, auto scaling on `ALBRequestCountPerTarget` (Lab 06), and internal versus internet facing load balancers.

## 9. Conclusion

The objectives of this practical were achieved. An internet facing Application Load Balancer was deployed across two Availability Zones in front of the ECS Fargate enrolment service. The service now registers its own tasks into the target group, and the security groups were cut over so that only the load balancer can reach the tasks.

Through this lab I gained practical skills in creating and configuring ELBv2 resources with the AWS CLI, reading target health, performing a safe security cutover, and verifying persistence. Load balancers are a core part of cloud architecture: they provide scalability, high availability and a stable entry point for applications.