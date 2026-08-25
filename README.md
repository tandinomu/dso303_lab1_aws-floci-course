# AWS CLI + Floci

A local AWS environment built with Floci (via Docker Compose), used to
practise the AWS CLI and IAM by building infrastructure for a fictional
system called USMS.

## How to run it

Start the environment:

```bash
source configs/course.env
./scripts/setup/floci-up.sh
```

Stop it (data is kept):

```bash
./scripts/setup/floci-down.sh
```

Check everything is set up correctly:

```bash
source configs/lab-01.env
./scripts/utilities/verify-lab-01.sh
```



