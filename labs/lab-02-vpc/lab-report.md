# Lab 02 - Virtual Private Cloud and Networking

## 1. Aim / Objective

To create and configure a Virtual Private Cloud (VPC) using the AWS CLI - including subnets, routing, gateways, security groups, and a network ACL - and verify the network works as designed.

## 2. Introduction

Amazon VPC lets an AWS account create its own private network to launch resources into, controlling IP ranges, subnets, routing, and access. Key features include custom CIDR blocks, public and private subnets, internet and NAT gateways, security groups, network ACLs, and private endpoints to other AWS services. It is foundational because almost every other AWS service depends on it to control what can be reached and by whom. It's commonly used to separate a public web tier from a private database tier, giving the private tier controlled outbound access without exposing it to the internet.

## 3. Use Case

- Hosting a public-facing web application.
- Keeping a database in a subnet that is never reachable from the internet.
- Giving private resources outbound-only internet access for updates.
- Connecting private resources to S3 without using the public internet.

## 4. System Architecture / Design

![USMS VPC architecture](../../screenshots/lab-02/vpc/architecture.png)

Public subnets route to the internet gateway. The private route table's default route points at usms-nat, which lives in the public subnet, this is what lets the private subnets reach the internet outbound without ever being reachable from it. usms-app-sg is attached to the public-tier instances and usms-db-sg is attached to the private-tier instances, with the database group sourcing its access from the app group rather than a CIDR block.

## 5. Implementation Procedure

1. Resumed Floci and confirmed storage was durable.
2. Loaded Lab 01 and confirmed identity.
3. Created the `usms-vpc` VPC and restored the normal identity.
4. Enabled DNS support and hostnames.
5. Created and attached an Internet Gateway.
6. Created and configured the public subnet.
7. Created the private subnet.
8. Created public and private route tables.
9. Verified the subnet routes were different.
10. Created application and database security groups.
11. Created and configured the private NACL.
12. Created a NAT Gateway and routed private traffic through it.
13. Created an S3 gateway endpoint.
14. Verified all resources had the `Project=USMS` tag.
15. Confirmed the network survived a restart.
16. Recorded resource IDs in `configs/lab-02.env`.
17. Committed the work and created a verification script.
18. Completed all five additional exercises.

## 6. Results and Evidence

### 6.1 CLI / SDK Output

![Environment resumed](../../screenshots/lab-02/vpc/0.png)

*Floci resumed, storage confirmed durable.*

![Identity confirmed](../../screenshots/lab-02/vpc/1.png)

*Lab 01 variables sourced, account confirmed.*

![Policy checked before use](../../screenshots/lab-02/vpc/2.png)

*Developer policy's active version read.*

![Role assumed](../../screenshots/lab-02/vpc/3.1.png)

*Temporary credentials obtained.*

![Identity as assumed role](../../screenshots/lab-02/vpc/3.2.png)

*Caller identity shows the assumed role.*

![VPC created](../../screenshots/lab-02/vpc/3.3.png)

*usms-vpc created with CIDR 10.0.0.0/16.*

![Identity restored](../../screenshots/lab-02/vpc/4.png)

*Back to the normal account identity.*

![DNS enabled](../../screenshots/lab-02/vpc/5.png)

*DNS support and hostnames both True.*

![Internet gateway attached](../../screenshots/lab-02/vpc/6.png)

*usms-igw attached to the VPC.*

![Public subnet created](../../screenshots/lab-02/vpc/7.png)

*usms-public-subnet-a created.*

![Public IP auto-assign on](../../screenshots/lab-02/vpc/8.png)

*Confirmed True for the public subnet.*

![Private subnet created](../../screenshots/lab-02/vpc/9.png)

*usms-private-subnet-a created, no public IP.*

![Public route table created](../../screenshots/lab-02/vpc/10.png)

*Default route to the internet gateway.*

![Public subnet associated](../../screenshots/lab-02/vpc/11.png)

*Associated with the public route table.*

![Second public subnet](../../screenshots/lab-02/vpc/11(myturn).png)

*usms-public-subnet-b created and associated.*

![Private route table created](../../screenshots/lab-02/vpc/12.png)

*Associated with the private subnet, no internet route.*

![Public vs private proven](../../screenshots/lab-02/vpc/13.png)

*Public subnet routes to the igw; private shows no route.*

![App security group created](../../screenshots/lab-02/vpc/14.png)

*usms-app-sg with HTTP and internal SSH.*

![HTTPS rule added](../../screenshots/lab-02/vpc/14(myturn).png)

*Port 443 added with a description.*

![DB security group created](../../screenshots/lab-02/vpc/15.1.png)

*usms-db-sg created.*

![Group-referenced rule written](../../screenshots/lab-02/vpc/15.2.png)

*Rule sourced from usms-app-sg, not a CIDR.*

![Rule applied and verified](../../screenshots/lab-02/vpc/15.3.png)

*Confirmed group-referenced, not address-based.*

![All security groups read back](../../screenshots/lab-02/vpc/16.png)

*Three groups in the VPC.*

![Default NACL inspected](../../screenshots/lab-02/vpc/17.1.png)

*Default allow and implicit deny rules seen.*

![Private NACL created](../../screenshots/lab-02/vpc/17.2.png)

*usms-private-nacl created.*

![NACL rules written](../../screenshots/lab-02/vpc/17.3.png)

*Inbound/outbound rules, including the ephemeral-port rule.*

![NACL associated](../../screenshots/lab-02/vpc/18.png)

*Replacing the default NACL on the private subnet.*

![Elastic IP allocated](../../screenshots/lab-02/vpc/19.1.png)

*Reserved for the NAT gateway.*

![NAT gateway created](../../screenshots/lab-02/vpc/19.2.png)

*usms-nat created in the public subnet.*

![NAT gateway available](../../screenshots/lab-02/vpc/19.3.png)

*Reached the available state.*

![Private route pointed at NAT](../../screenshots/lab-02/vpc/20.png)

*Default route now targets the NAT gateway.*

![S3 endpoint created](../../screenshots/lab-02/vpc/21.png)

*usms-s3-endpoint attached to the private route table.*

![Tag audit](../../screenshots/lab-02/vpc/22.png)

*Every resource confirmed tagged Project=USMS.*

![Subnet inventory](../../screenshots/lab-02/vpc/22(myturn).png)

*Private subnets listed before public ones.*

![Pre-restart state recorded](../../screenshots/lab-02/vpc/23.1.png)

*VPC, subnet, and security group counts saved.*

![Floci restarted](../../screenshots/lab-02/vpc/23.2.png)

*Environment stopped and started again.*

![Persistence proven](../../screenshots/lab-02/vpc/23.3.png)

*Same VPC found by tag, counts unchanged.*

![lab-02.env generated](../../screenshots/lab-02/vpc/24.png)

*All resource IDs saved for later labs.*

![Work committed](../../screenshots/lab-02/vpc/25.1.png)

*Lab 02 committed to Git.*

![Final verification](../../screenshots/lab-02/verification/verification9.2.png)

*verify-lab-02.sh - PASS=33, FAIL=0.*

**Exercises**

![Exercise 1](../../screenshots/exercises/exercise1.png)

*Third public subnet created and associated.*

![Exercise 2](../../screenshots/exercises/exercise2.png)

*Bastion security group created; app SG's SSH switched to a group reference.*

![Exercise 3](../../screenshots/exercises/exercise3.png)

*Script classifies each subnet from its route table alone.*

![Exercise 4](../../screenshots/exercises/exercise4.png)

*New security group created for a designed service; practice subnet removed.*

![Exercise 5](../../screenshots/exercises/exercise5.png)

*Second private subnet created under the assumed role.*

### 6.2 AWS Management Console Verification

Floci is CLI/API-only and has no web console, so no console screenshots exist. Every resource was verified instead through the AWS CLI's own read commands, shown above, which serve the same purpose.

## 7. Analysis and Discussion

The objective was achieved: a complete VPC was built with public and private subnets across two Availability Zones, correct routing, two firewall layers, a NAT gateway, and an S3 endpoint. Results matched expectations, confirmed by a verification script reporting `PASS=33, FAIL=0`.

A few errors came up. Two security-group rule removals reported success but the rule still appeared in one read command; a second, more reliable command confirmed the rule really had been removed. A similar delay appeared when moving a subnet to a new network ACL. A more serious mistake happened during cleanup, where a leftover variable from earlier in the session caused the wrong subnet to be disconnected from its route table; this was found by checking every subnet's ID directly, then fixed by reconnecting the right one and removing the leftover association.

## 8. Reflection

1. **What I learned.** A subnet is public or private purely because of its route table, not its name or settings. Security groups and NACLs work differently, and referencing a security group as a source is safer than hard-coding an address range.

2. **Challenges.** Telling apart a command that failed from one that succeeded but was reported inconsistently, and learning to check the same fact more than one way before trusting it.

3. **Real-world application.** This same layout, public tier, private tier, NAT for outbound access, and a service endpoint, is the standard shape of a real AWS network for any app with a public front end and a private backend.

4. **What I'd explore further.** How security groups and NACLs actually behave against real traffic, since that could not be observed here.

## 9. Conclusion

This lab built a two-tier VPC for the USMS project, with public and private subnets across two Availability Zones, correct routing, layered firewalls, a NAT gateway, and an S3 endpoint, meeting all objectives. The key concepts learned were that a subnet's public/private status comes only from its route table, the difference between stateful security groups and stateless NACLs, and the importance of reading a claim back from the API rather than trusting a command's success alone. Skills developed included capturing and reusing resource IDs, shaping API output, and diagnosing inconsistent results by cross-checking commands. VPC is foundational, since nearly every other AWS service depends on it.

## 10. Appendix

- Security group rule JSON: `policies/usms-db-sg-ingress.json`
- Configuration: `configs/course.env`, `configs/lab-01.env`, `configs/lab-02.env`
- Verification script: `scripts/utilities/verify-lab-02.sh`
- Classification script (Exercise 3): `scripts/utilities/lab-02-network-report.sh`
- Cleanup script (not run): `scripts/cleanup/lab-02-cleanup.sh`
- Screenshots: `screenshots/vpc/`
- Notes and review questions: `notes/lab-02-notes.md`