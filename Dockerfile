# Stage 1: Build the application using Maven
FROM openjdk:17-jdk-slim as builder
WORKDIR /app

# Copy only the files needed to download dependencies
COPY .mvn/ .mvn
COPY mvnw pom.xml ./

# Add execute permissions to the Maven Wrapper script
RUN chmod +x ./mvnw

# Download dependencies first. This step is cached if pom.xml doesn't change.
RUN ./mvnw dependency:go-offline

# Copy the rest of the source code
COPY src ./src

# Now, build the application using the downloaded dependencies
RUN ./mvnw clean package -DskipTests

# Stage 2: Create the final, smaller image
FROM openjdk:17-jdk-slim
WORKDIR /app

# Copy the built JAR from the builder stage
COPY --from=builder /app/target/*.jar app.jar

# Set the entrypoint to run the application
ENTRYPOINT ["java","-jar","app.jar"]

