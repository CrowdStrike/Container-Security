# Push Latest Falcon Sensor to AWS ECR
CrowdStrike with Azure DevOps and AWS ECR

> **Note**: This is an open source project, not a CrowdStrike product. As such, it carries no formal support, expressed or implied.

## Introduction

This pipeline retrieves the latest Falcon Sensor image and pushes to your ECR registry.
  
![image](https://user-images.githubusercontent.com/29733103/212500363-68bd3c9b-99a7-41ff-8193-2573df399ed4.png)
  
### Prerequisites
- AWS account with IAM programmatic access to Elastic Container Registry.
- Falcon API Client and Key with scope: Falcon Image Download (read)
- Working knowledge of Azure DevOps pipelines.
- Agent machine must have AWS CLI, Docker and JQ installed.
- Existing AWS ECR Repository
  

## Push Latest Sensor Image to ECR
The approach outlined in this document requires the Falcon Sensor Image to be made available in a private registry.  For this example, we use AWS Elastic Container Registry (ECR).
  
The pipeline uses an Ubuntu agent machine with Docker installed to retrieve the latest Sensor Image from the Falcon Container Registry.  The FALCON_SENSOR_TYPE variable specifies whether to pull the Container Sensor or Daemonset Sensor.  The sensor version is set as the image tag and pushed to your ECR repository. Eg. 1234567890.dkr.ecr.us-west-2.amazonaws.com/your-falcon-repo:6.50.0-3303.container.x86_64.Release.US-1
  

### Steps

| Step | Description |
|:-|:-|
| Install Docker | Install the Docker CLI on the agent machine. |
| Request Falcon API Bearer Token | Login using your API keys (client & secret) to obtain an OAuth2 bearer token to allow interaction with the CrowdStrike API. |
| Retrieve Falcon Registry Credentials | Using the OAuth2 bearer token from the previous step, retrieve credentials for the CrowdStrike private registry. |
| Query for Latest Sensor Version | Query the CrowdStrike private registry for the latest Falcon Sensor Version. |
| Pull Sensor Image | Pull latest Falcon Image. |
| Push Sensor Image to ECR | Push latest Falcon Image to AWS ECR. |
  

### Required Variable Inputs

| Variable Name | Description |
|:-|:-|
| FALCON_IMAGE_TYPE | falcon-container or falcon-sensor (daemonset) |
| FALCON_CID | Your cid with checksum, can be found in Hosts Management > Sensor Downloads |
| FALCON_CLIENT_ID | Your Falcon API Client ID with Falcon Image Download (read) scope |
| FALCON_CLIENT_SECRET | Your Falcon API Client Secret with Falcon Image Download (read) scope |
| FALCON_CLOUD_API | api.crowdstrike.com (us-1), api.us-2.crowdstrike.com (us-2), api.eu-1.crowdstrike.com (eu-1) |
| FALCON_CLOUD_REGION | us-1, us-2, or eu-1 |
| AWS_ACCOUNT_ID | AWS Account hosting ECR Registry |
| AWS_REGION | AWS Region hosting ECR Registry |
| AWS_ACCESS_KEY_ID | AWS IAM Access Key with permissions to ECR |
| AWS_SECRET_ACCESS_KEY | AWS IAM Secret Access Key with permissions to ECR |
| AWS_ECR_REPOSITORY | AWS ECR Repository Name |
