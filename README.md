# Workshop--Installation

This repository contains various deployment projects and configurations for Pentaho Server and related tools.

## Projects

### Pentaho Server 11 with MySQL (Ubuntu 24.04)

**Location**: [`pentaho-mysql-ubuntu/`](./pentaho-mysql-ubuntu/)

Complete, standalone Docker Compose deployment for **Pentaho Server 11.0.0.0-237** with **MySQL 8.0** repository on Ubuntu 24.04 LTS.

**Features**:
- Self-contained and portable deployment
- Automated database initialization (5 MySQL databases)
- Health checks and proper startup ordering
- Persistent data volumes
- Production-ready configuration templates
- Comprehensive documentation

**Quick Start**:
```bash
cd pentaho-mysql-ubuntu
# Place pentaho-server-ee-11.0.0.0-237.zip in docker/stagedArtifacts/
./deploy.sh
```

**Access**:
- Pentaho Server: http://localhost:8080/pentaho (admin/password)
- Adminer: http://localhost:8050 (database admin)

For complete documentation, see [pentaho-mysql-ubuntu/README.md](./pentaho-mysql-ubuntu/README.md)

---

## Reference Projects

### Pentaho-Docker

Original Pentaho Docker build project with multi-cloud distribution configurations.

**Location**: [`Pentaho-Docker/`](./Pentaho-Docker/)

### MySQL

MySQL Docker reference implementation.

**Location**: [`MySQL/`](./MySQL/)

### Database Drivers

JDBC drivers for various databases.

**Location**: [`Database Drivers/`](./Database%20Drivers/)

---

## Repository Structure

```
Workshop--Installation/
├── pentaho-mysql-ubuntu/      # Standalone Pentaho 11 + MySQL deployment (Ubuntu 24.04)
│   ├── docker-compose.yml     # Service orchestration
│   ├── deploy.sh              # Automated deployment
│   ├── README.md              # Complete deployment guide
│   └── ...                    # All necessary configs and scripts
│
├── Pentaho-Docker/            # Reference: Pentaho Docker build project
├── MySQL/                     # Reference: MySQL Docker implementation
├── Database Drivers/          # JDBC drivers repository
└── README.md                  # This file
```

---

## Getting Started

### Prerequisites

- Docker Engine 20.10+
- Docker Compose V2+
- Ubuntu 24.04 LTS (or compatible Linux distribution)
- 8GB+ RAM, 20GB+ disk space

### Installation

1. Clone or navigate to this repository
2. Choose a project (recommended: `pentaho-mysql-ubuntu/`)
3. Follow the project-specific README for deployment instructions

---

## Documentation

Each project contains its own comprehensive documentation:

- **pentaho-mysql-ubuntu/README.md** - Complete deployment guide with troubleshooting, backup/restore, and security best practices

---

## License

These deployment configurations are provided as-is. Pentaho Server requires appropriate licensing from Hitachi Vantara for enterprise features.

---

## Support

For project-specific issues, refer to the individual project README files.

For general questions or contributions, open an issue in this repository.
