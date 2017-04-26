Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
MIME-Version: 1.0
Content-Type: text/x-shellscript; charset="us-ascii"
#!/bin/bash

# cluster to join REPLACE `YOURCLUSTERNAMEHERE` OBVIOUSLY
echo ECS_CLUSTER=YOURCLUSTERNAMEHERE >> /etc/ecs/ecs.config

# Install awslogs and the jq JSON parser
yum install -y awslogs jq

# backup current cloudwatch files
mv /etc/awslogs/awslogs.conf /etc/awslogs/awslogs.conf.bak

# Inject the CloudWatch Logs configuration file contents
cat > /etc/awslogs/awslogs.conf <<- EOF
[general]
state_file = /var/lib/awslogs/agent-state

 # the most recent kernel messages
[/var/log/dmesg]
file = /var/log/dmesg
log_group_name = /var/log/dmesg
log_stream_name = {cluster}/{container_instance_id}

# more or less all logs, with timestamp
[/var/log/messages]
file = /var/log/messages
log_group_name = /var/log/messages
log_stream_name = {cluster}/{container_instance_id}
datetime_format = %b %d %H:%M:%S

# logs directly from docker
[/var/log/docker]
file = /var/log/docker
log_group_name = /var/log/docker
log_stream_name = {cluster}/{container_instance_id}
datetime_format = %Y-%m-%dT%H:%M:%S.%f

# logs from the initialization of ecs
[/var/log/ecs/ecs-init.log]
file = /var/log/ecs/ecs-init.log.*
log_group_name = /var/log/ecs/ecs-init.log
log_stream_name = {cluster}/{container_instance_id}
datetime_format = %Y-%m-%dT%H:%M:%SZ

# logs from the agent that's communicating between ecs and this instance
[/var/log/ecs/ecs-agent.log]
file = /var/log/ecs/ecs-agent.log.*
log_group_name = /var/log/ecs/ecs-agent.log
log_stream_name = {cluster}/{container_instance_id}
datetime_format = %Y-%m-%dT%H:%M:%SZ


[/var/log/ecs/audit.log]
file = /var/log/ecs/audit.log.*
log_group_name = /var/log/ecs/audit.log
log_stream_name = {cluster}/{container_instance_id}
datetime_format = %Y-%m-%dT%H:%M:%SZ

EOF

# Set the region to send CloudWatch Logs data to (the region where the container instance is located)
region=$(curl 169.254.169.254/latest/meta-data/placement/availability-zone | sed s'/.$//')
sed -i -e "s/region = us-east-1/region = $region/g" /etc/awslogs/awscli.conf

# Install AWS SSM agent RPM for later mass commands
yum install -y https://amazon-ssm-$region.s3.amazonaws.com/latest/linux_amd64/amazon-ssm-agent.rpm

--==BOUNDARY==
MIME-Version: 1.0
Content-Type: text/upstart-job; charset="us-ascii"

#upstart-job
description "Configure and start CloudWatch Logs agent on Amazon ECS container instance"
author "Amazon Web Services"
start on started ecs

script
  exec 2>>/var/log/ecs/cloudwatch-logs-start.log
  set -x

  until curl -s http://localhost:51678/v1/metadata
  do
    sleep 1
  done

  # Grab the cluster and container instance ARN from instance metadata
  cluster=$(curl -s http://localhost:51678/v1/metadata | jq -r '. | .Cluster')
  container_instance_id=$(curl -s http://localhost:51678/v1/metadata | jq -r '. | .ContainerInstanceArn' | awk -F/ '{print $2}' )

  # Replace the cluster name and container instance ID placeholders with the actual values
  sed -i -e "s/{cluster}/$cluster/g" /etc/awslogs/awslogs.conf
  sed -i -e "s/{container_instance_id}/$container_instance_id/g" /etc/awslogs/awslogs.conf

  service awslogs start
  chkconfig awslogs on
end script
--==BOUNDARY==--
