# Deploy Falcon to ECS Fargate
CrowdStrike with Azure DevOps and AWS ECS
  
## Introduction
This document describes a basic approach to integrate Falcon Sensor Deployment on AWS ECS Fargate with an Azure DevOps Pipeline.  While this document uses Azure DevOps pipelines to demonstrate our approach, this approach can be recreated in any other CI/CD tool as the steps will be virtually identical. 
  
This solution uses the Falcon Container Sensor image image to patch a supplied Task Definition spec file and register the new Task Definition with AWS ECS.
  
![image](https://user-images.githubusercontent.com/29733103/212939731-b2f02fde-5e7e-4697-83d8-c2580218033a.png)
  
This document will also explain how the Falcon Patching Utility is actually modifying your ECS Spec files and what happens at launch.
  
**Note:** The intent of this document is only to describe Falcon Container Sensor deployment to AWS ECS on Fargate.  For information on deploying the daemonset sensor to ECS on EC2, please see https://falcon.crowdstrike.com/documentation/20/falcon-sensor-for-linux#install-the-falcon-sensor-for-linux-directly-on-the-hosts 
  
### Prerequisites
- AWS account with IAM programmatic access to Elastic Container Registry and Elastic Container Service.
- Working knowledge of Azure DevOps pipelines or similar CI/CD tool.
- Agent machine must have AWS CLI, Docker and JQ installed.
- AWS ECR Repository named falcon-sensor/falcon-container
  

## Patch Task Definition and Register with AWS ECS
This pipeline will demonstrate how to integrate the Falcon Patching utility as a part of your ECS Task Definition build pipeline.  In our example, the ECS Task Definition build phase is abstracted by providing an existing ECS Task Definition Spec file.  The customer’s ECS Task Definition build phase may be more complex, but this doesn’t affect our approach here since the patching utility assumes the supplied Task Definition Spec file is complete and ready for registration.
  
Once the spec file is retrieved (build phase complete), the following steps create a pull token to access ECR, then execute a docker run command to run the Falcon Patching Utility against the supplied ECS Task Definition Spec file.  This will finally produce a new spec file with necessary additions to include the Falcon Container Sensor as an additional container on the task.  Our pipeline completes by registering the new ECS Task Definition in AWS.
  
**Source:** https://github.com/ryanjpayne/cs-container-security/blob/main/AWS%20ECS/azure-devops/patch-ecs-task-definition.yml 
  

### Steps

| Step | Description |
|:-|:-|
| Install Docker | Install the Docker CLI on the agent machine. |
| Build ECS Task Spec File | Retrieve ECS Task Spec File and set parameters. |
| Create Pull Token for ECR | Construct a pull token for use with ECR. |
| Run Falcon Patching Utility on ECS Task Spec File | Patch the supplied ECS Task Definition Spec file.  More details below. |
| Register Patched Task Definition with AWS ECS | Register modified Task Definition with AWS ECS. |
  

### Required Inputs

| Variable Name | Description |
|:-|:-|
| AWS_ACCOUNT_ID | AWS Account hosting ECS Tasks |
| AWS_REGION | AWS Region hosting ECS Tasks |
| AWS_ACCESS_KEY_ID | AWS IAM Access Key with permissions to ECS |
| AWS_SECRET_ACCESS_KEY | AWS IAM Secret Access Key with permissions to ECS |
| FALCON_CID | Your cid with checksum, can be found in Hosts Management > Sensor Downloads |
| FALCON_CONTAINER_SENSOR_REGISTRY | ECR Registry URI for Falcon Container Sensor. eg: 1234567890.dkr.ecr.us-west-2.amazonaws.com/falcon-sensor/falcon-container:latest |

## How the Patching Utility Works
The patching utility makes necessary changes to your spec file such as:
  
- Additional entrypoints, capabilities and environment variables to your container definition
- Additional container definition for CrowdStrike init container
  
When the patching utility completes, it creates a new Task Definition Spec file.  
  
Upon deployment the CrowdStrike init container sets up a shared working directory and copies in the required libraries and binaries required for the falcon sensor. Then the application starts with a modified entrypoint to first start the crowdstrike sensor followed by the customer's defined entrypoint.
  
### Running the Patching Utility
This is the docker run command used in step 4 of the Patch Task Definition and Register with ECS pipeline.  This assumes that the Falcon Container Sensor image is in your ECR Registry.
  
```
# Generate Pull Token on Mac:
export PULL_TOKEN=$(echo "{\"auths\":{\"<AWSACCOUNTID>.dkr.ecr.<AWSREGION>.amazonaws.com\":{\"auth\": \"$(echo AWS:$(aws ecr get-login-password)|base64)\"}}}" | base64)
# Generate Pull Token on Linux:
export PULL_TOKEN=$(echo "{\"auths\":{\"<AWSACCOUNTID>.dkr.ecr.<AWSREGION>.amazonaws.com\":{\"auth\": \"$(echo AWS:$(aws ecr get-login-password)|base64 -w 0)\"}}}" | base64 -w 0)
 
# Run Patching Utility
docker run -v /path/to/ecs/taskspecfolder:/var/run/spec \
--rm <AWSACCOUNTID>.dkr.ecr.<AWSREGION>.amazonaws.com/falcon-sensor/falcon-container:your_tag_value \
-cid "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-YY" \
-image "<AWSACCOUNTID>.dkr.ecr.<AWSREGION>.amazonaws.com/falcon-sensor/falcon-container:your_tag_value" \
-pulltoken $PULL_TOKEN \
-ecs-spec-file /var/run/spec/taskdefinition.json > taskdefinitionwithfalcon.json
```
  
### docker run Flags Explained
  
| Flag | Description |
|:-|:-|
| -v <localpath>:<pathwithincontainer> | Used to mount the directory holding your task definition locally into the falcon container as a volume in order for the ecs patcher to access |
| --rm | Automatically clean up the container and remove the file system when the container exits |
| <repo>:<tag> | The repo/tag value of the container image to run containing the patching utility |
| -cid <cidvalue> | Customer ID - Used to direct falcon container sensors to report into your falcon cloud portal |
| -image <repo>:<tag> | Represents the image path which the falcon init containers will spawn from (typically ECR). |
| -pulltoken | Used by the ECS patching utility to query in ECR hosted images defined within the ECS task definition and file to inspect their entrypoints / commands if not defined in the customers ECS task definitions. |
| -ecs-spec-file /var/run/spec/<taskdefintion.json> | Lastly the output is redirected to a newfile. Alternatively remove this redirection and it will print to stdout. |



### Example Task Definition - Before Patch Utility
  
```
{
 "executionRoleArn": "arn:aws:iam::1234567890:role/ecsTaskExecutionRole",
 "containerDefinitions": [
   {
     "logConfiguration": {
       "logDriver": "awslogs",
       "options": {
         "awslogs-group": "/ecs/fargate-task-definition",
         "awslogs-region": "us-west-2",
         "awslogs-stream-prefix": "ecs"
       }
     },
     "entryPoint": [
       "sh",
       "-c"
     ],
     "portMappings": [
       {
         "hostPort": 80,
         "protocol": "tcp",
         "containerPort": 80
       }
     ],
     "command": [
       "/bin/sh -c \"echo '<html> <head> <title>Amazon ECS Sample App</title> <style>body {margin-top: 40px; background-color: #333;} </style> </head><body> <div style=color:white;text-align:center> <h1>Amazon ECS Sample App</h1> <h2>Congratulations!</h2> <p>Your application is now running on a container in Amazon ECS.</p> </div></body></html>' >  /usr/local/apache2/htdocs/index.html && httpd-foreground\""
     ],
     "cpu": 0,
     "image": "httpd:2.4",
     "name": "sample-fargate-app"
   }
 ],
 "memory": "512",
 "compatibilities": [
   "EC2",
   "FARGATE"
 ],
 "taskDefinitionArn": "arn:aws:ecs:us-west-2:1234567890:task-definition/fargate-task-definition:1",
 "family": "fargate-task-definition",
 "requiresCompatibilities": [
   "FARGATE"
 ],
 "networkMode": "awsvpc",
 "runtimePlatform": {
   "operatingSystemFamily": "LINUX"
 },
 "cpu": "256",
 "revision": 1,
 "status": "ACTIVE"
}
```
  
### Example Task Definition - After Patch Utility
  
```
{
 "executionRoleArn": "arn:aws:iam::1234567890:role/ecsTaskExecutionRole",
 "containerDefinitions": [
   {
     "logConfiguration": {
       "logDriver": "awslogs",
       "options": {
         "awslogs-group": "/ecs/fargate-task-definition",
         "awslogs-region": "us-west-2",
         "awslogs-stream-prefix": "ecs"
       }
     },
     "entryPoint": [
       "/tmp/CrowdStrike/rootfs/lib64/ld-linux-x86-64.so.2",
       "--library-path",
       "/tmp/CrowdStrike/rootfs/lib64",
       "/tmp/CrowdStrike/rootfs/bin/bash",
       "/tmp/CrowdStrike/rootfs/entrypoint-ecs.sh",
       "sh",
       "-c"
     ],
     "portMappings": [
       {
         "hostPort": 80,
         "protocol": "tcp",
         "containerPort": 80
       }
     ],
     "command": [
       "/bin/sh -c \"echo '<html> <head> <title>Amazon ECS Sample App</title> <style>body {margin-top: 40px; background-color: #333;} </style> </head><body> <div style=color:white;text-align:center> <h1>Amazon ECS Sample App</h1> <h2>Congratulations!</h2> <p>Your application is now running on a container in Amazon ECS.</p> </div></body></html>' >  /usr/local/apache2/htdocs/index.html && httpd-foreground\""
     ],
     "linuxParameters": {
       "capabilities": {
         "add": [
           "SYS_PTRACE"
         ]
       }
     },
     "cpu": 0,
     "environment": [
       {
         "name": "FALCONCTL_OPTS",
         "value": "--cid=97DBE4B7157348B9A533D66A81E30D28-B9"
       }
     ],
     "mountPoints": [
       {
         "readOnly": false,
         "containerPath": "/tmp/CrowdStrike",
         "sourceVolume": "crowdstrike-falcon-volume"
       }
     ],
     "image": "httpd:2.4",
     "dependsOn": [
       {
         "containerName": "crowdstrike-falcon-init-container",
         "condition": "COMPLETE"
       }
     ],
     "name": "sample-fargate-app"
   },
   {
     "entryPoint": [
       "/bin/bash",
       "-c",
       "chmod u+rwx /tmp/CrowdStrike && mkdir /tmp/CrowdStrike/rootfs && cp -r /bin /etc /lib64 /usr /entrypoint-ecs.sh /tmp/CrowdStrike/rootfs && chmod -R a=rX /tmp/CrowdStrike"
     ],
     "cpu": 0,
     "mountPoints": [
       {
         "readOnly": false,
         "containerPath": "/tmp/CrowdStrike",
         "sourceVolume": "crowdstrike-falcon-volume"
       }
     ],
     "image": "1234567890.dkr.ecr.us-west-2.amazonaws.com/falcon-sensor/falcon-container",
     "user": "0:0",
     "name": "crowdstrike-falcon-init-container"
   }
 ],
 "memory": "512",
 "compatibilities": [
   "EC2",
   "FARGATE"
 ],
 "taskDefinitionArn": "arn:aws:ecs:us-west-2:1234567890:task-definition/fargate-task-definition:2",
 "family": "fargate-task-definition",
 "requiresCompatibilities": [
   "FARGATE"
 ],
 "networkMode": "awsvpc",
 "cpu": "256",
 "revision": 2,
 "status": "ACTIVE",
 "volumes": [
   {
     "name": "crowdstrike-falcon-volume"
   }
 ]
}
```
