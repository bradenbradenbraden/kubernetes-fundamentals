Udemy: [kubernetes-microservice](https://www.udemy.com/course/kubernetes-microservices/learn/lecture/11156700#bookmarks)

## K8s

[API Docs](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.17/)

### Pods

- wrapper around container
- typically a 1:1 relationship between pod and container
- pod implements a single service
- pods are not accessible outside the cluster
- Pods can have labels: key value pairs

### Services

- Intended to be a long-running object
- Will have a ip address and stable fixed ports
- Services are attached to Pods
- Services have selectors (key value pairs) which attempt to match up against Pod labels
- Available Types
  - LoadBalancer (only supported by some cloud providers… won’t work locally)
  - ClusterIP - service is only available within the cluster
    - use with microservices
    - will have an ip address
  - NodePorts expose a port through the node
    - port number must be greater than 30000
    - Just using this for local development, would be swapped out with LoadBalancer in the cloud

### ReplicaSets

- Rarely do you work with pods directly
- Typically, in. a production system you’re dealing with:
  - Deployments
  - ReplicaSets

### Deployments

- Usually preferred over replicaSets
- More sophisticated replicaSet
- Automatic rolling updates with zero downtime
- Think of it as an entity that manages the replicaSet for you.

### Rollback

- only use in emergency.
- it will leave the running system and yamls out of sync.

### Networking

- Not a common scenario or recommended but, if you deploy two containers within a single pod, then they can communicate via localhost.
  - having both in the same pod makes it harder to manage (when something fails, harder to figure out what failed)
- Preferred: deploy the containers in separate pods and separate services
- each service is given its own private ip address (allocated dynamically by k8s)
- k8s maintains its own private dns service (coredns)
  - keys are names of the services
  - values are the ip address of the service
- we can refer to the service using the name of the service
  - containers looks up the service in coredns

### Namespace

- as you’d expect, a way of partitioning resources
- when unspecified, stuff goes into the ‘default’ namespace, and kubectl will return things from the default namespace if left unspecified.

### Data Persistence

- Configuring and attaching storage outside the container
- PersistentVolume
  - `kubectl get pv`
- PersistentVolumeClaim
  - `kubectl get pvc`
- StorageClass
  - similar to PersistentVolume… it will become a PersistentVolume when it is applied, it will be dynamically created.

### Secrets

- Not encrypted
- A place to put configuration and ensure it won’t be written to system logs

---

## minikube

- For local dev
- Start minikube
  - minikube start --memory 4096
- Connect to minikube host
  - `minikube ip`
  - `ssh docker@[ip]`
  - password: `tcuser`
- enable metrics server (needed for HPA)
  - minikube addons enable metrics-server

---

## Deploying to AWS

### Instance Configuration

- Nodes
  - physical server in the system
  - for AWS, that’s an EC2 instance
- Created a bootstrap aws instance
  - t2.nano
  - generated keypair… pem file is saved in 1pw (move to working dir)
- Accessing the bootstrap instance
  - ssh -i bootstrap-keypair.pem ec2-user@[public ip]
  - Restrict ssh access to known ips
    - EC2 -> select bootstrap instance -> click link to launch-wizard-1 security group
    - launch-wizard-1 SG -> Actions -> Edit inbound rules
    - Add Rule -> TCP -> My Ip
- When starting a new session (unless added to .bash_profile), you’ll need to [set ENV vars](https://github.com/kubernetes/kops/blob/master/docs/getting_started/aws.md#prepare-local-environment)
- Nodes and Master are protected by auto-scaling group. If one dies, it will be recreated. When k8s is running on the cluster, k8s will recreate any pods that died when the instance died.

### Recreate Cluster AWS

- Create the cluster (looks like it blows away the configs when the cluster is deleted)
  - `kops create cluster --zones us-east-1a,us-east-1b,us-east-1c,us-east-1d,us-east-1e,us-east-1f ${NAME}`
- Edit the number of nodes
  - `kops edit ig nodes --name=${NAME}`
    - `maxSize: 5`
    - `minSize: 3`
- Edit kubelet settings (workaround for grafana)
  - `kops edit cluster --name ${NAME}`
    - `authenticationTokenWebhook: true`
    - `authorizationMode: Webhook`
- Start cluster
  - `kops update cluster --name fleetman.k8s.local --yes`
- Validate
  - `kops validate cluster ${NAME}`
- Deploy Pods
  - `kubectl apply -f .`
- Redeploy monitoring
  - `kubectl create namespace monitoring`
  - `helm install monitoring stable/prometheus-operator --namespace monitoring`
  - `kubectl --namespace monitoring get pods -l "release=monitoring"`
- Make grafana load balanced
  - `kubectl edit [grafana service] -n monitoring`
  - change from clusterip to loadbalancer
- you’ll have to update loadbalancer alias
  - kubectl get all
    - service for webapp will show loadbalancer
    - get the A record for the loadbalancer
    - route53 -> Hosted Zones -> select alias
    - update alias target

### Delete Cluster

- `kops delete cluster --name=\${NAME} --yes`
- If stopping bootstrap instance you’ll have a new ip address when it is restarted

### Prometheus Operator

- [prometheus-operator](https://github.com/helm/charts/tree/master/stable/prometheus-operator)
  - Pulls together tools/configurations for full monitoring and alerting solution
  - Deployed with helm
    - `kubectl create namespace monitoring`
    - `helm install monitoring stable/prometheus-operator --namespace monitoring`
    - `kubectl --namespace monitoring get pods -l "release=monitoring"`
    - Edit config to expose grafana
      - `kubectl edit -n monitoring service/monitoring-grafana`
      - Set `type: LoadBalancer`
    - Show loadbalancer
      - `kubectl --namespace monitoring get all`

### Kibana

- Loadbalanced url
  - `kubectl get all -n kube-system`
  - port 5601

---

## General Info

### Accessing Service w/o LoadBalancer

- Won’t work all the time (if dependent services)
- get the cluster api load balancer url
- credentials
  - `admin`
  - password: `kubectl config view —minify`
- compose the url
  - `api/v1/namespaces/<namespace>/services/<service>:<port>/proxy`

### Stateful Pods

- Avoid them (you can’t just throw a replicate set at it).
  - In the case of this demo app:
    - active MQ
    - MongoDB
  - Look for hosted alternatives (trade-off is that it ties you to 3rd party
    - Amazon MQ
    - Amazon SimpleDB
  - or refactor code to support replication
    - common in mongo

### Micro-services

- Highly cohesive & Loosely coupled
- Highly cohesive
  - ideally, a single services fulfills a single business requirement
  - a single set of responsibilities
- Loosely coupled
  - minimize the interfaces between two services
  - messaging can help reduce the complexity of interfaces
- Integration databases (lots of stuff writing to the same db) are incompatible with microservice architecture
- Each microservice will maintain its own datastore. It will be the only thing reading/writing to/from the datastore
- really hard to do a microservice architecture up front, they’re more typically emergent.
- API Gateway - single point of contact between frontend and backend (BFF)

---

##

---

## Troubles

### Rolling restart

- There’s a workaround for missing data in grafana that requires editing cluster config and doing a rolling restart.
  - The rolling restart kept failing on one of the elasticsearch-logging pods
  - `Warning FailedScheduling 3s (x15 over 19m) default-scheduler 0/4 nodes are available: 1 node(s) had taints that the pod didn't tolerate, 3 node(s) had volume node affinity conflict.`
    - not sure why this was happening or what the fix is. Saw some reference to it being related to availability zones.
    - Attempted fix: updated storage-aws.yaml to specify this on the StorageClass
      - `volumeBindingMode:WaitForFirstConsumer`

### Alerts Configuration

- Never sorted out how to resolve these alerts...
- Getting the following alerts: `job="coredns" job="kube-proxy"`
  - `KubeControllerManager has disappeared from Prometheus target discovery`
  - `KubeScheduler has disappeared from Prometheus target discovery`
  - `TargetDown (kube-system monitoring/monitoring-prometheus-oper-prometheus warning)`
- Docs for kube-prometheus indicate that there may be config overrides available for deployments that are managed by Kops.
