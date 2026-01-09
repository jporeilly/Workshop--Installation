# Pentaho Data Integration Docker Project

This project provides a Docker setup for Pentaho Data Integration (PDI). The setup includes Dockerfiles, Docker Compose configurations, and necessary scripts to build and run PDI in a containerized environment.

## Project Structure

### `assemblies/`

This folder contains resources required for building the Docker image.

- **`Dockerfile`**: The Dockerfile used to build the PDI Docker image.
- **`entrypoint/`**: Contains the entrypoint script and initialization files.
    - **`docker-entrypoint.sh`**: The entrypoint script that sets up the environment and starts the command given.
    - **`carte-config.xml`**: The xml file will be used as parameter for the carte.sh.
    - **`docker-entrypoint-init/`**: A folder to place any initialization files that need to be copied into the container.
- **`stagedArtifacts/`**: This folder should contain the pre-downloaded Pentaho distribution software ZIP files.
    - **`README.md`**: Instructions on what files to place in this folder.

### `dist/`

This folder contains resources and configurations for running the PDI Docker container.

- **`pdi/`**: Contains Docker Compose configurations for running Carte (PDI server).
    - **`carte.yaml`**: yaml script to deploy carte service into kubernates.
    - **`kitchen.yaml`**: yaml script to deploy kitchen job into kubernates.
    - **`pan.yaml`**: yaml script to deploy pan job into kubernates.
    - **`.env`**: Environment variables file for Docker Compose.

### `config/`

This folder should contain Pentaho files such as: .kettle and .pentaho also other configs like: .aws and .ssh

### `softwareOverride/`

This folder should contain any configuration files that need to override the default configurations in the PDI installation.

### `solutionFiles/`

This folder should contain the project solution files such as KTR, KJB, and .kettle files.

## Usage

### Prerequisites

- Docker
- Docker Compose

### Building the Docker Image

1. Navigate to the `assemblies/` directory.
2. Place the required Pentaho distribution software ZIP files in the `assemblies/stagedArtifacts/` folder.
3. Change the `Dockerfile` `ARG PENTAHO_VERSION` to the desired version of Pentaho Data Integration.
4. Build the Docker image using the following command:
   ```sh
   docker build -t pentaho/pdi:11.x .
   ```
5. tag this image and push it using following commands into ECR
    ```sh
    docker tag pentaho/pdi:10.3.0.0-318 524647911006.dkr.ecr.us-east-2.amazonaws.com/dockmaker-pdi:318-2
    docker push 524647911006.dkr.ecr.us-east-2.amazonaws.com/dockmaker-pdi:318-2
   ```

### Deploying into Kubernates and checking logs

## Update yaml Files

Create the required AWS EKS + IAM + Storage resources:
• Create EKS Cluster
• Create AWS Bucket (acts as storage account/file share)
• Create Artifact Registry (container registry)
• Create Kubernetes Service Account
• Enable Workload Identity
• Bind K8s Service Account to kubernates cluster IAM Service Account


Update followings in the yaml files

1- containers:image Replace with your image
2- env:LICENSE_URL # Replace with your actual license URL
3- volumeMounts # Update path for each mount path if needed

Other values can be changed or keep the name same as YAML file like Namespace, PersistentVolume, PersistentVolumeClaim, ServiceAccount etc..

## Deploying storage
kubectl apply -f /path/voluems.yaml
This creates the service account along with the persistent volume and persistent volume claim.
The trust identity needs to be updated. IAM role and IRSA needs to be updated with the correct SA or additional SA using bellow example.
The service account "pdi-s3-access" is specific to PDI in pdi namespace.
```sh
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::524647911006:oidc-provider/oidc.eks.us-east-2.amazonaws.com/id/6865435CCE28BD2FF190A4692FD6C261"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.us-east-2.amazonaws.com/id/6865435CCE28BD2FF190A4692FD6C261:sub": [
                        "system:serviceaccount:pdi:pdi-s3-access"
                    ]
                }
            }
        }
    ]
}
```


## Deploying Carte

The yaml file needs to be updated with path to the iamge, License server URL in the env variable, bucket and path to the softwareOverride in the bucket

1. kubectl apply -f /dist/aws/pdi/carte.yaml
2. kubectl logs carte-78855f6777-z62w6  -n carte --all-containers
3. Fetch the external IP address using the command 
   kubectl get nodes -o wide 
   the page can be access via http://externalIP:30081/kettle/status

## Deploying Pan and Kitchen

Use following yaml scripts to run Kitchen & Pan job respectively.
kitchen  -- kitchen.yaml
pan      -- pan.yaml

1. kubectl apply -f /dist/aws/kitchen/kitchen.yaml
   kubectl apply -f /dist/aws/pdi/pan.yaml
2. Get pod name
   kubectl get jobs -n <namespace>
   e.g.- kubectl get jobs -n kitchen
3. Check status
   kubectl describe job <job-name> -n <namespace>
   e.g.- kubectl describe job kitchen-job -n kitchen
4. Check logs using
   kubectl logs job/<job-name> -n <namespace>
   e.g.- kubectl logs job/kitchen-job -n kitchen

   Similar steps will be done to run the pan job as well

To run the Kubernetes Job with a new parameter, first delete the existing Job and then recreate it with the updated configuration and run it.

1. Delete the existing Job:
   kubectl delete job <job-name> --namespace <namespace>
   e.g.- kubectl delete job pan-job --namespace pdi
2. Modify the YAML (e.g., change a command, env var, or .ktr/.kjb file path).
3. Apply the updated YAML again:
   kubectl apply -f <job-name>
   e.g.- kubectl apply -f pan.yaml

### Additional Information

For more details on how to configure and use the Docker setup, refer to the individual README files in the respective folders.
