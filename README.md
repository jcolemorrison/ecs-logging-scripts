A small repo of 2 ECS Admin helpers.

The Shell script `ecs-logs-init.sh` can be used as `User Data` for you EC2 instances and Launch Configurations for `ECS` clusters.  It provides the following functionality:

**a)** Tell the instance what cluster to join

**b)** Install the `awslogs` tool

**c)** Setup the default points to send our Logs to

**d)** Set the region to send our logs to (which by default will be the one our instance resides in)

**e)** Setup logging meta data so that we can tell which logs belong to which clusters, services and instances

**f)** Install the SSM Agent to allow for `Run Command`

The Policy just allows for putting logs to Cloudwatch for these instances.  You're ECS Container instances will generally have a role for the instances.  Attach this policy to that role as well.

More details can be found on this post:

[How to Unify AWS ECS Logs in CloudWatch (and SSM Run Command)](http://start.jcolemorrison.com/how-to-setup-aws-ecs-logs-in-cloudwatch-and-ssm)