# CI Workflow

The [Docker Image CI workflow](../.github/workflows/app_ci.yaml) builds the
`hello-world-go` image, pushes it to ECR, and records the new image tag in
`hello-world/deployment.yaml`.

The AWS resources the workflow needs are created by the separate
[`terraform-ci/`](../terraform-ci) configuration. It contains only the ECR
repository and the GitHub OIDC role, so you can run CI and debug the workflow
without paying for the EKS cluster, NAT Gateway, and nodes in `terraform/`.

## Workflow overview

Triggers:

- a push to `main` that changes files under `hello-world/` or the workflow file
  itself;
- a pull request to `main` that changes files under `hello-world/`; this only
  runs the `build-check` job;
- a manual run from the Actions tab (`workflow_dispatch`), useful for debugging.

| Job | Purpose |
|-----|---------|
| `build-check` | Pull requests only. Builds the image to catch Dockerfile or compile errors. Uses no AWS access, pushes nothing, and needs no environment or secrets. |
| `build` | Assumes the AWS role through OIDC, builds the image tagged with the commit SHA, and pushes it to ECR. |
| `commit` | Updates the `image:` line in `hello-world/deployment.yaml` and pushes the commit as a GitHub App bot. |

Details:

- Both jobs run in the GitHub environment `main`. The IAM trust policy is
  scoped to that environment name.
- The AWS role ARN and region are read from [config/aws.json](../config/aws.json).
- The ECR repository name is read from `hello-world/deployment.config.json`.
- `hello-world/config/ci.config.toml` is copied over `local.config.toml` so the
  image embeds a placeholder token instead of a real one.
- The bot commit message contains `[skip ci]`, and both jobs skip runs whose
  actor is `commit-bot-1234[bot]`, which prevents a loop.
- Third-party actions are pinned to full commit SHAs (the version is in a
  trailing comment). [Dependabot](../.github/dependabot.yml) opens weekly PRs
  that bump the actions, Go modules, Docker base image, and Terraform providers.
  Review the PRs, since the `build-check` job validates the image build.
- Runs are serialized per ref (`concurrency`) and never cancelled mid-push.

## Create the CI AWS resources

Prerequisites are the same as in the [Terraform setup](terraform-setup.md#prerequisites).

```bash
cd terraform-ci
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- `provider_assume_role_arn`: IAM role Terraform assumes.
- `github_username`, `github_user_id`: from
  `curl -s https://api.github.com/users/<username> | jq .id`.
- `github_repository`, `github_repository_id`: from
  `curl -s https://api.github.com/repos/<username>/<repository> | jq .id`.
- `environment_name`: the GitHub environment used by the workflow (`main`).

Then, from `terraform-ci/`, follow the
[standard Terraform workflow](terraform-setup.md#standard-terraform-workflow)
(`init`, `validate`, `plan -out`, review, `apply` the saved plan, then `fmt`).

Terraform creates:

- the `hello-world-go` ECR repository (force delete enabled, keeps the last 30
  images);
- the GitHub OIDC identity provider;
- the `github-actions-role` IAM role, assumable only by this repository and
  environment, with permission to push images to that repository.

The OIDC provider is unique per AWS account. If one already exists, import it
(`terraform import aws_iam_openid_connect_provider.github <arn>`) instead of
creating another.

## Configure GitHub

1. Copy the `aws_config` output into [config/aws.json](../config/aws.json):

   ```bash
   terraform output -json aws_config > ../config/aws.json
   ```

   Commit the file. It contains no secrets.
2. Create a GitHub environment named `main` (Settings > Environments).
3. Create a GitHub App that can write repository contents, install it on the
   repository, and add to the `main` environment:
   - variable `COMMIT_BOT_APP_ID`
   - secret `COMMIT_BOT_PRIVATE_KEY`
4. If branch protection blocks pushes to `main`, allow the app to bypass it.

## Troubleshooting

- **"Not authorized to perform sts:AssumeRoleWithWebIdentity":** the trust
  policy does not match the run. Check that `environment_name`, the GitHub
  username/repository and their IDs in `terraform-ci/terraform.tfvars` match the
  workflow, and that the job uses `environment: main`.
- **"Could not load credentials" or an unknown role:** `config/aws.json` holds a
  stale role ARN, usually after `terraform-ci/` was destroyed and recreated or
  applied in another account. Re-run `terraform output -json aws_config`.
- **ECR push fails with "repository does not exist":** `terraform-ci/` was
  destroyed or the repository name in `hello-world/deployment.config.json`
  changed.
- **The `commit` job fails creating the app token or pushing:** check the
  `COMMIT_BOT_APP_ID` variable and `COMMIT_BOT_PRIVATE_KEY` secret in the `main`
  environment, and branch protection bypass for the app.

## Cost-saving workflow

- **Only practicing or debugging CI:** apply only `terraform-ci/`. Do not
  create the EKS stack.
- **Deploying to the cluster:** apply `terraform/` as well, then destroy it when
  finished. Keep `terraform-ci/` (ECR and IAM are essentially free) so the
  workflow keeps working and images are preserved.
- **Full cleanup:** destroy `terraform/` first, then `terraform-ci/`. Destroying
  `terraform-ci/` deletes the ECR repository and all its images, and the role ARN
  in `config/aws.json` becomes invalid.

The two stacks have independent state, so destroying one does not affect the
other. If you recreate `terraform-ci/`, the role ARN usually stays the same, but
re-check `config/aws.json`.
