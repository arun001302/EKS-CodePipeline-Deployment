# Java CI/CD Pipeline on AWS EKS

This is my personal walkthrough of how I successfully set up a complete CI/CD pipeline to deploy a Java Spring Boot app onto Amazon EKS. 

---

## 1. Preparing My Environment

### Tools I Installed on CloudShell
The first thing I did was make sure I had the right tools in **AWS CloudShell**.  
I installed the following:

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

## 2. Creating My EKS Cluster

I created the cluster with:

```bash
eksctl create cluster   --name java-ci-cd-cluster   --region us-east-1   --nodegroup-name workers   --node-type t3.medium   --nodes 2
```

This gave me a running EKS cluster. I also verified it with:

```bash
kubectl get nodes
```

---

## 3. Setting Up ECR

I created an **ECR repository** to store my Docker images:

```bash
aws ecr create-repository   --repository-name java-ci-cd-app   --region us-east-1
```

The repo URI looked like:

```
914261932225.dkr.ecr.us-east-1.amazonaws.com/java-ci-cd-app
```

---

## 4. Configuring CodePipeline & CodeBuild

### Buildspec File

I created a `buildspec.yml` in my repo root:

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
      - helm upgrade --install java-ci-cd-app ./helm         --set image.repository=${ECR_REPO}         --set image.tag=${IMAGE_TAG}
```

I made sure **privileged mode** was enabled in CodeBuild to allow Docker.

---

## 5. Project Structure

Here’s the folder structure I used:

```
my-java-app/
├── src/
│   └── main/java/com/example/demo/DemoApplication.java
├── pom.xml
├── Dockerfile
├── buildspec.yml
└── helm/
    └── Chart.yaml
    └── values.yaml
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

### Helm Chart Example

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
  name: java-ci-cd-app
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: java-ci-cd-app
  template:
    metadata:
      labels:
        app: java-ci-cd-app
    spec:
      containers:
        - name: java-ci-cd-app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: 8080
```

**helm/templates/service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: java-ci-cd-app
spec:
  type: LoadBalancer
  selector:
    app: java-ci-cd-app
  ports:
    - port: 80
      targetPort: 8080
```

---

## 6. Deploying and Testing

Once the pipeline ran successfully, I checked my pods:

```bash
kubectl get pods
```

Then I checked services:

```bash
kubectl get svc
```

I copied the **EXTERNAL-IP** of the LoadBalancer and opened it in my browser.  
The page showed:

```
Hello from EKS!
```

---

## ✅ Final Result

- My Java Spring Boot app was built with Maven.  
- The Docker image was pushed to Amazon ECR.  
- The app was deployed automatically to Amazon EKS using Helm.  
- I could access it via a LoadBalancer URL.

This was the end-to-end CI/CD workflow I implemented today.
