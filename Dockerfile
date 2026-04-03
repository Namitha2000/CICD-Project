# Stage 1: Build the WAR
FROM maven:3.9.6-eclipse-temurin-17 AS builder
WORKDIR /app

# Copy parent pom first
COPY pom.xml pom.xml

# Copy webapp module
COPY webapp/pom.xml webapp/pom.xml
COPY webapp/src webapp/src

# Build
RUN mvn clean package -DskipTests -pl webapp

# Stage 2: Run in Tomcat
FROM tomcat:10-jdk17-openjdk-slim
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=builder /app/webapp/target/*.war /usr/local/tomcat/webapps/webapp.war
EXPOSE 8080
CMD ["catalina.sh", "run"]
