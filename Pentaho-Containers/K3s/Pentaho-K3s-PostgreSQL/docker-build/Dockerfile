# =============================================================================
# Pentaho Server 11 Docker Image
# =============================================================================
#
# Multi-stage Dockerfile for Pentaho Server 11.0.0.0-237 Enterprise Edition
#
# Base Image: debian:trixie-slim (official Debian from Docker Hub)
# Java: OpenJDK 21 JRE (headless)
# User: pentaho (UID 5000, non-root for security)
#
# Build: docker compose build pentaho-server
# Run:   docker compose up -d pentaho-server
#
# Stages:
#   1. install_unpack - Extracts Pentaho ZIP and optional plugins
#   2. pack - Creates final runtime image with Java and configuration
#
# For more information, see:
#   - README.md - Quick start guide
#   - ARCHITECTURE.md - System design documentation
#   - softwareOverride/README.md - Configuration customization
#
# =============================================================================

# Global build arguments (available to all stages)
ARG INSTALLATION_PATH=/opt/pentaho
ARG PENTAHO_VERSION
ARG PENTAHO_SERVER_PATH=${INSTALLATION_PATH}/pentaho-server

# Base image: Using official Debian Trixie Slim from Docker Hub
# Previously used Hitachi Vantara registry, changed for public accessibility
ARG UNPACK_BUILD_IMAGE=debian:trixie-slim
ARG PACK_BUILD_IMAGE=debian:trixie-slim

FROM ${UNPACK_BUILD_IMAGE} AS install_unpack

LABEL maintainer="Hitachi Vantara"
LABEL version="11.x"
LABEL description="Dockerfile for Pentaho Server"

WORKDIR /opt/pentaho-installer/

#Arguments definition
ARG INSTALLATION_PATH
ARG PENTAHO_SERVER_PATH
ARG INSTALLER_PATH=/opt/pentaho-installer
## Arguments for regular Pentaho Server install
ARG PENTAHO_INSTALLER_NAME=pentaho-server-ee
ARG PENTAHO_VERSION=11.0.0.0-xxx
ARG IS_DEMO=0

ARG FILE_SOFTWARE=${PENTAHO_INSTALLER_NAME}-${PENTAHO_VERSION}.zip
## Arguments related to Pentaho Server plugins
ARG FILE_PAZ=paz-plugin-ee-${PENTAHO_VERSION}.zip
ARG FILE_PIR=pir-plugin-ee-${PENTAHO_VERSION}.zip
ARG FILE_PDD=pdd-plugin-ee-${PENTAHO_VERSION}.zip

#Copy from local predownloaded folder al the artifacts required for Pentaho installation
COPY ./stagedArtifacts/* ${INSTALLER_PATH}/

RUN apt-get update && \
    apt-get install -y unzip && \
    rm -rf /var/lib/apt/lists/*

##########################################
# Here comes the GA Install part
##########################################
#
# First, It validates if main software package (version release) is available or stop the process asking for file if not there
RUN if [ ! -f "${INSTALLER_PATH}/${FILE_SOFTWARE}" ]; \
        then \
        echo "File ${FILE_SOFTWARE} Not Found in predownloaded folder, please download required artifact and copy to predownloaded folder"; exit 2; \
    fi;

# Additional unpack logic placeholder - do not remove or change
# Where is the Install of extra packs for unpack? do we have a large image for build and same to run?

# UNZIP and INSTALL the Pentaho server
RUN mkdir -p ${INSTALLATION_PATH}; \
    unzip ${FILE_SOFTWARE} -d ${INSTALLATION_PATH};

# Remove promptUser.sh
RUN rm -f ${PENTAHO_SERVER_PATH}/promptuser.sh || true;

# UNZIP and INSTALL plugins
RUN if [ -f "${FILE_PAZ}" ]; \
    then \
      unzip -o ${FILE_PAZ} -d ${PENTAHO_SERVER_PATH}/pentaho-solutions/system; \
    fi;

RUN if [ -f "${FILE_PIR}" ]; \
    then \
      unzip -o ${FILE_PIR} -d ${PENTAHO_SERVER_PATH}/pentaho-solutions/system; \
    fi;

RUN if [ -f "${FILE_PDD}" ]; \
    then \
      unzip -o ${FILE_PDD} -d ${PENTAHO_SERVER_PATH}/pentaho-solutions/system; \
    fi;

# Remove default-content
RUN if [ "${IS_DEMO}" -eq "0" ]; \
    then \
      rm -rf ${PENTAHO_SERVER_PATH}/pentaho-solutions/system/default-content/*; \
    fi;

# =============================================================================
# STAGE 2: pack - Final Runtime Image
# =============================================================================
#
# This stage creates the final production image:
#   - Fresh Debian base with security updates
#   - OpenJDK 21 JRE for running Pentaho
#   - Non-root user (pentaho, UID 5000) for security
#   - Pentaho installation from Stage 1
#   - Entrypoint scripts for configuration overlay
#
# =============================================================================

FROM ${PACK_BUILD_IMAGE} AS pack

# Re-declare arguments for this stage
ARG INSTALLATION_PATH
ARG PENTAHO_VERSION
ARG PENTAHO_SERVER_PATH=${INSTALLATION_PATH}/pentaho-server

# =============================================================================
# User Configuration
# =============================================================================
# Create non-root user for running Pentaho (security best practice)
# UID 5000 is used to avoid conflicts with common system users
ENV PENTAHO_UID=5000
ENV PENTAHO_USER=pentaho
ENV PENTAHO_HOME=/home/pentaho
# Ensure PENTAHO_SERVER_PATH is set correctly
ENV PENTAHO_SERVER_PATH=${PENTAHO_SERVER_PATH}
ENV PATH="${PENTAHO_SERVER_PATH}:${PATH}"
ENV PENTAHO_VERSION=${PENTAHO_VERSION}
ENV INSTALLATION_PATH=${INSTALLATION_PATH}


# Create user for non-root account
RUN groupadd --gid ${PENTAHO_UID} ${PENTAHO_USER} \
    && useradd --home-dir ${PENTAHO_HOME} --create-home --uid ${PENTAHO_UID} \
    --gid ${PENTAHO_UID} --shell /bin/bash --skel /dev/null ${PENTAHO_USER}
# RUN echo 'pentaho ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Install pending updates
RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get autoremove -y \
    && apt-get clean

# Install Java OpenJDK 21 and curl (required for container health checks)
RUN apt-get update && \
    apt-get install -y openjdk-21-jre-headless curl && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

#Default to Windows host, please override for other cases
#ENV DISPLAY=host.docker.internal:0

#This Setting is to skipe WEB TOOLKIT GTK Check. Since the use of this mack normally does no use GUI.
# If you want GUI, then istall libwebkitgtk-1.0-0 as the line commented above
ENV SKIP_WEBKITGTK_CHECK=1

# Use installed software from installation base and assign non-elevated-privileges user in destination path
COPY --from=install_unpack --chown=${PENTAHO_USER}:${PENTAHO_USER} ${INSTALLATION_PATH}/ ${INSTALLATION_PATH}/

# =============================================================================
# Entrypoint Configuration
# =============================================================================
# Copy entrypoint scripts from docker/entrypoint/ directory
# The entrypoint script handles:
#   - JVM configuration (memory, encoding)
#   - Processing softwareOverride directories
#   - License installation (if LICENSE_URL is set)
#   - Starting Pentaho Server
COPY ./entrypoint/ /

# Copy softwareOverride directory (K3s-specific: baked into image)
# Docker Compose mounts this as a volume, but for K3s we bake it in
# Contains: database configs, JDBC drivers, modified startup.sh
COPY --chown=${PENTAHO_USER}:${PENTAHO_USER} ./softwareOverride /docker-entrypoint-init

# Set working directory to Pentaho Server root
WORKDIR ${PENTAHO_SERVER_PATH}

# =============================================================================
# JVM and Port Configuration
# =============================================================================
# Default JVM options for Pentaho Data Integration
ENV PENTAHO_DI_JAVA_OPTIONS="-Dfile.encoding=utf8 "

# Exposed ports:
#   8080 - HTTP (Pentaho Web UI and REST API)
#   8443 - HTTPS (secure access when SSL configured)
EXPOSE 8080
EXPOSE 8443

# =============================================================================
# Runtime Configuration
# =============================================================================
# Run as non-root pentaho user for security
USER ${PENTAHO_USER}

# Entrypoint processes configuration and starts Pentaho
# See docker/entrypoint/docker-entrypoint.sh for details
ENTRYPOINT ["/docker-entrypoint.sh"]

# Default command: Start Pentaho Server via Tomcat
CMD ["./start-pentaho.sh"]
