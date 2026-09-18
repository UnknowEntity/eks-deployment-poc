# Learning EKS

## EKS Cluster Management

### Setup eksctl profile

```toml
# ~/.aws/config
[profile eksctl]
credential_process = aws configure export-credentials --profile <your-main-profile> --format process
region = <region>
```

**Note**: The reason for setting up a separate `eksctl` profile is related to an issue with AWS token expired when running long-lived `eksctl` commands. By using a dedicated profile with a credential process, you can ensure that fresh credentials are always used.

### Creating an EKS Cluster

Test command:

```bash
eksctl create cluster -f cluster.yaml --dry-run
```

```bash
eksctl create cluster -f cluster.yaml
```

### Set kubeconfig for the newly created cluster

```bash
aws eks --region <region> update-kubeconfig --name <cluster-name>
```

### Verifying the Cluster

```bash
kubectl get nodes
```

### Cleaning Up the Cluster

**Note**: You need `--disable-nodegroup-eviction` to prevent delete failures because nodegroups may have running pods that would otherwise block deletion.

> Default add-ons like CoreDNS or storage drivers often have strict PDB rules that prevent pod eviction, which can permanently hang or fail a eksctl delete cluster command.

```bash
eksctl delete cluster --region <region> --name <cluster-name> --disable-nodegroup-eviction
```

## ECR Management

### Creating an ECR Repository

Test command:

```bash
aws ecr describe-repositories --repository-names hello-world-go
```

```bash
aws ecr create-repository --repository-name hello-world-go
```

### Pushing a Image to the ECR Repository

#### 1. Docker

Login to ECR:

```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
```

Pushing the image to ECR:

```bash
docker build -t hello-world-go:latest .
docker tag hello-world-go:latest <account-id>.dkr.ecr.<region>.amazonaws.com/hello-world-go:latest
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/hello-world-go:latest
```

#### 2. Podman

Login to ECR:

```bash
aws ecr get-login-password --region <region> | podman login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
```

Pushing the image to ECR:

```bash
podman build -t hello-world-go:latest .
podman tag hello-world-go:latest <account-id>.dkr.ecr.<region>.amazonaws.com/hello-world-go:latest
podman push <account-id>.dkr.ecr.<region>.amazonaws.com/hello-world-go:latest
```

**Note**: To use podman both in windows and wsl, you need podman-remote installed and properly configured.

**In Windows:**

```powershell
podman version
```

This is to get the correct version of podman-remote installed and ensure it is properly configured.

**In WSL:**

```bash
# Download and extract the podman-remote binary for WSL
curl -L https://github.com/containers/podman/releases/download/<version>/podman-remote-static-linux_amd64.tar.gz -o /tmp/podman.tar.gz

# Unpack the downloaded tarball
tar -xzf /tmp/podman.tar.gz -C /tmp

# Move the podman-remote binary to a directory in your PATH, for example /usr/local/bin
sudo mv /tmp/bin/podman-remote-static-linux_amd64 /usr/local/bin/podman
sudo chmod +x /usr/local/bin/podman
# Verify the installation
podman version
```

This ensures that the podman-remote binary is correctly installed and available for use in WSL.
An added bonus is that you can track the images in Podman Desktop, providing a graphical interface to manage your containers and images.

### Verifying the Image in Podman Desktop

1. Open Podman Desktop.
2. Navigate to the "Images" section.
3. Look for the `hello-world-go:latest` image.
4. Ensure that the image is listed and has the correct tag.

This confirms that the image has been successfully pushed to ECR and is available for use in Podman Desktop.

### Verifying the Image in ECR

To verify that the image has been successfully pushed to ECR, you can use the following command:

```bash
aws ecr describe-images --repository-name hello-world-go
```

This command will list all the images in the `hello-world-go` repository, allowing you to confirm that the `hello-world-go:latest` image is present.

### Clean up ECR

To clean up the ECR repository and remove the image, you can use the following commands:

```bash
aws ecr delete-repository --repository-name hello-world-go --force
```

The `--force` flag ensures that the repository is deleted even if it contains images.

## AWS Load Balancer Controller

The AWS Load Balancer Controller lets Kubernetes create and manage AWS load balancers for Services and Ingress resources. The following steps configure IAM permissions, install the controller, and expose the Go application through an AWS Network Load Balancer (NLB).

### 1. Create the IAM policy

Download the AWS Load Balancer Controller IAM policy:

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
```

Create the customer-managed IAM policy:

```bash
aws iam create-policy \
  --policy-name AmazonEKSLoadBalancerControllerPolicy \
  --policy-document file://iam_policy.json
```

The policy grants the controller permission to create and manage the AWS load balancing resources required by Kubernetes.

### 2. Create IAM OIDC Provider associated with the EKS cluster

Before creating the IAM ServiceAccount, ensure that your EKS cluster has an OIDC provider associated with it. You can create it using `eksctl`:

```bash
eksctl utils associate-iam-oidc-provider \
  --region <region> \
  --cluster <cluster_name> \
  --approve
```

### 3. Create the IAM ServiceAccount with `eksctl`

Create the IAM role and Kubernetes ServiceAccount together:

```bash
eksctl create iamserviceaccount \
  --cluster <cluster_name> \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/AmazonEKSLoadBalancerControllerPolicy \
  --approve
```

This creates the following trust chain:

```text
Kubernetes ServiceAccount
        |
        | IRSA annotation
        v
IAM Role
        |
        v
AmazonEKSLoadBalancerControllerPolicy
```

`eksctl` also creates a CloudFormation stack to manage the IAM ServiceAccount resources.

### 4. Install the controller with Helm

Add and update the AWS EKS Helm repository:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

Install the AWS Load Balancer Controller:

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster_name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

The `serviceAccount.create=false` and `serviceAccount.name=aws-load-balancer-controller` options tell Helm to use the ServiceAccount that `eksctl` already created.

### 5. Verify the controller

Check the controller Deployment:

```bash
kubectl get deployment \
  aws-load-balancer-controller \
  -n kube-system
```

Check the system Pods:

```bash
kubectl get pods -n kube-system
```

The controller should be running inside the EKS cluster before an application Service is created.

## 6. EKS Deployment

### 6.1 Generating and Deploying the Secret

The application reads its config from a Kubernetes Secret generated by `kustomize` from `hello-world/config/server.config.toml`. This generated file (`secret.yaml`) is gitignored (see `*/secret.yaml` in `.gitignore`) because it contains sensitive data, so it must be regenerated locally whenever the config file changes.

Generate the secret manifest:

```bash
kubectl kustomize ./hello-world/ > ./hello-world/secret.yaml
```

`kustomize`'s `secretGenerator` names the Secret with the `app-credentials` prefix plus a unique content hash suffix (for example, `app-credentials-57btd956m2`). Whenever `server.config.toml` changes and you regenerate the file, a new hash suffix is produced, so this command must be re-run any time the config changes.

Update `deployment.yaml` with the new secret name: change `spec.template.spec.volumes[].secret.secretName` to match the newly generated hash.

Deploy in this order:

1. Apply the new secret first:

   ```bash
   kubectl apply -f ./hello-world/secret.yaml
   ```

2. Then apply the updated deployment so it references the new secret:

   ```bash
   kubectl apply -f ./hello-world/deployment.yaml
   ```

Once the rollout is confirmed healthy, clean up old secrets:

```bash
kubectl get secrets
```

Delete secrets that are no longer referenced by any Deployment, but keep the second-to-last one around for rollback purposes (its hash can be found from the previous version of `deployment.yaml` in git history) before removing it too.

### 6.2 Initial Deployment

In the ./hello-world directory, you will find the Kubernetes deployment files required to deploy the application to an EKS cluster.

To deploy the application, you can use the following commands:

```bash
kubectl apply -f ./hello-world/deployment.yaml
```

This will create the deployment and service in your EKS cluster, making the application accessible according to the service configuration.

### 6.3 Updating the Deployment

#### 1. Update the Image Version

If you have made changes to the application and built a new Docker image, you will need to update the image version in the deployment YAML file. For example, update the `image` field in `deployment.yaml` to the new version:

```yaml
        image: 107503902849.dkr.ecr.ap-southeast-1.amazonaws.com/hello-world-go:1.3.0
```

#### 2. Apply the Updated Deployment

After updating the image version, apply the changes to the EKS cluster using the following command:

```bash
kubectl apply -f ./hello-world/deployment.yaml
```

This will update the deployment with the new image version, and Kubernetes will handle rolling out the changes to the pods.

#### 3. Verify the Deployment

You can verify that the deployment has been updated and the new pods are running using the following command:

```bash
kubectl get pods -l app=hello-world-go
```

This will list all the pods associated with the `hello-world-go` application, allowing you to confirm that the new pods are running with the updated image.

You can also check the rollout status of the deployment to ensure that it has been successfully updated:

```bash
kubectl rollout status deployment/hello-world-go
```

This command will provide information about the progress of the deployment update and confirm when it has been successfully rolled out.

### 6.4 Rollback Deployment

If you encounter issues with the new deployment, you can rollback to the previous version using the following command:

```bash
kubectl rollout undo deployment/hello-world-go
```

This will revert the deployment to the previous stable version, ensuring that your application remains available.

### 6.5 Deleting the Deployment

If you no longer need the deployment, you can delete it using the following command:

```bash
kubectl delete -f ./hello-world/deployment.yaml
```

This will remove the deployment and associated pods from your EKS cluster.

### 6.6 Exposing the application through an AWS Load Balancer

The application manifest defines a Kubernetes `Service` with `type: LoadBalancer`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-world-go-lbc
spec:
  type: LoadBalancer
  selector:
   app: hello-world-go-lbc
  ports:
   - port: 80
    targetPort: 8080
```

Apply the application manifest:

```bash
kubectl apply -f ./hello-world/deployment.yaml
```

The request flow is:

```text
kubectl apply
    |
    v
Kubernetes Service (type: LoadBalancer)
    |
    v
AWS Load Balancer Controller
    |
    v
AWS Network Load Balancer
    |
    v
NLB DNS hostname
```

Check the Service until an external hostname is assigned:

```bash
kubectl get svc
```

The output should include an AWS load balancer hostname in the `EXTERNAL-IP` column, similar to:

```text
NAME                 TYPE           CLUSTER-IP       EXTERNAL-IP
hello-world-go-lbc   LoadBalancer   10.100.79.82     k8s-default-hellowor-....elb.ap-southeast-1.amazonaws.com
```

External traffic then follows this path:

```text
Internet
  |
  v
AWS Network Load Balancer
  |
  v
Kubernetes Service hello-world-go-lbc:80
  |
  v
Pod
  |
  v
Container
```

The application is available at the assigned hostname:

```text
http://<your-aws-load-balancer-hostname>.elb.ap-southeast-1.amazonaws.com
```

## Final cleanup check

Please review the output of the above commands to ensure that all resources have been properly cleaned up. Remaining resources, if any, should be manually deleted to avoid unnecessary charges (some resources may incur costs even when not actively used).

### EC2 instances

```bash
aws ec2 describe-instances \
  --region ap-southeast-1 \
  --filters Name=instance-state-name,Values=running
```

### Load Balancers

```bash
aws elbv2 describe-load-balancers \
  --region ap-southeast-1
```

### NAT Gateways

```bash
aws ec2 describe-nat-gateways \
  --region ap-southeast-1
```

### EKS Clusters

```bash
aws eks list-clusters \
  --region ap-southeast-1
```

### ECR Repositories

```bash
aws ecr describe-repositories \
  --region ap-southeast-1
```

### LoadBalancer Service

When the experiment is complete, delete the Service to remove the AWS load balancer:

```bash
kubectl delete svc hello-world-go-lbc
```

### EKS cluster

### ⚠️ Important: Delete LoadBalancer Services Before Deleting the Cluster

Before deleting the EKS cluster, find and remove every Kubernetes Service with `type: LoadBalancer`. These Services may have created AWS load balancers such as NLBs.

List Services across all namespaces:

```bash
kubectl get svc -A
```

Delete each Service whose `TYPE` is `LoadBalancer`:

```bash
kubectl delete svc <service-name> -n <namespace>
```

For example:

```bash
kubectl delete svc hello-world-go-lbc
```

Verify that the AWS load balancer has disappeared before continuing:

```bash
aws elbv2 describe-load-balancers \
  --region ap-southeast-1 \
  --query 'LoadBalancers[].LoadBalancerName' \
  --output table
```

If the load balancer is still present, wait and check again. Deleting the cluster while it still exists can prevent the VPC subnets or VPC from being removed and may cause CloudFormation deletion to fail.

Only after the load balancer is gone should you delete the cluster:

```bash
eksctl delete cluster --name basic-cluster --wait
```

The dependency is:

```text
Kubernetes Service (type: LoadBalancer)
  |
  v
AWS Load Balancer
  |
  v
VPC Subnets
  |
  v
VPC
```

> Rule of thumb: Delete the `LoadBalancer` Service, wait for the AWS load balancer to disappear, and then delete the EKS cluster.

When you are ready to remove the entire cluster, run:

```bash
eksctl delete cluster --region <region> --name basic-cluster --disable-nodegroup-eviction
```

The `eksctl`-managed IAM ServiceAccount and CloudFormation resources can then be cleaned up as part of the cluster teardown.
