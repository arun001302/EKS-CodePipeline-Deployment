FROM public.ecr.aws/docker/library/maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn -B -q -e -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -B -DskipTests package

FROM public.ecr.aws/docker/library/eclipse-temurin:17-jre
WORKDIR /app
COPY --from=builder /app/target/demo-*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
