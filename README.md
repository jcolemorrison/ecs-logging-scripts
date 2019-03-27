A User Data Launch script to ESSENTIAL logging in CloudWatch for ECS container instances launched either one-off or via Launch Configuration + Auto Scaling Group.  Based on this [log file](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_cloudwatch_logs.html#cwlogs_user_data) from AWS.

To use - 

1. Ensure that your instances / launch configuration have the following IAM permissions:

```
"logs:CreateLogGroup",
"logs:CreateLogStream",
"logs:PutLogEvents",
"logs:DescribeLogStreams"
```

2. Grab either `ecs-logs-init-aml-1.sh`for Amazon Linux 1 based AMIs or `ecs-logs-init-aml-2.sh` for Amazon Linux 2 AMIs.  If you're keeping up to date with the ECS Optimized Image, you'll need the Amazon Linux 2 Script.

3. paste in the contents to your instance or Launch Configuration's User Data under `Advanced Details`.

---

The Shell script `ecs-logs-init.sh` can be used as `User Data` for you EC2 instances and Launch Configurations for `ECS` clusters.  It provides the following functionality:

**a)** Tell the instance what cluster to join

**b)** Install the `awslogs` and `jq`

**c)** Setup the default points to send our Logs to

**d)** Set the region to send our logs to (which by default will be the one our instance resides in)

**e)** Setup logging meta data so that we can tell which logs belong to which clusters, services and instances.  Logs the following:

- Global Messages
- Kernal Message
- SSH Logins
- Cloud Init Logs
- Docker Logs
- ECS Logs
- IAM Role Audit Logs

All named and organized in cloudwatch via log type -> container instance.  For example, Docker logs will be organized in this manner:

Log Group - `CLUSTER_global_messages`
Log Stream - `CONTAINER_INSTANCE_ID/var/log/messages`

You can modify the log group and log stream name to be whatever you'd like.

**f)** Install the SSM Agent to allow for `Run Command` (not present by default on ECS Optimized AMIs)

The Policy just allows for putting logs to Cloudwatch for these instances.  You're ECS Container instances will generally have a role for the instances.  Attach this policy to that role as well.

---

## Amazon Linux 2 Update

Amazon's newest Amazon Linux 2 AMI changes up how longs work.  First up, they're no longer referenced to as `awslogs`, but instead of `awslogsd`.  Second, to start and top logs, you'll be using the `systemctl` instead of `service`.  For example, the new start command to run logs is:

`systemctl start awslogsd`

And to start the service on each boot:

`systemctl enable awslogsd.service`

If you try to to use the old script in Amazon Linux 2, you'll get all sorts of nasty errors like...

```
cwlogs.push.stream - WARNING - somenumber - Thread-1 - No file is found with given path '/var/log/docker'.
```

... and so on.

---

More details can be found on this post:

[How to Unify AWS ECS Logs in CloudWatch (and SSM Run Command)](http://start.jcolemorrison.com/how-to-setup-aws-ecs-logs-in-cloudwatch-and-ssm)