# Application Deployment

This guide deploys the `hello-world-go` application to an EKS cluster. It assumes
the cluster and the `hello-world-go` ECR repository already exist, and that
`kubectl` is configured to access the target cluster.

Replace `<region>`, `<account-id>`, and `<version>` with values for your AWS
account and release. Use a specific image version, such as `1.5.0`, rather than
`latest`.

## 1. Generate and deploy the application Secret

The Secret is generated from `hello-world/config/server.config.toml`. That file
and the generated `hello-world/secret.yaml` contain sensitive configuration and
are gitignored; keep them out of source control.

From the repository root, generate the manifest:

```bash
kubectl kustomize ./hello-world/ > ./hello-world/secret.yaml
```

The generated Secret name includes a content hash, for example
`app-credentials-57btd956m2`. Open `hello-world/secret.yaml` and note its
`metadata.name`; you will use that exact name in `deployment.yaml` below.

Apply the Secret before updating the Deployment:

```bash
kubectl apply -f ./hello-world/secret.yaml
```

If the configuration changes, regenerate and apply the Secret again. The new
content produces a new hashed name, which must also be updated in
`deployment.yaml` before applying the Deployment.

## 2. Build and push the image to ECR

Run these commands from the `hello-world` directory. Authenticate to ECR:

```bash
aws ecr get-login-password --region <region> |
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
```

Build, tag, and push the image with Docker:

```bash
docker build -t hello-world-go:<version> .
docker tag hello-world-go:<version> <account-id>.dkr.ecr.<region>.amazonaws.com/hello-world-go:<version>
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/hello-world-go:<version>
```

For Podman, use `podman` in place of `docker` in the login, build, tag, and push
commands. On Windows/WSL, ensure Podman Remote is installed and configured.

Confirm that the pushed tag is in ECR:

```bash
aws ecr describe-images \
  --region <region> \
  --repository-name hello-world-go
```

## 3. Update `deployment.yaml` and deploy

In `hello-world/deployment.yaml`, update both values:

1. Set `spec.template.spec.volumes[].secret.secretName` to the exact hashed name
   from the generated Secret manifest.
2. Set the container's `image` to the image URI and version just pushed, for
   example:

   ```yaml
   image: <account-id>.dkr.ecr.<region>.amazonaws.com/hello-world-go:<version>
   ```

Apply the manifest from the repository root:

```bash
kubectl apply -f ./hello-world/deployment.yaml
```

Wait for the rollout and check the application Pods:

```bash
kubectl rollout status deployment/hello-world-go
kubectl get pods -l app=hello-world-go
```

The manifest also creates the `hello-world-go-lbc` LoadBalancer Service. Check
for its external hostname:

```bash
kubectl get svc hello-world-go-lbc
```

If the new release has problems, roll back the Deployment:

```bash
kubectl rollout undo deployment/hello-world-go
```

Keep the previous Secret available if you may need to roll back to a Deployment
that references it. Remove old Secrets only after confirming they are no longer
needed.
