# Stage 1: Build the WAR
FROM maven:3.9.6-eclipse-temurin-17 AS builder
WORKDIR /app
COPY webapp/pom.xml webapp/pom.xml
COPY webapp/src webapp/src
RUN cd webapp && mvn clean package -DskipTests

# Stage 2: Run in Tomcat
FROM tomcat:10-jdk17-openjdk-slim
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=builder /app/webapp/target/*.war /usr/local/tomcat/webapps/webapp.war
EXPOSE 8080
CMD ["catalina.sh", "run"]
