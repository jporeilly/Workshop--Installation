# =============================================================================
# Pentaho Server 11 Docker Image (Oracle Repository)
# =============================================================================
#
# Multi-stage Dockerfile for Pentaho Server 11.0.0.0-237 Enterprise Edition
# Configured to use Oracle database for repository
#
# Base Image: debian:trixie-slim (official Debian from Docker Hub)
# Java: OpenJDK 21 JRE (headless)
# User: pentaho (UID 5000, non-root for security)
#
# Build: docker compose build pentaho-server
# Run:   docker compose up -d pentaho-server
#
# =============================================================================

# Global build arguments (available to all stages)
ARG INSTALLATION_PATH=/opt/pentaho
ARG PENTAHO_VERSION
ARG PENTAHO_SERVER_PATH=${INSTALLATION_PATH}/pentaho-server

# Base image: Using official Debian Trixie Slim from Docker Hub
ARG UNPACK_BUILD_IMAGE=debian:trixie-slim
ARG PACK_BUILD_IMAGE=debian:trixie-slim

FROM ${UNPACK_BUILD_IMAGE} AS install_unpack

LABEL maintainer="Hitachi Vantara"
LABEL version="11.x"
LABEL description="Dockerfile for Pentaho Server with Oracle Repository"

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

# Validate if main software package is available
RUN if [ ! -f "${INSTALLER_PATH}/${FILE_SOFTWARE}" ]; \
        then \
        echo "File ${FILE_SOFTWARE} Not Found in predownloaded folder, please download required artifact and copy to predownloaded folder"; exit 2; \
    fi;

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

FROM ${PACK_BUILD_IMAGE} AS pack

# Re-declare arguments for this stage
ARG INSTALLATION_PATH
ARG PENTAHO_VERSION
ARG PENTAHO_SERVER_PATH=${INSTALLATION_PATH}/pentaho-server

# =============================================================================
# User Configuration
# =============================================================================
ENV PENTAHO_UID=5000
ENV PENTAHO_USER=pentaho
ENV PENTAHO_HOME=/home/pentaho
ENV PENTAHO_SERVER_PATH=${PENTAHO_SERVER_PATH}
ENV PATH="${PENTAHO_SERVER_PATH}:${PATH}"
ENV PENTAHO_VERSION=${PENTAHO_VERSION}
ENV INSTALLATION_PATH=${INSTALLATION_PATH}

# Create user for non-root account
RUN groupadd --gid ${PENTAHO_UID} ${PENTAHO_USER} \
    && useradd --home-dir ${PENTAHO_HOME} --create-home --uid ${PENTAHO_UID} \
    --gid ${PENTAHO_UID} --shell /bin/bash --skel /dev/null ${PENTAHO_USER}

# Install pending updates
RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get autoremove -y \
    && apt-get clean

# Install Java OpenJDK 21 and curl (required for container health checks)
RUN apt-get update && \
    apt-get install -y openjdk-21-jre-headless curl && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Skip WebKit GTK check for headless server
ENV SKIP_WEBKITGTK_CHECK=1

# Use installed software from installation base and assign non-elevated-privileges user
COPY --from=install_unpack --chown=${PENTAHO_USER}:${PENTAHO_USER} ${INSTALLATION_PATH}/ ${INSTALLATION_PATH}/

# =============================================================================
# Entrypoint Configuration
# =============================================================================
COPY ./entrypoint/ /

# Set working directory to Pentaho Server root
WORKDIR ${PENTAHO_SERVER_PATH}

# =============================================================================
# JVM and Port Configuration
# =============================================================================
ENV PENTAHO_DI_JAVA_OPTIONS="-Dfile.encoding=utf8 "

# Exposed ports:
#   8080 - HTTP (Pentaho Web UI and REST API)
#   8443 - HTTPS (secure access when SSL configured)
EXPOSE 8080
EXPOSE 8443

# =============================================================================
# Runtime Configuration
# =============================================================================
USER ${PENTAHO_USER}

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["./start-pentaho.sh"]
