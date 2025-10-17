# Java CI/CD Pipeline on AWS EKS

A complete walkthrough of setting up a CI/CD pipeline to deploy a Java Spring Boot application onto Amazon EKS using AWS CodePipeline, CodeBuild, and Helm.

---

## 1. Environment Setup

### Required Tools (AWS CloudShell)
Install the following tools in AWS CloudShell:

```bash
# Update system
sudo yum update -y

# Install kubectl
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.30.0/2024-07-05/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/

# Verify
kubectl version --client

# Install eksctl
curl --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" -o eksctl.tar.gz
tar -xzf eksctl.tar.gz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Verify
eksctl version

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

---

## 2. Creating the EKS Cluster

Create the cluster with eksctl:

```bash
eksctl create cluster \
  --name <your-cluster-name> \
  --region <your-region> \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 2
```

Verify the cluster is running:

```bash
kubectl get nodes
```

---

## 3. Setting Up ECR

Create an ECR repository to store Docker images:

```bash
aws ecr create-repository \
  --repository-name <your-app-name> \
  --region <your-region>
```

Note the repository URI for later use:
```
<account-id>.dkr.ecr.<region>.amazonaws.com/<repository-name>
```

---

## 4. Configuring CodePipeline & CodeBuild

### Buildspec File

Create a `buildspec.yml` in your repository root:

```yaml
version: 0.2
env:
  variables:
    REGION: "<your-region>"
    CLUSTER_NAME: "<your-cluster-name>"
    ECR_REPO: "<account-id>.dkr.ecr.<region>.amazonaws.com/<repository-name>"

phases:
  install:
    runtime-versions:
      java: corretto17
    commands:
      - echo "Installing Docker..."
      - nohup /usr/local/bin/dockerd --host=unix:///var/run/docker.sock --host=tcp://127.0.0.1:2375 --storage-driver=overlay2 &
      - timeout 15 sh -c "until docker info; do echo .; sleep 1; done"
      - echo "Installing Helm..."
      - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  pre_build:
    commands:
      - echo "Logging in to Amazon ECR..."
      - REGISTRY=$(echo ${ECR_REPO} | cut -d'/' -f1)
      - aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${REGISTRY}
      - IMAGE_TAG=$(echo ${CODEBUILD_RESOLVED_SOURCE_VERSION:-latest} | cut -c1-7)
      - echo "IMAGE_TAG=${IMAGE_TAG}"

  build:
    commands:
      - echo "Building Docker image..."
      - docker build -t ${ECR_REPO}:${IMAGE_TAG} .
      - docker push ${ECR_REPO}:${IMAGE_TAG}

  post_build:
    commands:
      - echo "Deploying with Helm..."
      - aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}
      - helm upgrade --install <your-app-name> ./helm \
        --set image.repository=${ECR_REPO} \
        --set image.tag=${IMAGE_TAG}
```

**Important:** Enable **privileged mode** in your CodeBuild project settings to allow Docker operations.

---

## 5. Project Structure

```
my-java-app/
├── src/
│   └── main/java/com/example/demo/DemoApplication.java
├── pom.xml
├── Dockerfile
├── buildspec.yml
└── helm/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── deployment.yaml
        └── service.yaml
```

### Dockerfile

```dockerfile
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn package -DskipTests

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Helm Chart Configuration

**helm/values.yaml**
```yaml
replicaCount: 1

image:
  repository: ""
  tag: "latest"
  pullPolicy: Always

service:
  type: LoadBalancer
  port: 80
```

**helm/templates/deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: 8080
```

**helm/templates/service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ .Chart.Name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 8080
```

---

## 6. Deploying and Testing

Once the pipeline runs successfully, check your pods:

```bash
kubectl get pods
```

Check services to get the LoadBalancer URL:

```bash
kubectl get svc
```

Access your application using the **EXTERNAL-IP** of the LoadBalancer service.

---

## Architecture Overview

- **Java Spring Boot** application built with Maven
- **Docker** image pushed to Amazon ECR
- **Automated deployment** to Amazon EKS using Helm
- **LoadBalancer** service for external access
- **CI/CD** pipeline using AWS CodePipeline and CodeBuild

---

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured
- Git repository for source code
- Basic knowledge of Kubernetes and Docker

## Next Steps

Consider adding:
- Monitoring with CloudWatch or Prometheus
- Ingress controller for better routing
- Auto-scaling configurations
- Multiple environments (dev, staging, prod)
- Secrets management with AWS Secrets Manager or Kubernetes Secrets
