# Multi-stage Dockerfile for Java application

# Stage 1: Build stage
FROM maven:3.9-eclipse-temurin-17 AS builder

WORKDIR /app

# Copy pom.xml first to leverage Docker cache
COPY pom.xml .

# Download dependencies
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Stage 2: Runtime stage
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Install debugging utilities
RUN apk add --no-cache curl wget bind-tools netcat-openbsd busybox-extras

# Copy the built JAR from the builder stage
COPY --from=builder /app/target/demo-app-java-*.jar /app/app.jar

# Create a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Expose port (if needed for health checks)
EXPOSE 8080

# Run the application with logging options
# -Djava.util.logging.manager=org.jboss.logmanager.LogManager ensures logs go to stdout
ENTRYPOINT ["java", "-Xms128m", "-Xmx256m", "-jar", "/app/app.jar"]
