# ---------- Build stage ----------
FROM public.ecr.aws/docker/library/maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app

# Cache deps
COPY pom.xml .
RUN mvn -B -q -DskipTests dependency:go-offline

# Build & repackage an executable (boot) jar
COPY src ./src
RUN mvn -B -DskipTests package spring-boot:repackage

# ---------- Runtime stage ----------
FROM public.ecr.aws/docker/library/eclipse-temurin:17-jre
WORKDIR /app

# Copy the boot jar (has Main-Class in manifest)
COPY --from=builder /app/target/*-SNAPSHOT.jar /app/app.jar
# If your version is not -SNAPSHOT, the glob still matches (e.g., *-0.0.1.jar)

EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
