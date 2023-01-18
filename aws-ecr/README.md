# Push Latest Falcon Sensor to AWS ECR
CrowdStrike with AWS ECR

> **Note**: This is an open source project, not a CrowdStrike product. As such, it carries no formal support, expressed or implied.

### Prerequisites
- JQ: https://stedolan.github.io/jq/
- AWS CLI: https://aws.amazon.com/cli/
- Docker: https://www.docker.com/get-started/ (or alternatively Podman, however the steps in this guide are written for Docker).

### Step 1 - Create Falcon API Client and Keys

1. Goto Support > Api client and keys
2. Create API Client and keys with these scope :
Falcon Image Download (read)

### Step 2 - Set Environment Variables

```
export FALCON_CLIENT_ID=
export FALCON_CLIENT_SECRET=
export FALCON_CID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-YY # < Your cid with checksum, can be found in # Hosts Management > Sensor Downloads
export FALCON_CLOUD_REGION=us-2 # us-1 or us-2 or eu-1
export FALCON_CLOUD_API=api.us-2.crowdstrike.com # api.crowdstrike.com (us-1), api.us-2.crowdstrike.com (us-2), api.eu-1.crowdstrike.com (eu-1)
```
### Step 3 - Get Private CrowdStrike Registry Credentials From API

**get OAuth2 token**
Login using your API keys (client & secret) to obtain an OAuth2 bearer token to allow interaction with the CrowdStrike API.
```
export FALCON_API_BEARER_TOKEN=$(curl \
--silent \
--header "Content-Type: application/x-www-form-urlencoded" \
--data "client_id=${FALCON_CLIENT_ID}&client_secret=${FALCON_CLIENT_SECRET}" \
--request POST \
--url "https://$FALCON_CLOUD_API/oauth2/token" | \
jq -r '.access_token')
```

**get CrowdStrike registry password**
Using the OAuth2 bearer token from the previous step, retrieve password FALCON_ART_PASSWORD to be used alongside FALCON_ART_USERNAME (next step) which will obtain access to the CrowdStrike private registry - which is necessary for reviewing repositories and pulling the image. Essentially docker login credentials.
```
export FALCON_ART_PASSWORD=$(curl --silent -X GET -H "authorization: Bearer ${FALCON_API_BEARER_TOKEN}" \
https://${FALCON_CLOUD_API}/container-security/entities/image-registry-credentials/v1 | \
jq -r '.resources[].token')
```

**format username to login to CrowdStrike registry**
The format is based on your CID, except it's all lowercase, checksum is removed, and fc-  is appended to the front. Example format fc-xxxxxxxxxxxxxxxxxxxxx .
```
export FALCON_ART_USERNAME="fc-$(echo $FALCON_CID | awk '{ print tolower($0) }' | cut -d'-' -f1)"
```

### Step 4 - Get Latest Sensor Version

**login to CrowdStrike registry & retrieve latest sensor version**
Obtain and utilize REGISTRYBEARER token to interact with the CrowdStrike private registry. Then get the latest sensor version. Finally, setting the FALCON_IMAGE_REPO variable where you will be pulling/deploying the image from and setting up the tag for it.
Example tag: 6.35.0-13206.falcon-linux.x86_64.Release.US-1 
```
export REGISTRYBEARER=$(curl -X GET -s -u "${FALCON_ART_USERNAME}:${FALCON_ART_PASSWORD}" "https://registry.crowdstrike.com/v2/token?=${FALCON_ART_USERNAME}&scope=repository:$SENSORTYPE/$FALCON_CLOUD_REGION/release/falcon-sensor:pull&service=registry.crowdstrike.com" | jq -r '.token')
 
export LATESTSENSOR=$(curl -X GET -s -H "authorization: Bearer ${REGISTRYBEARER}" "https://registry.crowdstrike.com/v2/falcon-container/${FALCON_CLOUD_REGION}/release/falcon-sensor/tags/list" | jq -r '.tags[-1]')
 
export FALCON_IMAGE_REPO="registry.crowdstrike.com/falcon-container/${FALCON_CLOUD_REGION}/release/falcon-sensor"
export FALCON_IMAGE_TAG=$LATESTSENSOR
```

### Step 5 - Pull/Push Container Sensor Image to ECR

Pull the Falcon Container Image and save it to your ECR
```
### Pull image from Crowdstrike registry
echo $FALCON_ART_PASSWORD | docker login -u $FALCON_ART_USERNAME --password-stdin registry.crowdstrike.com
 
### Get sensor for DaemonSet
docker pull $FALCON_IMAGE_REPO:$FALCON_IMAGE_TAG
 
### Tag the image to point to your registry
docker tag $FALCON_IMAGE_REPO:$FALCON_IMAGE_TAG <AWSACCOUNTID>.dkr.ecr.<AWSREGION>.amazonaws.com/falcon-sensor/falcon-container:your_tag_value
 
### push the image to your registry
docker push <AWSACCOUNTID>.dkr.ecr.<AWSREGION>.amazonaws.com/falcon-sensor/falcon-container:your_tag_value
```
