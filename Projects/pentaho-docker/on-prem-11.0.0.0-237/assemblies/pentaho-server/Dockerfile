# Pentaho Server 11 Dockerfile
# Base image with OpenJDK 21
FROM eclipse-temurin:21-jdk-jammy

# Build arguments
ARG PENTAHO_VERSION=11.0.0.0-237
ARG PENTAHO_HOME=/home/pentaho
ARG INSTALLATION_PATH=/opt/pentaho

# Environment variables
ENV PENTAHO_VERSION=${PENTAHO_VERSION}
ENV PENTAHO_HOME=${PENTAHO_HOME}
ENV INSTALLATION_PATH=${INSTALLATION_PATH}
ENV PENTAHO_SERVER=${INSTALLATION_PATH}/pentaho-server
ENV PENTAHO_JAVA_HOME=/opt/java/openjdk
ENV JAVA_HOME=/opt/java/openjdk

# Create pentaho user and group
RUN groupadd -r pentaho && useradd -r -g pentaho -d ${PENTAHO_HOME} -s /bin/bash pentaho

# Install required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    curl \
    wget \
    fontconfig \
    libfreetype6 \
    fonts-dejavu-core \
    netcat-openbsd \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Add PostgreSQL 17 APT repository and install client
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client-17 \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p ${INSTALLATION_PATH} \
    && mkdir -p ${PENTAHO_HOME}/.kettle \
    && mkdir -p ${PENTAHO_HOME}/.pentaho \
    && mkdir -p /docker-entrypoint-init

# Copy Pentaho Server distribution
COPY stagedArtifacts/pentaho-server-*.zip /tmp/

# Extract Pentaho Server
RUN unzip /tmp/pentaho-server-*.zip -d ${INSTALLATION_PATH} \
    && rm /tmp/pentaho-server-*.zip \
    && chmod +x ${PENTAHO_SERVER}/*.sh \
    && chmod +x ${PENTAHO_SERVER}/tomcat/bin/*.sh

# Copy entrypoint script
COPY entrypoint/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Set ownership
RUN chown -R pentaho:pentaho ${INSTALLATION_PATH} \
    && chown -R pentaho:pentaho ${PENTAHO_HOME} \
    && chown -R pentaho:pentaho /docker-entrypoint-init

# Switch to pentaho user
USER pentaho

# Set working directory
WORKDIR ${PENTAHO_SERVER}

# Expose Pentaho Server port
EXPOSE 8090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8090/pentaho/Login || exit 1

# Entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command - start Pentaho Server
CMD ["./start-pentaho.sh"]
