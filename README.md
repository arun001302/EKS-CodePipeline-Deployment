# End-to-End Java CI/CD Pipeline on AWS (EKS + CodePipeline + CodeBuild + ECR + Helm)

This guide walks through the exact **steps I successfully completed** to set up a CI/CD pipeline that deploys a Java Spring Boot application to Amazon EKS using AWS CodePipeline, CodeBuild, ECR, and Helm.

---

## ✅ Prerequisites
- AWS account with admin permissions
- IAM roles for CodePipeline and CodeBuild
- EKS cluster created and `kubectl` configured
- Docker installed locally (optional for testing)
- GitHub repository containing:
  - Java Spring Boot app
  - `Dockerfile`
  - `helm/` chart
  - `buildspec.yml`

---

## 1. Create ECR Repository
```bash
aws ecr create-repository --repository-name java-ci-cd-app --region us-east-1
```
Repository URI example:
```
914261932225.dkr.ecr.us-east-1.amazonaws.com/java-ci-cd-app
```

---

## 2. Configure CodePipeline (GitHub → CodeBuild → EKS)
1. Go to **AWS CodePipeline** → Create Pipeline.
2. **Source stage**:
   - Provider: GitHub (via CodeStar connection)
   - Repository: `EKS-CodePipeline-Deployment`
   - Branch: `main`
   - Output format: *CodePipeline default*
3. **Build stage**:
   - Provider: AWS CodeBuild
   - Project: `JavaApp-CodeBuild`
   - Input: `SourceArtifact`

---

## 3. CodeBuild Project Setup
- Runtime: `aws/codebuild/standard:6.0` (supports Docker + Java 17)
- Environment: **Privileged mode enabled** (for Docker-in-Docker)
- Service Role: Must allow access to ECR, S3, CloudWatch, EKS.

---

## 4. `buildspec.yml` File
Working version:

```yaml
version: 0.2
env:
  variables:
    REGION: "us-east-1"
    CLUSTER_NAME: "java-ci-cd-cluster"
    ECR_REPO: "914261932225.dkr.ecr.us-east-1.amazonaws.com/java-ci-cd-app"

phases:
  install:
    runtime-versions:
      java: corretto17
    commands:
      - set -euxo pipefail
      - echo "Installing Helm..."
      - curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      - helm version

  pre_build:
    commands:
      - set -euxo pipefail
      - echo "== PRE_BUILD =="
      - docker --version
      - REGISTRY=$(echo ${ECR_REPO} | cut -d'/' -f1)
      - aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${REGISTRY}
      - IMAGE_TAG=$(echo ${CODEBUILD_RESOLVED_SOURCE_VERSION:-$(date +%Y%m%d-%H%M%S)} | cut -c1-7)
      - echo "IMAGE_TAG=${IMAGE_TAG}"

  build:
    commands:
      - set -euxo pipefail
      - echo "== BUILD =="
      - docker build -t ${ECR_REPO}:${IMAGE_TAG} .
      - docker push ${ECR_REPO}:${IMAGE_TAG}

  post_build:
    commands:
      - echo "== POST_BUILD =="
      - aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}
      - helm upgrade --install java-ci-cd-app ./helm --set image.repository=${ECR_REPO} --set image.tag=${IMAGE_TAG}
```

---

## 5. Helm Chart Structure
```
helm/
 └── templates/
     ├── deployment.yaml
     ├── service.yaml
     └── _helpers.tpl
 └── values.yaml
```

- `values.yaml` must use:
```yaml
image:
  repository: ""
  tag: ""
```

---

## 6. Deploy and Verify
After a successful pipeline run:
```bash
kubectl get pods
kubectl get svc
```

Check logs:
```bash
kubectl logs deployment/java-ci-cd-app
```

---

## 7. Access the Application
- Get the **LoadBalancer External IP**:
```bash
kubectl get svc java-ci-cd-app
```
- Open in browser:
```
http://<external-dns>
```
✅ You should see:
```
Hello from EKS!
```

---

## 🎉 Success!
You now have:
- A working **CI/CD pipeline**
- Automatic Docker image builds + pushes to **ECR**
- Automated **Helm deployment** to EKS
- Public access via **LoadBalancer URL**
