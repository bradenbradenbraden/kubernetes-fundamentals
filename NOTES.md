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

### Resource Requests

- Enables cluster manager to determine if a node has sufficient memory/cpu requirements to handle a given pod
- If no available node, pod will fail to deploy
- Does not change the runtime behavior of the Pod
- specified in container definition
- Minikube
  - show available resources
    - kubectl describe minikube
    - available resources
      - Capacity (available the node)
      - Allocatable (available pods)
- Memory Requests
- CPU Requests
  _ 1 CPU = 1vCPU
  _ 100m = 100 millicores = .1CPU

### Resource Limits

- Have an impact on runtime behavior
- Safety net for misbehaving containers
- Must be at least the value specified in the request
- Memory
  - Container will be killed if the actual memory usage of the container at runtime exceeds the limit
  - The Pod will remain and the container will attempt to restart
- CPU
  - CPU is throttled at the specified limit

### Metrics and Profiling

- Available as a minikube addon
- Enable: minikube addons enable metrics-server
- kubectl top node
- kubectl top pod
- Dashboard
  - minikube
    - minikube addons enable dashboard
    - minikube dashboard

### Horizontal Pod Auto-scaling

- Automatically resize the cluster depending on current workload
- Requires metrics-server
- You’re autoscaling the deployment not the pods
- Can set an HPA rule that will automatically update the number of replicas in the deployment
- Example:
  - if pod uses > 50% of cpu request, autoscale to a max of 5 pods
  - similarly, scale down as needed
- Rules are setup for each deployment
- Best to capture in yaml but here’s the command:
  - kubectl autoscale deployment api-gateway --cpu-percent 400 --min 1 --max 4
  - cpu-percent is relative to the request
  - cpu request for api-gateway is set at 50m, so this would scale at 200m
- kubectl get hpa
  - targets % is current usage of request (50m)
- Outputting the yaml config for the HPA object
  - kubectl get hpa api-gateway -o yaml
  - strip out unnecessary properties

### Readiness / Liveness Probes

- Can be an http request, a command to execute against the container (does a exec on the container), or a tcp probe
- Readiness Probes
  - configured in the deployment (at the container)
  - Run when the container starts.
  - will not route traffic until the the instance reports that it is ready for traffice
- Liveness Probes
  - Run continually
  - If the probe fails, K8s will restart the container

### QOS

- Used for already running pods
- Guaranteed
  - label applied when cpu request/limit AND memory request/limit are specified AND are request/limit are the same value
- Burstable
  - label applied when either cpu or memory request but no limit
- Best Effort \* label applied when no requests/limits are specified.
  Priority
- Used when scheduling a new pod
- Just a number
- New pod with a higher priority can evict lower priority pod. The evicted pod will then be rescheduled.

### Configmaps

- share across pods
- immutable (currently) for running pods.
  - workarounds:
    - bounce the pods or...
    - version the (metadata) name of the configmap… then you have update all references to that name
- Injecting as an env var
  - container
    - envFrom:
      - -configMapReg:
        - name: <name of configMap>
- Can also volume mount the config map
  - will create as file

### Secret

- not encrypted
- similar to configmap
- just masks output in console log (e.g. kubectl describe secret)

### Ingress on minikube

- enable the addon: minikube addons enable ingress
  - will create an nginx ingress controller deployment (pod/service)
  - no longer creates a default-http-backend pod (at least not one that I could find)
- Applying Basic Auth
  - generate a username/password:
    - htpasswd -c auth admin
      - filename must be ‘auth'
  - Add config to ingress yaml as described here: https://kubernetes.github.io/ingress-nginx/examples/auth/basic/
  - You can have multiple ingress files to partition auth / no auth routes. e.g.: ingress-secure, ingress-public

###Ingress on AWS

- Installation Guide: https://kubernetes.github.io/ingress-nginx/deploy/
- Grab the prereq config: wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml
- kubectl apply -f mandatory.yaml
  - creates a new namespace: ingress-nginx
- AWS: https://kubernetes.github.io/ingress-nginx/deploy/#aws
- Layer 4 vs Layer 7
  - Layer 4
    - lower-level balancer: inspects the raw packets (TCP)
  - Layer 7
    - Works at HTTP level, can get access to whether it is a get or post
- Using Layer 4 in this example because apps are using websocket connections don’t get through
- In AWS deployment, there’s a loadbalancer in front of the ingress controller
- Couldn’t get it working with /etc/hosts entry
- Route53
  - configure an alias for app and queue
  - both point at the load balancer
  - update ingress-public/secure yaml files to reference the correct subdomain.
- HTTPS
  - options
    - set up ingress controller to terminate the ssl connection
      - get/install cert … then you’re stuck managing that cert.
      - all traffic coming though the load balancer would be encrypted as far as the ingress controller.
      - http from ingress to services
    - set up the loadbalancer to terminate the ssl
      - easier because aws can handle most of the cert management
      - don’t have to pay for the cert
  - configuring https on the load balancer
    - Certificate Manager
      - request public certificate
        - .<domain> (subdomains)
        - <domain> (root)
      - expand option and click add to route 53 button
  - modify service-l4.yaml
    - annotations
      - service.beta.kubernetes.io/aws-load-balancer-ssl-cert: “<arn for the cert (sub)>"
      - service.beta.kubernetes.io/aws-load-balancer-backend-protocol: “tcp” # because demo uses websockets
      - service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
      - ports
        - since we’re terminating on the load balancer, we want port 443 to have a target port of 80
        - the request is unencrypted at the load balancer so we want to make sure we’re forwarding the unencrypted request to port 80 instead of 443 (which the ingress control would complain about)
    - forcing http redirect to https
      - Can add custom configuration to patch-configmap-l4.yaml
      - https://gist.github.com/DickChesterwood/3557a4f30f056703a4e1b9892491f531
      - force-ssl-redirect: “true” should be all that is needed but websockets might be requiring more config.

### Other Workloads

- Job

  - creates a pod and k8s will ensure that it runs to completion (batch job)
  - kubernetes will reschedule a pod if it completes
    - could add a restartPolicy to the container (default is always but can be onFailure or never)
    - a completed Pod will not be automatically deleted
    - There’s a TTL Controller that can perform cleanup
    - pod won’t restart container on error status

- CronJobs

  - wrapper around regular job
  - nothing special, does what it says.

- DaemonSets

  - Ensures that all nodes run a copy of a pod
  - When a new node is added to the cluster, the pod will be added to the node.
  - Deleting a daemonSet will cleanup the associated pods

- StatefulSets
  - a statefulSet is NOT used/needed for persistence
  - Sometimes you have pods that must have known and predictable names
  - Usually when you want the clients to be able to call the pods directly using their name (via a ‘headless’ service). You client needs to address specific instances of the pod. e.g: first call pod1, then call pod2
  - Originally called ‘petSet'
  - Pods will have predictable names (with incrementing suffix)
  - Pods will always start up in sequence
  - clients can address them by name
  - typical use case: you have database pod AND you want to replicate it (scale it out)
  - Mongo example
    - in a mongo cluster, the cluster will elect a leader
      - primary
      - others are secondary
    - writes need to be made to the primary, from the primary mongo will copy to the secondaries
    - client needs to write to a specific url: e.g. mongodb://mongo-server-1
  - When you make a call to headless service, the url is slightly different: comma separated list of named pods followed by the service
    - example:
      - mongodb://<pod>.<service>,<pod>.<service>
      - mongodb://mongo-0.mongodb,mongo-1.mongodb,mongo-2.mongodb
    - since all the pods are referenced in the url, the client will be able to find the primary.
  - Typically, you wouldn’t want to have database pods in a cluster, you’d want it to live externally so you can better manage the database, backups, recovery
    - Prefer a hosted service instead.
    - documentdb is similar to mongo
  - headless service
    - there’s no syntax for a headless service
    - it is just a service that connects to a stateful-set

---

## minikube

- For local dev
- Start minikube
  - minikube start --memory 4096
- Connect to minikube host
  - `minikube ip`
  - `ssh docker@[ip]`
  - password: `tcuser`
- configure shell to expose minikube docker
  - eval \$(minikube docker-env)
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
