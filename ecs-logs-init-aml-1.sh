Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/bin/bash

# cluster to join REPLACE `YOURCLUSTERNAMEHERE` OBVIOUSLY
echo ECS_CLUSTER=YOURCLUSTERNAMEHERE >> /etc/ecs/ecs.config

# Install awslogs and the jq JSON parser
yum install -y awslogs jq

# Inject the CloudWatch Logs configuration file contents
cat > /etc/awslogs/awslogs.conf <<- EOF
[general]
state_file = /var/lib/awslogs/agent-state        

# Kernel Messages
[/var/log/dmesg]
file = /var/log/dmesg
log_group_name = {cluster}_kernal_messages
log_stream_name = {container_instance_id}/var/log/dmesg

# Global Messages
[/var/log/messages]
file = /var/log/messages
log_group_name = {cluster}_global_messages
log_stream_name = {container_instance_id}/var/log/messages
datetime_format = %b %d %H:%M:%S

# SSH logs
[/var/log/secure]
file = /var/log/secure
log_group_name = {cluster}_ssh_logs
log_stream_name = {container_instance_id}/var/log/secure
datetime_format = %b %d %H:%M:%S

# Cloud Init Logs (results of User Data Scripts)
[/var/log/cloud-init.log]
file = /var/log/cloud-init.log
log_group_name = {cluster}_cloud_init
log_stream_name = {container_instance_id}/var/log/cloud-init.log
datetime_format = %b %d %H:%M:%S

[/var/log/cloud-init-output.log]
file = /var/log/cloud-init-output.log
log_group_name = {cluster}_cloud_init_output
log_stream_name = {container_instance_id}/var/log/cloud-init-output.log
datetime_format = %b %d %H:%M:%S

# Docker Logs
[/var/log/docker]
file = /var/log/docker
log_group_name = {cluster}_docker
log_stream_name = {container_instance_id}/var/log/docker
datetime_format = %Y-%m-%dT%H:%M:%S.%f

# ECS Initialization Logs
[/var/log/ecs/ecs-init.log]
file = /var/log/ecs/ecs-init.log
log_group_name = {cluster}_ecs_init
log_stream_name = {container_instance_id}/var/log/ecs/ecs-init.log
datetime_format = %Y-%m-%dT%H:%M:%SZ

# ECS Agent Logs
[/var/log/ecs/ecs-agent.log]
file = /var/log/ecs/ecs-agent.log.*
log_group_name = {cluster}_ecs_agent
log_stream_name = {container_instance_id}/var/log/ecs/ecs-agent.log
datetime_format = %Y-%m-%dT%H:%M:%SZ

# IAM Role Audit Logs Logs
[/var/log/ecs/audit.log]
file = /var/log/ecs/audit.log.*
log_group_name = {cluster}_ecs_iam_audit
log_stream_name = {container_instance_id}/var/log/ecs/audit.log
datetime_format = %Y-%m-%dT%H:%M:%SZ

EOF

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/bin/bash

# Set the region to send CloudWatch Logs data to (the region where the container instance is located)
region=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
sed -i -e "s/region = us-east-1/region = $region/g" /etc/awslogs/awscli.conf

# Install AWS SSM agent RPM for later mass commands
# Not present by default on ECS Optimized AMI:
# https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-manual-agent-install.html#agent-install-al

# For x86_64 instances, so what you're probably using
yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm

# For arm64 instances, you'd run this:
# yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_arm64/amazon-ssm-agent.rpm

# For 32-bit:
# yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_386/amazon-ssm-agent.rpm

--==BOUNDARY==
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
	
	# start aws logs
	service awslogs start
	chkconfig awslogs on

	# start ssm
	start amazon-ssm-agent
end script
--==BOUNDARY==--