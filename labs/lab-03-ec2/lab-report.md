# Lab 03: Amazon EC2 and Deploying the USMS Application

**Course:** DSO303 | **Environment:** Floci (local AWS emulator), AWS CLI v2, macOS

## 1. Aim / Objective

To deploy the USMS application on Amazon EC2 as a two tier system: a web server in a public subnet and a database server in a private subnet. The lab also covers user data bootstrapping, an Elastic IP, an EBS data volume and a golden AMI, and verifies that each part is configured correctly.

## 2. Introduction

Amazon EC2 (Elastic Compute Cloud) provides virtual servers in the cloud. A server, called an instance, is built from an **AMI** (the disk template), an **instance type** (CPU and memory) and optional **user data** (a script that runs at first boot). EC2 works with key pairs for login, security groups as firewalls, Elastic IPs for fixed public addresses, EBS volumes for storage, and instance profiles for AWS permissions without stored keys. EC2 is the core compute service of AWS and the usual starting point for running applications in the cloud.

## 3. Use Case

1. Hosting websites and web applications, such as the USMS student portal.
2. Running multi tier systems, with public web servers in front of private database servers.
3. Running batch jobs and build servers on demand.
4. Creating golden AMIs so new servers can be launched already configured.

## 4. System Architecture / Design

Users reach the web server through the internet gateway on port 80. Only the web tier can reach the database on port 5432. The database servers have no public address and can only connect outward through the NAT gateway. The web server gets AWS permissions through its instance profile.

## 5. Implementation Procedure

### Main steps

1. **Resumed the environment:** started Floci and loaded the env files from Labs 01 and 02.
2. **Checked Lab 02:** ran `verify-lab-02.sh`, which reported `FAIL=0`.
3. **Chose an AMI:** captured an image ID from Floci's catalogue with `describe-images`.
4. **Created a key pair:** saved the private key straight to `outputs/usms-app-key.pem` with permissions `600`.
5. **Checked Git ignore:** confirmed the private key file is excluded from Git.
6. **Wrote the user data script:** `user-data.sh` installs nginx and creates the portal page.
7. **Built a launch template:** generated a JSON request file for `run-instances`.
8. **Launched `usms-web-01`:** in the public subnet with `usms-app-sg` and `usms-ec2-app-profile`.
9. **Waited for running:** used `aws ec2 wait instance-running`.
10. **Read the instance back:** checked its subnet, IPs, security group and profile.
11. **Traced permissions:** followed instance → profile → role → policy.
12. **Checked user data:** read the stored user data back and compared it with the original.
13. **Added an Elastic IP:** allocated `usms-web-eip` and attached it to the web server.
14. **Tested the application:** ran `curl` and six configuration checks.
15. **Added a data volume:** created an 8 GiB gp3 volume in the same AZ and attached it.
16. **Launched `usms-db-01`:** in the private subnet with `usms-db-sg` and no profile.
17. **Checked tier wiring:** confirmed the database only accepts port 5432 from the web tier.
18. **Stop and start test:** stopped and started the web server to see which addresses stay the same.
19. **Persistence test:** restarted Floci and confirmed all instances were still there.
20. **Created a golden AMI:** made `usms-web-golden` from the web server.
21. **Audited resources:** listed all USMS instances, volumes, Elastic IPs and images.
22. **Saved outputs:** wrote `configs/lab-03.env`.
23. **Committed:** committed and pushed the lab files to GitHub.

### Your turn tasks

1. **Step 15:** tried attaching a volume from a different AZ, to test the AZ rule.
2. **Step 18:** launched `usms-web-02` in the second Availability Zone.
3. **Step 21:** created an exposure report listing instances without a public IP first.

### Exercises

1. **Exercise 1:** launched a temporary admin instance, `usms-admin-01-host`.
2. **Exercise 2:** wrote a database bootstrap script and launched `usms-db-02` with it.
3. **Exercise 3:** wrote a script that labels each instance REACHABLE or UNREACHABLE.
4. **Exercise 4:** analysed right sizing and cost, then deleted the admin instance.
5. **Exercise 5:** wrote an S3 upload script and a readiness file for the future S3 bucket.

## 6. Results and Evidence

### 6.1 CLI Output

**Step 1: Environment loaded**
![Step 1](../../screenshots/lab-03/1.png)

**Step 2: Lab 02 verified**
![Step 2](../../screenshots/lab-03/2.png)

**Step 3: AMI selected**
![Step 3.1](../../screenshots/lab-03/3.1.png)
![Step 3.2](../../screenshots/lab-03/3.2.png)

**Step 4: Key pair created**
![Step 4](../../screenshots/lab-03/4.png)

The owner shows as `macbookairm4chip staff` instead of `student student` because of macOS defaults. The permissions are correct.

**Step 5: Private key ignored by Git**
![Step 5](../../screenshots/lab-03/5.png)

**Step 6: User data script written**
![Step 6](../../screenshots/lab-03/6.png)

**Step 7: Launch template created**
![Step 7.1](../../screenshots/lab-03/7.1.png)
![Step 7.2](../../screenshots/lab-03/7.2.png)

**Step 8: Web server launched**
![Step 8](../../screenshots/lab-03/8.png)

**Step 9: Instance running**
![Step 9](../../screenshots/lab-03/9.png)

**Step 10: Instance details**
![Step 10](../../screenshots/lab-03/10.png)

**Step 11: Permission chain**
![Step 11](../../screenshots/lab-03/11.png)

**Step 12: User data check**
![Step 12](../../screenshots/lab-03/12.png)

**Step 13: Elastic IP attached**
![Step 13](../../screenshots/lab-03/13.png)

**Step 14: Application test and configuration checks**
![Step 14.1](../../screenshots/lab-03/14.1.png)
![Step 14.2](../../screenshots/lab-03/14.2.png)

**Step 15: Data volume attached**
![Step 15](../../screenshots/lab-03/15.png)
![Step 15.2](../../screenshots/lab-03/15.2.png)

**Step 15: Your turn, AZ test**
![Step 15 your turn](<../../screenshots/lab-03/15(myturn).png>)
![Step 15 your turn cleanup](<../../screenshots/lab-03/15(myturn)-cleanup.png>)

The attach was rejected because the volume and instance were in different AZs. The test volume was then deleted.

**Step 16: Database server launched**
![Step 16](../../screenshots/lab-03/16.png)

**Step 17: Tier wiring checked**
![Step 17](../../screenshots/lab-03/17.png)

**Step 18: Stop and start test**
![Step 18](../../screenshots/lab-03/18.png)

**Step 18: Your turn, second web server**
![Step 18 your turn](<../../screenshots/lab-03/18(myturn).png>)

**Step 19: Persistence proven**
![Step 19](../../screenshots/lab-03/19.png)

**Step 20: Golden AMI created**
![Step 20](../../screenshots/lab-03/20.png)

**Step 21: Resource audit**
![Step 21](../../screenshots/lab-03/21.png)

**Step 21: Your turn, exposure report**
![Step 21 your turn](<../../screenshots/lab-03/21(myturn).png>)

**Step 22: Env file written**
![Step 22](../../screenshots/lab-03/22.png)

**Step 23: Committed and pushed**
![Step 23](../../screenshots/lab-03/23.png)

### 6.2 Exercises

**Exercise 1: Admin instance**
![Exercise 1](../../screenshots/lab-03/ex1.png)

**Exercise 2: Database bootstrap**
![Exercise 2 script](../../screenshots/lab-03/ex2-script.png)
![Exercise 2 launch](../../screenshots/lab-03/ex2-launch.png)
![Exercise 2 read back](../../screenshots/lab-03/ex2-readback.png)

**Exercise 3: Reachability report**
![Exercise 3](../../screenshots/lab-03/ex3.png)

**Exercise 4: Cleanup**
![Exercise 4 credits](../../screenshots/lab-03/ex4-credits.png)
![Exercise 4 orphans](../../screenshots/lab-03/ex4-orphans.png)
![Exercise 4 terminate](../../screenshots/lab-03/ex4-terminate.png)
![Exercise 4 verify](../../screenshots/lab-03/ex4-verify.png)

**Exercise 5: S3 handoff**
![Exercise 5 script](../../screenshots/lab-03/ex5-script.png)
![Exercise 5 egress](../../screenshots/lab-03/ex5-egress.png)
![Exercise 5 readiness](../../screenshots/lab-03/ex5-readiness.png)
![Exercise 5 bucket variable](../../screenshots/lab-03/ex5-bucket-env.png)

### 6.3 AWS Management Console Verification

Floci runs locally and has no AWS Console. All resources were checked with AWS CLI `describe` commands, which show the same information as the console.

## 7. Analysis and Discussion

**What was achieved.** The two tier setup was built and verified. The verification script reported `PASS=36 FAIL=0`. The web server has the correct subnet, security group, instance profile, Elastic IP and data volume. The database servers are private and accept connections only from the web tier. All instances survived a Floci restart.

**Key idea.** The S3 policy from Lab 01 names a bucket that does not exist yet. This is allowed, because a policy refers to a name (ARN), not to an existing resource. Once the bucket is created, the web server can use it straight away, without any change.

**Errors and how they were fixed.**

1. **User data not stored (Step 12):** the read back returned `None`. The launch command did include the script, so this is a Floci limitation. The same happened in Exercise 2.
2. **Instance terminated by mistake (Step 15):** the web server was terminated while troubleshooting Step 12, so attaching the volume failed. It was relaunched from the same template, and the Elastic IP and data volume were moved to the new instance. This showed that both survive independently of the instance.
3. **NAT address released by mistake:** an unattached Elastic IP was released as a "duplicate", but it belonged to the NAT gateway. Real AWS would have blocked this. `verify-lab-02.sh` still passed. The lesson is to check what a resource is attached to before deleting it.
4. **Missing scripts at commit (Step 23):** the verify and cleanup scripts had to be created before committing.

**Floci limitations observed.**

| Floci behaviour | Real AWS |
|---|---|
| User data not stored | User data stored and returned |
| No operating system, so `curl` fails | nginx serves the page |
| Root volumes and AMI not tagged | Tags applied at launch |
| Docker IPs shown (`172.20.0.x`, `127.0.0.1`) | IPs from the subnet; the EIP shown as public IP |
| Allowed releasing the NAT gateway's IP | Release is blocked |
| Credit specification not supported | Shows standard or unlimited mode |

**Exercise 4: Cost analysis** (`us-east-1`, 730 hours per month)

The `t3.micro` runs at 85% CPU at midday, far above its 10% baseline. By default, T3 runs in unlimited mode, which charges extra for this, estimated at about $3 per month for a four hour daily peak.

| Option | Monthly cost |
|---|---|
| A: 1 × t3.micro (today) | ~$14.24 (instance $7.59 + extra CPU ~$3.00 + public IP $3.65) |
| B: 1 × t3.small (scale up) | $18.83 (instance $15.18 + public IP $3.65) |
| C: 2 × t3.micro + load balancer (scale out) | ~$44.75 (instances $15.18 + ALB $22.27 + 2 public IPs $7.30) |

**Recommendation:** move to `t3.small` now. It costs about $4.60 more per month and removes the extra CPU charges. Option C is better in the long term for high availability, because it spans two AZs, but it costs more.

**Deleted:** `usms-admin-01-host` (Exercise 1). No orphaned volumes or unused Elastic IPs were found.

## 8. Reflection

**1. What was learned about this AWS service?**
An EC2 instance is made of separate parts that can each be checked. Instance profiles remove the need for access keys, and Elastic IPs and EBS volumes live on independently of the instance.

**2. What challenges were encountered?**
Telling apart real mistakes and Floci limitations, especially in Step 12. Recovering from the accidental termination taught the importance of checking a resource's state before acting on it.

**3. How would this service be applied in a real world cloud environment?**
Web servers would run in at least two AZs behind a load balancer, using instance profiles, separate data volumes, and AMIs built in advance.

**4. What additional concepts or features warrant further exploration?**
Auto Scaling groups, T3 CPU credits, EBS snapshots, and Systems Manager Session Manager instead of SSH.

## 9. Conclusion

This lab deployed the USMS application on EC2 as a two tier system. One `run-instances` call combined resources from Labs 01, 02 and 03. The web server received a fixed IP and a data volume, the database tier was placed in a private subnet, a golden AMI was created, and persistence was proven. The verification script passed all 36 checks, and all five exercises were completed, so the objectives were met.

The main lessons were the separate parts of an EC2 instance, the independent lifecycles of IPs and volumes, the AZ rule for EBS, and the habit of verifying results rather than trusting a command's success.

## 10. Appendix

### Review Questions

**1. What if a launch input was wrong?** A missing subnet, security group, profile or key fails immediately with an error. A wrong but valid one fails silently. For example, a private subnet means no public IP, the default security group blocks port 80, a missing profile causes `AccessDenied` later, and a missing key means no SSH. A broken user data script always fails silently at boot.

**2. Why is a policy for a missing bucket valid?** Policies refer to ARNs, not existing resources. The permission does nothing until the bucket exists, and then works immediately with no changes.

**3. Why can't user data redeploy on restart?** It runs only once, at first boot. Better options are a deployment tool, such as Systems Manager or CodeDeploy, or baking each release into a new AMI.

**4. Automatically assigned IP vs Elastic IP?** An automatically assigned IP belongs to AWS and changes on every stop and start. An Elastic IP belongs to the account and stays the same. Both cost $0.005 per hour. Because an Elastic IP can be moved, it can be switched to a standby server during a failover.

**5. Volumes vs snapshots?** A volume lives in one AZ, while a snapshot is stored regionally. To survive an AZ failure, use snapshots or replicate data to another AZ.

**6. Are the six checks enough?** They check all of the AWS configuration, but not problems inside the server, such as nginx not running or the app crashing.

**7. Differences between `usms-web-01` and `usms-db-01`?**
1. **Instance:** tags, security group, instance profile, user data, data volume, Elastic IP.
2. **Subnet:** IP range, public IP setting, route (internet gateway vs NAT).
3. **VPC:** CIDR and internet gateway, which are the same for both.

### Files

1. `labs/lab-03-ec2/user-data.sh`, `user-data-db.sh`, `transcript-upload.sh`
2. `templates/lab-03-run-instances.json`, `lab-03-run-instances-web02.json`
3. `configs/lab-03.env`
4. `scripts/utilities/verify-lab-03.sh`, `lab-03-reachability.sh`
5. `scripts/cleanup/lab-03-cleanup.sh` (not run)

### Pricing Sources

1. [Amazon EC2 T3 Instances](https://aws.amazon.com/ec2/instance-types/t3/)
2. [t3.micro pricing (us-east-1)](https://www.doit.com/compute/spot/us-east-1/t3.micro) and [t3.small pricing (us-east-1)](https://www.doit.com/compute/spot/us-east-1/t3.small)
3. [AWS Public IPv4 Address Charge](https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights)
4. [Elastic Load Balancing Pricing](https://aws.amazon.com/elasticloadbalancing/pricing/)