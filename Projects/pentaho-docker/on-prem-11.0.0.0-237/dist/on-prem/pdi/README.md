# On-Prem Pentaho Data Integration Docker Project

This project provides a Docker setup for Pentaho Data Integration (PDI). The setup includes Dockerfiles, Docker Compose configurations, and necessary scripts to build and run PDI in a containerized environment.

## Project Structure

### `assemblies/pdi`

This folder contains resources required for building the Docker image.

- **`Dockerfile`**: The Dockerfile used to build the PDI Docker image.
- **`entrypoint/`**: Contains the entrypoint script and initialization files.
  - **`docker-entrypoint.sh`**: The entrypoint script that sets up the environment and starts the command given.
  - **`docker-entrypoint-init/`**: A folder to place any initialization files that need to be copied into the container.
- **`stagedArtifacts/`**: This folder should contain the pre-downloaded Pentaho distribution software ZIP files.
- **`README.md`**: Instructions on what files to place in this folder.

### `dist/on-prem/pdi/`

This folder contains dist resources and configurations for running the PDI Docker container.

- **`pdi/`**: Contains Docker Compose configurations for running Carte (PDI server), Kitchen and Pan.
  - **`carte.yml`**: Docker Compose file to set up and run the Carte server.
  - **`kitchen.yml`**: Docker Compose file to set up and run Kitchen.
  - **`pan.yml`**: Docker Compose file to set up and run Pan.
  - **`.env`**: Environment variables file for Docker Compose.

### `config/`

This folder should contain Pentaho files such as: .kettle and .pentaho also other configs like: .aws and .ssh
- **`carte-config.xml`**: The xml file will be used as parameter for the carte.sh.

### `logs/`

This folder is used to store log files for carte, kitchen, and pan services.

### `sofwareOverride/`

This folder should contain any configuration files that need to override the default configurations in the PDI installation.

### `solutionFiles/`

This folder should contain the project solution files such as KTR, KJB, and additional solution files.


## Usage

### Prerequisites

- Docker
- Docker Compose

### Building the Docker Image

1. Place the required Pentaho distribution software ZIP files in the `assemblies/pdi/stagedArtifacts/` folder.
2. Navigate to the `assemblies/pdi/` directory.
3. Build the Docker image using the following command:
   ```sh
   docker build -t pentaho/pdi:11.x .
   ```

### Running the Docker Containers

1. Navigate to the `dist/on-prem/pdi/` directory.
2. Ensure the `.env` file is correctly configured with the necessary environment variables.
3. Start the Carte server using Docker Compose:
   ```sh
   docker-compose -f volumes.yaml up
   ```
   ```sh
   docker-compose -f carte.yaml up
   ```
4. To run Kitchen and Pan, use the following commands:
   ```sh   
   docker-compose -f kitchen.yaml up
   ```
   ```sh
   docker-compose -f pan.yaml up
   ```

### Environment Variables

The `.env` file contains the following environment variables:

- `PENTAHO_VERSION`: The version of Pentaho to be used.
- `SOFTWARE_OVERRIDE_FOLDER`: The folder containing configuration overrides.
- `SOLUTION_FOLDER`: The folder containing project solution files.
- `CONFIG_FOLDER`: The folder containing configuration files.
- `PORT`: The port number to expose for the server (in case carte is used).

### Additional Information

For more details on how to configure and use the Docker setup, refer to the individual README files in the respective folders.
