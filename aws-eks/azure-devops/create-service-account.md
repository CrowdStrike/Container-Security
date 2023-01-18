# How to Create Service Connection for Azure DevOps (ADO) Pipelines to AWS EKS Cluster

## Create Service Account
**After your cluster is created create the service account**
```
kubectl create serviceaccount ado-admin
```
  
**Then apply the cluster rolebinding**
```
kubectl create clusterrolebinding ado-admin-crb --clusterrole=cluster-admin --serviceaccount=default:ado-admin
```
  
## Setup ADO Service Connection
**In ADO goto Project Settings > Service Connections > New Service Connection > Kubernetes**
- Authentication method: Service Account
- Server URL: EKS Endpoint
- Secret:  To Get Secret follow the below commands...
```
kubectl get serviceAccounts ado-admin -n default -o=jsonpath={.secrets}

# Example Response: [{"name":"ado-admin-token-*****"}]
```
**Use Response in next command:**

```
kubectl get secret ado-admin-token-***** -n default -o json

# Example Response:
{
    "apiVersion": "v1",
    "data": {
        "ca.crt": "*****==",
        "namespace": "****==",
        "token": "*****=="
    },
    "kind": "Secret",
    "metadata": {
        "annotations": {
            "kubernetes.io/service-account.name": "ado-admin",
            "kubernetes.io/service-account.uid": "****-***-***-***-****"
        },
        "creationTimestamp": "2023-01-01T00:00:00Z",
        "name": "ado-admin-token-*****",
        "namespace": "default",
        "resourceVersion": "123456",
        "uid": "****-***-***-***-****"
    },
    "type": "kubernetes.io/service-account-token"
}
```
**Paste this response in 'Secret' field in ADO new service connection dialiog**
- Service connection name: use this name in pipelines