# Deploy and Update Falcon to AWS EKS with Azure DevOps
  
  > **Note**: This is an open source project, not a CrowdStrike product. As such, it carries no formal support, expressed or implied.
  
## Introduction
This document describes a basic approach to integrate Falcon Sensor Deployment on AWS EKS with an Azure DevOps Pipeline.  While this document uses Azure DevOps pipelines to demonstrate our approach, this approach can be recreated in any other CI/CD tool as the steps will be virtually identical. 
  
This solution uses the Falcon Operator, to use Helm please see: **TBD**
  
### Prerequisites
- AWS EKS Cluster with access to create service accounts and role-bindings.
- Working knowledge of Azure DevOps pipelines or similar CI/CD tool.
- Agent machine must have kubectl installed.
  

## Deploy Falcon Sensor via Falcon Operator
This pipeline will demonstrate how to deploy the Falcon Operator and then the Falcon Sensor.  In our example, the supplied variables will determine whether to install the Daemonset Sensor or the Container sensor.  While the operator can install either, you must choose Container sensor for EKS on Fargate.  The image source can also be set via variables.  'default' will source the image from CrowdStrike, while 'ECR' will mirror the image to your ECR repository.
  
This pipeline will download the appropriately formated CRD file and configure certain required fields.  For more info see: https://github.com/ryanjpayne/cs-container-security/tree/main/aws-eks/crd

### Steps

| Step | Description |
|:-|:-|
| Install Kubectl | Install kubectl on the agent machine. |
| Download Operator File | Retrieve Falcon Operator yaml from CrowdStrike repo. |
| Setup Default Falcon Node Sensor CRD File | Build CRD file if FALCON_SENSOR_TYPE = 'falcon-sensor' & FALCON_SENSOR_IMAGE_LOCATION = 'default' |
| Setup ECR Falcon Node Sensor CRD File | Build CRD file if FALCON_SENSOR_TYPE = 'falcon-sensor' & FALCON_SENSOR_IMAGE_LOCATION = 'ECR' |
| Setup Default Falcon Container Sensor CRD File | Build CRD file if FALCON_SENSOR_TYPE = 'falcon-container' & FALCON_SENSOR_IMAGE_LOCATION = 'default' |
| Setup ECR Falcon Container Sensor CRD File | Build CRD file if FALCON_SENSOR_TYPE = 'falcon-container' & FALCON_SENSOR_IMAGE_LOCATION = 'ECR' |
| Check Sensor CRD | Print/log modified CRD File. |
| Deploy Falcon Operator | Run kubectl apply falcon-operator.yaml against EKS Service Connection. |
| kubectl apply sensor CRD | Run kubectl apply sensor-crd.yml against EKS Service Connection. |
  

### Required Inputs

| Variable Name | Description |
|:-|:-|
| FALCON_SENSOR_TYPE | falcon-sensor or falcon-container |
| FALCON_SENSOR_IMAGE_LOCATION | default or ECR |

### Optional Inputs

| Variable Name | Description |
|:-|:-|
| FALCON_CID | Your Falcon CID, required if FALCON_SENSOR_TYPE = 'falcon-sensor' & FALCON_SENSOR_IMAGE_LOCATION = 'ECR' |
| FALCON_CLIENT_ID | Your Falcon API Client ID, required in all cases execpt when FALCON_SENSOR_TYPE = 'falcon-sensor' & FALCON_SENSOR_IMAGE_LOCATION = 'ECR' |
| FALCON_CLIENT_SECRET | Your Falcon API Client Secret, required in all cases execpt when FALCON_SENSOR_TYPE = 'falcon-sensor' & FALCON_SENSOR_IMAGE_LOCATION = 'ECR' |
| AWS_ECR_REPOSITORY | Your ECR Repo, required if FALCON_SENSOR_TYPE = 'falcon-sensor' & FALCON_SENSOR_IMAGE_LOCATION = 'ECR'  |