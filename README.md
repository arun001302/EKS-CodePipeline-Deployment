# Java CI/CD Sample (Spring Boot) for EKS + CodePipeline

This is a minimal Spring Boot app that listens on port 8080 and returns `Hello from EKS!`.
Use it to unblock your pipeline. It builds with Maven inside the Docker build (no mvnw needed).

## Files
- `Dockerfile` — multi-stage build using Maven base image.
- `pom.xml` — Spring Boot 3 + Java 17.
- `src/main/java/com/example/demo/DemoApplication.java` — main app with one GET endpoint `/`.
