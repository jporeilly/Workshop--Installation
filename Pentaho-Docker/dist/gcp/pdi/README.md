# Pentaho Data Integration Docker Project

This project provides a Docker setup for Pentaho Data Integration (PDI). The setup includes Dockerfiles, Docker Compose configurations, and necessary scripts to build and run PDI in a containerized environment.

## Project Structure

### `dist/`

This folder contains resources and configurations for running the PDI Docker container.
- **`volumes.yaml`**: yaml script to create storage, secrets, workspace etc into kubernates.
- **`carte.yaml`**: yaml script to deploy carte service into kubernates.
- **`kitchen.yaml`**: yaml script to deploy and run kitchen job into kubernates.
- **`pan.yaml`**: yaml script to deploy and run pan job into kubernates.

### `config/`

This folder should contain Pentaho files such as: .kettle and .pentaho also other configs like: .aws and .ssh
- **`carte-config.xml`**: The xml file will be used as parameter for the carte.sh.

### `softwareOverride/`

This folder should contain any configuration files that need to override the default configurations in the PDI installation.

### `solutionFiles/`

This folder should contain the project solution files such as KTR, KJB, and .kettle files.

### `logs/`

This folder is used to store log files fro services/jobs


## Usage

### Deploying into Kubernates and checking logs

## Update yaml Files

Create the required Google Cloud + GKE + IAM + Storage resources:
• Create GKE Cluster
• Create GCS Bucket (acts as storage account/file share)
• Create Artifact Registry (container registry)
• Create Kubernetes Service Account
• Enable Workload Identity
• Bind K8s Service Account to Google IAM Service Account


Update followings in the yaml files

1- containers:image Replace with your image
2- env:LICENSE_URL # Replace with your actual license URL
3- volumeMounts:subPath # Update subpath for each mount path if needed

Other values can be changed or keep the name same as YAML file like Namespace, PersistentVolume, PersistentVolumeClaim, ServiceAccount etc..

## Login to GKE Cluster

Run following commands to connect GPC

gcloud auth login

gcloud auth configure-docker <Artificat_Registry>
e.g.- gcloud auth configure-docker us-east1-docker.pkg.dev

gcloud config set project <project_name>
e.g.- gcloud config set project pentaho-lee-cheng

gcloud container clusters get-credentials <CLUSTER_NAME> --region <REGION> --project <PROJECT_ID>
e.g.- gcloud container clusters get-credentials  pentaho-standard-cluster --region  us-central1 --project pentaho-lee-cheng


## Deploying storage and secrets

kubectl apply -f /path/voluems.yaml

## Deploying Carte

1. kubectl apply -f /path/carte.yaml
2. Get pod name
   kubectl get pods -n <namespace>
   e.g.- kubectl get pods -n pdi
3. kubectl logs <pod_name>  -n <namespace>
   e.g.- kubectl logs carte-78855f6777-z62w6  -n pdi
4. Fetch the external IP address using the command
   kubectl get service <service-name> -n <namespace>
   e.g.- kubectl get service carte-service -n pdi

   the page can be access via http://externalIP:30081/kettle/status

## Deploying Pan and Kitchen

Use following yaml scripts to run Kitchen & Pan job respectively.
kitchen  -- kitchen.yaml
pan      -- pan.yaml

1. kubectl apply -f /path/kitchen
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