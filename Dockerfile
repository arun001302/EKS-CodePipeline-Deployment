# Stage 1: Build the application using Maven
FROM openjdk:17-jdk-slim as builder
WORKDIR /app
COPY . .

# Add execute permissions to the Maven Wrapper script
RUN chmod +x ./mvnw

# Now, run the build command
RUN ./mvnw clean package -DskipTests

# Stage 2: Create the final, smaller image
FROM openjdk:17-jdk-slim
WORKDIR /app

# Copy the built JAR from the builder stage
COPY --from=builder /app/target/*.jar app.jar

# Set the entrypoint to run the application
ENTRYPOINT ["java","-jar","app.jar"]
