<h1 align="center">🌟 Cloud first microservices e-commerce web application 🌟</h1>

<p align="center">
  <img alt="Static Badge" src="https://img.shields.io/badge/Spring%20Boot-yellowgreen?style=for-the-badge">
  <img alt="Static Badge" src="https://img.shields.io/badge/React.js-darkblue?style=for-the-badge">
  <img alt="Static Badge" src="https://img.shields.io/badge/mongodb-darkgreen?style=for-the-badge">
  <img alt="Static Badge" src="https://img.shields.io/badge/jwt-hotpink?style=for-the-badge">
  <img alt="Static Badge" src="https://img.shields.io/badge/docker-blue?style=for-the-badge">
  <img alt="Static Badge" src="https://img.shields.io/badge/kubernetes-skyblue?style=for-the-badge">
  <img alt="Static Badge" src="https://img.shields.io/badge/terraform-purple?style=for-the-badge">
  <img alt="Static Badge" src="https://img.shields.io/badge/AWS%20EKS-tomato?style=for-the-badge">
  <img alt="Static Badge" src="https://img.shields.io/badge/AWS%20ECR-orange?style=for-the-badge">
  <img alt="Static Badge" src="https://img.shields.io/badge/GITHUB%20ACTIONS-white?style=for-the-badge">
</p>

- Purely is a cloud-first microservices web application showcasing Kubernetes. The application is a web-based e-commerce app where users can browse items, add them to the cart, and purchase them...
- The architecture leverages **Spring Boot microservices**, **Spring Cloud Gateway**, and **Eureka Service Registry**, with a **React.js frontend** and **MongoDB databases**. 
- The solution is containerized and deployed to **AWS Elastic Kubernetes Service (EKS)** using **Helm** and automated via **GitHub Actions CI/CD** pipelines.

## 📑 Table of contents

1.  [Project Tree](#-project-tree)
2.  [Development Set up](#-development-set-up)
    - [Component Diagram](#component-diagram)
    - [Frontend](#frontend)
    - [Service Registry](#service-registry)
    - [Api Gateway](#api-gateway)
    - [Auth Service](#auth-service)
    - [Category Service](#category-service)
    - [Product Service](#product-service)
    - [Cart Service](#cart-service)
    - [Order Service](#order-service)
    - [Notification Service](#notification-service)
    - [Communication between services](#communication-between-services)
3. [Deployment Set up](#-deployment-set-up)
    - [Deployment Diagram](#deployment-diagram)
    - [Containerization](#containerization)
    - [Kubernetes Orchestration](#kubernetes-orchestration)
    - [AWS Infrastructure](#aws-infrastructure)
      - [Networking (AWS VPC)](#networking-aws-vpc)
      - [Kubernetes Cluster (AWS EKS)](#kubernetes-cluster-aws-eks)
      - [Horizontal Pod Autoscaler (HPA)](#horizontal-pod-autoscaler-hpa---deep-dive)
      - [Cluster Autoscaler](#cluster-autoscaler---deep-dive)
      - [Load Testing HPA & Cluster Autoscaler](#load-testing-hpa--cluster-autoscaler)
      - [Service Accounts & RBAC](#service-accounts--rbac)
      - [CoreDNS (Cluster DNS)](#coredns-cluster-dns)
    - [Terraform - Infrastructure as Code](#terraform-infrastructure-as-code)
    - [CI/CD with GitHub Actions](#cicd-with-github-actions)
4. [How to run locally?](#%EF%B8%8F-how-to-run-locally)
5. [How to deploy to AWS?](#%EF%B8%8F-how-to-deploy-to-amazon-eks)
6. [Demo video](#demo-video)

## 📂 Project tree

```
fullstack-E-commerce-web-application/
├── .github/
│   └── workflows/
│       ├── ci-cd-auth.yml
│       ├── ci-cd-cart.yml
│       ├── ci-cd-category.yml
│       ├── ci-cd-gateway.yml
│       ├── ci-cd-ingress.yml
│       ├── ci-cd-notification.yml
│       ├── ci-cd-order.yml
│       ├── ci-cd-product.yml
│       ├── ci-cd-registry.yml
│       ├── ci-cd-user.yml
│       └── ci-cd-web.yml
├── assets/
├── frontend/
│   ├── nginx/
│   ├── public/
│   ├── src/
│   │   ├── api-service/
│   │   ├── assets/
│   │   ├── components/
│   │   ├── contexts/
│   │   ├── pages/
│   │   ├── routes/
|   |   ├── App.jsx
│   │   └── main.jsx
│   ├── Dockerfile
│   └── index.html
├── helm-charts/
│   ├── api-gateway/
│   ├── auth-service/
│   ├── cart-service/
│   ├── category-service/
│   ├── common/                    # Service Accounts, RBAC, shared resources
│   ├── ingress-alb/
│   ├── notification-service/
│   ├── order-service/
│   ├── product-service/
│   ├── service-registry/
│   ├── user-service/
│   └── web-app/
├── microservice-backend/
│   ├── api-gateway/
│   ├── auth-service/
│   ├── cart-service/
│   ├── category-service/
│   ├── notification-service/
│   ├── order-service/
│   ├── product-service/
│   ├── service-registry/
│   └── user-service/
├── sample-data/
│   ├── purely_category_service.categories.json
│   └── purely_product_service.products.json
└── terraform/
│   ├── common-data.tf
│   ├── common-provider.tf
│   ├── common-variables.tf
│   ├── ecr-registries.tf
│   ├── eks-access-entries.tf
│   ├── eks-alb-controller.tf
│   ├── eks-cluster-autoscaler.tf
│   ├── eks-cluster.tf
│   ├── eks-metrics-server.tf
│   ├── eks-node-groups.tf
│   ├── eks-openid-connect-provider.tf
│   ├── policies/
│   │   ├── AWSLoadBalancerControllerIAMPolicy.json
│   │   └── EKSClusterAutoscalerIAMPolicy.json
│   ├── vpc-internet-gateway.tf
│   ├── vpc-nat-gateway.tf
│   ├── vpc-route-tables.tf
│   ├── vpc-subnets.tf
│   └── vpc.tf
└── README.md
```

## 👨‍💻 Development set up

- **Microservices Architecture**: Independent services for User, Auth, Product, Category, Cart, Order, and Notification.
- **Service Discovery**: Centralized Eureka Service Registry manages dynamic discovery of microservices within the cluster. Simplifies communication and load balancing between services.
- **API Gateway**: Built using Spring Cloud Gateway. Acts as the single entry point for all client requests.
- **Frontend**: Developed in React.js, providing a responsive user interface. Communicates with the backend exclusively via API Gateway.
- **Databases**: Each microservice uses a dedicated MongoDB database.
  
### Component Diagram 

<img src="assets/component-diagram.png" />

### Frontend 

### Service Registry

- The <a href="./microservice-backend/service-registry">Service Registry</a> serves as a centralized repository for storing information about all the available services in the microservices architecture. 

- This includes details such as IP addresses, port numbers, and other metadata required for communication.

- As services start, stop, or scale up/down dynamically in response to changing demand, they update their registration information in the Service Registry accordingly.

### API Gateway

- The <a href="./microservice-backend/api-gateway">API gateway</a> acts as a centralized entry point for clients, providing a unified interface to access the microservices.

- API gateway acts as the traffic cop of our microservices architecture. It routes incoming requests to the appropriate microservice, or instance based on predefined rules or configurations.


### Auth Service

- The <a href="./microservice-backend/auth-service">Auth Service</a> is responsible for securely verifying user identities and facilitating token-based authentication.

| HTTP Method | Route Path | Parameters | Description |
|----------|----------|----------|----------|
| <img alt="Static Badge" src="https://img.shields.io/badge/post-green?style=for-the-badge"> | `/auth/signin`   | - | User login |
| <img alt="Static Badge" src="https://img.shields.io/badge/post-green?style=for-the-badge"> | `/auth/signup`   | - | User registration   |
| <img alt="Static Badge" src="https://img.shields.io/badge/get-blue?style=for-the-badge"> | `/auth/signup/verify`   | code | Validate registration one time password code |
| <img alt="Static Badge" src="https://img.shields.io/badge/get-blue?style=for-the-badge"> | `/auth/isValidToken`   | token | Validate json web token  |


### Category Service

- The <a href="./microservice-backend/category-service">Category Service</a> provides centralized data management and operations for product categories.

| HTTP Method | Route Path | Parameters | Description | Authentication | Role | 
|----------|----------|----------|----------| ----------| ----------|
| <img alt="Static Badge" src="https://img.shields.io/badge/post-green?style=for-the-badge"> | `/admin/category/create`   | - | Create new category | Yes | Admin |
| <img alt="Static Badge" src="https://img.shields.io/badge/put-yellow?style=for-the-badge"> | `/admin/category/edit`   | categoryId | Edit existing category | Yes | Admin |
| <img alt="Static Badge" src="https://img.shields.io/badge/delete-red?style=for-the-badge"> | `/admin/category/delete`   | categoryId | Delete existing category | Yes | Admin |
| <img alt="Static Badge" src="https://img.shields.io/badge/get-blue?style=for-the-badge"> | `/category/get/all`   | - | Get all categories | No | Admin/User/Non user |
| <img alt="Static Badge" src="https://img.shields.io/badge/get-blue?style=for-the-badge"> | `/category/get/byId`   | categoryId | Get category by id | No |  Admin/User/Non user  |

### Product Service

- The <a href="./microservice-backend/product-service">Product Service</a> provides centralized data management and operations for available products.

| HTTP Method | Route Path | Parameters | Description | Authentication | Role (Admin/User) | 
|----------|----------|----------|----------| ----------| ----------|
| <img alt="Static Badge" src="https://img.shields.io/badge/post-green?style=for-the-badge"> | `/admin/product/add`   | - | Create new product | Yes | Admin |
| <img alt="Static Badge" src="https://img.shields.io/badge/put-yellow?style=for-the-badge"> | `/admin/product/edit`   | productId | Edit existing product | Yes | Admin |
| <img alt="Static Badge" src="https://img.shields.io/badge/get-blue?style=for-the-badge"> | `/product/get/all`   | - | Get all products | No |  Admin/User/Non user  |
| <img alt="Static Badge" src="https://img.shields.io/badge/get-blue?style=for-the-badge"> | `/product/get/byId`   | productId | Get product by id | No |  Admin/User/Non user  |
| <img alt="Static Badge" src="https://img.shields.io/badge/get-blue?style=for-the-badge"> | `/product/get/byCategory`   | categoryId | Get product by category | No |  Admin/User/Non user  |
| <img alt="Static Badge" src="https://img.shields.io/badge/get-blue?style=for-the-badge"> | `/product/search`   | searchKey | Search products by key | No |  Admin/User/Non user  |

### Cart Service

- The <a href="./microservice-backend/cart-service">Cart Service</a> provides centralized data management and operations for user carts.

| HTTP Method | Route Path | Parameter | Description | Authentication | Role (Admin/User) | 
|----------|----------|----------|----------| ----------| ----------|
| <img alt="Static Badge" src="https://img.shields.io/badge/post-green?style=for-the-badge"> | `/cart/add`   | - | Add item to cart, update quantity | Yes | User |
| <img alt="Static Badge" src="https://img.shields.io/badge/get-blue?style=for-the-badge"> | `/cart/get/byUser` | - | Get cart details by user | Yes | User |
| <img alt="Static Badge" src="https://img.shields.io/badge/get-blue?style=for-the-badge"> | `/cart/get/byId` | cartId | Get cart details by cart id | Yes | User |
| <img alt="Static Badge" src="https://img.shields.io/badge/delete-red?style=for-the-badge"> | `/cart/remove`   | productId | Remove an item from the cart | Yes | User |
| <img alt="Static Badge" src="https://img.shields.io/badge/delete-red?style=for-the-badge"> | `/cart/clear/byId`   | cartId | Remove all the items from the cart | Yes | User |

### Order Service

- The <a href="./microservice-backend/order-service">Order Service</a> provides centralized data management and operations for orders.

| HTTP Method | Route Path | Parameter | Description | Authentication | Role (Admin/User) | 
|----------|----------|----------|----------| ----------| ----------|
| <img alt="Static Badge" src="https://img.shields.io/badge/post-green?style=for-the-badge"> | `/order/create`   | - | Place an order | Yes | User |
| <img alt="Static Badge" src="https://img.shields.io/badge/get-blue?style=for-the-badge"> | `/order/get/byUser` | - | Get orders by user | Yes | User |
| <img alt="Static Badge" src="https://img.shields.io/badge/get-blue?style=for-the-badge"> | `/order/get/all`   | - | Get all orders | Yes | Admin |
| <img alt="Static Badge" src="https://img.shields.io/badge/delete-red?style=for-the-badge"> | `/order/cancel`   | orderId | Cancel the order | Yes | User |

### Notification Service

- The <a href="./microservice-backend/notification-service">Notification Service</a> provides centralized operations for send emails to user.

| HTTP Method | Route Path | Description | 
|----------|----------|----------|
| <img alt="Static Badge" src="https://img.shields.io/badge/post-green?style=for-the-badge"> | `/notification/send`   | Send email | 

### Communication between services

- OpenFeign, a declarative HTTP client library for Java, is used to simplify the process of making HTTP requests to other microservices.
  
## 🚀 Deployment set up

### Deployment Diagram

<img alt="Deployment-Diagram" src="assets/deployment-diagram.png" />

### Containerization

- Each component ([frontend](./frontend/Dockerfile), [service-registry](./service-registry/Dockerfile), [api-gateway](./api-gateway/Dockerfile), and [other microservices](./category-service/Dockerfile)) has its own Dockerfile, and is packaged into a Docker image.
- Images pushed to **Amazon Elastic Container Registry (ECR)**.

### Kubernetes Orchestration

- Each service is deployed as a separate Helm chart under [`/helm-charts`](`/helm-charts`) directory.
- Each chart includes Kubernetes resources: `Deployment`, `hpa`, `Service`, `ConfigMaps`, and `Secrets`.
- All components ([Ingress](./helm-charts/ingress-alb), [frontend](./helm-charts/web-app), [service-registry](./helm-charts/service-registry), [api-gateway](./helm-charts/api-gateway), and [other microservices](./helm-charts/category-service)) deployed as `ClusterIP` service type.

### AWS Infrastructure

#### Networking (AWS VPC)

- A dedicated [VPC](./terraform/vpc.tf) across two Availability Zones (AZs).
- [Subnets](./terraform/vpc-subnets.tf):
  - 2 Public subnets (1 in each AZ).
  - 2 Private subnets (1 in each AZ).
- [Internet Gateway](./terraform/vpc-internet-gateway.tf): Attached to VPC for public subnet access for public subnets.
- [NAT Gateway](/terraform/vpc-nat-gateway.tf): Deployed in one public subnet, allowing outbound internet access for resources in private subnets (e.g., EKS worker nodes pulling Docker images).
- [Route Tables](./terraform/vpc-route-tables.tf):
  - Public route table routes internet-bound traffic via Internet Gateway.
  - Private route table routes internet-bound traffic via NAT Gateway.

#### Kubernetes Cluster (AWS EKS)

- [**EKS Cluster**](./terraform/eks-cluster.tf) deployed within the above VPC.
- [**EKS Node Group (managed worker nodes)**](./terraform/eks-node-groups.tf) spread across the two AZs for high availability. Worker nodes are deployed in private subnets, ensuring they are not exposed directly to the internet.
- [**Application Load Balancer controller**](./terraform/eks-alb-controller.tf) is installed within the EKS cluster, to let traffic route using ingress.
- [**Metrics-server**](./terraform/eks-metrics-server.tf) is installed within the EKS cluster, to let `Horizontal Pod AutoScaler` get the current CPU/memory usage for each Pod.
- [**Cluster AutoScaler**](./terraform/eks-cluster-autoscaler.tf) is installed within the EKS Cluster, automatically adjusting the number of worker nodes in the EKS cluster based on pending pods.

> Horizontal Pod AutoScaler (HPA) is a Kubernetes resource that automatically scales the number of pods in a Deployment, ReplicaSet, or StatefulSet. It continuously watches pod resource metrics (like CPU %, memory %, or custom metrics) from metrics-server. If usage goes above or below a defined threshold, it increases or decreases pods.

> Cluster Autoscaler (CA) is a Kubernetes component that automatically adjusts the number of worker nodes in the cluster. If HPA scales up pods but no nodes have enough resources to run them, CA adds new nodes. If nodes are scaled down, it removes nodes to save cost.

#### Horizontal Pod Autoscaler (HPA) - Deep Dive

HPA automatically scales pods based on CPU/Memory utilization. It requires **Metrics Server** to collect resource metrics.

**HPA Configuration (per service):**

| Setting | Value | Description |
|---------|-------|-------------|
| `minReplicas` | 1 | Minimum pods (never scale below) |
| `maxReplicas` | 5 | Maximum pods (never scale above) |
| `targetCPUUtilization` | 70% | Scale up when avg CPU > 70% |
| `targetMemoryUtilization` | 80% | Scale up when avg Memory > 80% |

**How HPA Works:**

```
Normal Traffic (1 pod)          CPU Spike (HPA scales up)
┌─────────┐                     ┌─────────┐  ┌─────────┐  ┌─────────┐
│ Pod     │  CPU: 30%           │ Pod     │  │ Pod     │  │ Pod     │
└─────────┘                     └─────────┘  └─────────┘  └─────────┘
                                CPU: 28%     CPU: 28%     CPU: 29%
     │                               ▲
     │ Traffic increases             │ Load distributed across pods
     │ CPU > 70%                     │
     └───────────────────────────────┘
```

**Important: `maxSurge` vs `HPA maxReplicas`**

| Setting | When Used | Purpose |
|---------|-----------|---------|
| `maxSurge: 1` | During code deployment ONLY | Create 1 extra pod for zero-downtime update |
| `HPA maxReplicas: 5` | During runtime (traffic spikes) | Scale up to 5 pods when CPU/Memory is high |

**HPA Scaling Behavior:**

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 60    # Wait 60s before scaling up
    policies:
      - type: Pods
        value: 2                       # Add max 2 pods at a time
        periodSeconds: 60
  scaleDown:
    stabilizationWindowSeconds: 300   # Wait 5min before scaling down
    policies:
      - type: Pods
        value: 1                       # Remove 1 pod at a time
        periodSeconds: 120
```

**Validation Commands:**
```bash
# Check HPA status
kubectl get hpa -n ecommerce

# Watch HPA in real-time
kubectl get hpa -n ecommerce -w

# Check current pod CPU/Memory
kubectl top pods -n ecommerce
```

#### Cluster Autoscaler - Deep Dive

Cluster Autoscaler automatically adjusts the number of EC2 worker nodes based on pod scheduling needs.

**When Cluster Autoscaler Scales UP:**
1. HPA creates more pods due to high CPU
2. New pods are in **Pending** state (no node has enough resources)
3. Cluster Autoscaler detects pending pods
4. Autoscaler adds new EC2 node
5. Pending pods get scheduled on new node

**When Cluster Autoscaler Scales DOWN:**
1. Traffic decreases → HPA reduces pods
2. Node becomes underutilized (< 50% CPU)
3. Autoscaler waits 5 minutes (stabilization)
4. Autoscaler terminates underutilized node
5. Remaining pods moved to other nodes

**Cluster Autoscaler Configuration:**

| Setting | Value | Description |
|---------|-------|-------------|
| `scale-down-enabled` | true | Allow removing nodes |
| `scale-down-delay-after-add` | 5m | Wait 5min after adding node |
| `scale-down-unneeded-time` | 5m | Node must be idle 5min before removal |
| `scale-down-utilization-threshold` | 0.5 | Scale down if CPU < 50% |

**Node Group Scaling Limits (Terraform):**

```hcl
scaling_config {
  desired_size = 1    # Initial nodes
  min_size     = 1    # Minimum nodes (never go below)
  max_size     = 4    # Maximum nodes (CA can scale up to 4)
}
```

**Complete Scaling Flow:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  SCALING UP FLOW                                                            │
│                                                                             │
│  1. Traffic increases                                                       │
│     │                                                                       │
│     ▼                                                                       │
│  2. Pod CPU > 70% (detected by Metrics Server)                             │
│     │                                                                       │
│     ▼                                                                       │
│  3. HPA creates more pods (1 → 5)                                          │
│     │                                                                       │
│     ▼                                                                       │
│  4. New pods are "Pending" (node full)                                     │
│     │                                                                       │
│     ▼                                                                       │
│  5. Cluster Autoscaler adds EC2 node (1 → 4)                               │
│     │                                                                       │
│     ▼                                                                       │
│  6. Pods scheduled on new node ✅                                          │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  SCALING DOWN FLOW                                                          │
│                                                                             │
│  1. Traffic decreases                                                       │
│     │                                                                       │
│     ▼                                                                       │
│  2. Pod CPU < 70% (stabilization: 5min)                                    │
│     │                                                                       │
│     ▼                                                                       │
│  3. HPA removes pods (5 → 1)                                               │
│     │                                                                       │
│     ▼                                                                       │
│  4. Node underutilized < 50% (stabilization: 5min)                         │
│     │                                                                       │
│     ▼                                                                       │
│  5. Cluster Autoscaler terminates EC2 node (4 → 1)                         │
│     │                                                                       │
│     ▼                                                                       │
│  6. Cost savings! ✅                                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Validation Commands:**
```bash
# Check Cluster Autoscaler logs
kubectl logs -n kube-system -l app.kubernetes.io/name=cluster-autoscaler --tail=50

# Check current nodes
kubectl get nodes

# Watch node scaling
kubectl get nodes -w

# Check node resources
kubectl top nodes
```

#### Load Testing HPA & Cluster Autoscaler

This section describes how to test and validate that HPA and Cluster Autoscaler are working correctly.

**Prerequisites:**
- Metrics Server is running (`kubectl get pods -n kube-system | grep metrics-server`)
- HPA is enabled for the service (`kubectl get hpa -n ecommerce`)
- Cluster Autoscaler is running (`kubectl get pods -n kube-system | grep cluster-autoscaler`)

**Step 1: Set Up Monitoring (Terminal 1)**

Open a terminal to watch HPA scaling in real-time:
```bash
# Watch HPA scaling
kubectl get hpa -n ecommerce -w
```

**Step 2: Set Up Node Monitoring (Terminal 2)**

Open another terminal to watch node scaling:
```bash
# Watch nodes
kubectl get nodes -w
```

**Step 3: Set Up Pod Monitoring (Terminal 3)**

Open another terminal to watch pods:
```bash
# Watch pods (auth service example)
kubectl get pods -n ecommerce -l app=auth -w
```

**Step 4: Generate CPU Load (Terminal 4)**

Run a load generator pod to stress the auth-service:
```bash
# Create a load generator pod
kubectl run -i --tty load-generator --rm --image=busybox:1.36 --restart=Never -n ecommerce -- /bin/sh -c "
while true; do
  wget -q -O- http://auth-svc:9030/actuator/health > /dev/null 2>&1
done
"
```

**Alternative: High-Intensity Load Testing**

For more intense load testing using multiple parallel requests:
```bash
# Run 10 parallel load generators
for i in $(seq 1 10); do
  kubectl run load-gen-$i --image=busybox:1.36 --restart=Never -n ecommerce -- /bin/sh -c "
    while true; do
      wget -q -O- http://auth-svc:9030/actuator/health > /dev/null 2>&1
    done
  " &
done
```

**Step 5: Observe Scaling Behavior**

Expected behavior when load increases:

| Time | What Happens | Where to See |
|------|--------------|--------------|
| 0-60s | CPU increases from ~30% to >70% | `kubectl top pods -n ecommerce` |
| 60-120s | HPA detects high CPU, creates new pods | Terminal 1 (HPA watch) |
| 120-180s | Pods in Pending state (if node full) | Terminal 3 (Pod watch) |
| 180-300s | Cluster Autoscaler adds new node | Terminal 2 (Node watch) |
| 300s+ | Pending pods scheduled on new node | Terminal 3 (Pod watch) |

**Step 6: Monitor Resource Usage**

Check real-time CPU/Memory usage:
```bash
# Pod resource usage
kubectl top pods -n ecommerce

# Node resource usage
kubectl top nodes

# Detailed HPA status
kubectl describe hpa auth-hpa -n ecommerce
```

**Step 7: Clean Up Load Generators**

After testing, clean up the load generator pods:
```bash
# Delete single load generator
kubectl delete pod load-generator -n ecommerce --ignore-not-found

# Delete multiple load generators
kubectl delete pods -n ecommerce -l run=load-gen --ignore-not-found
for i in $(seq 1 10); do
  kubectl delete pod load-gen-$i -n ecommerce --ignore-not-found
done
```

**Step 8: Observe Scale Down**

After removing load:
1. Wait 5 minutes (HPA stabilization window)
2. HPA will scale pods down (5 → 1)
3. Wait another 5 minutes (CA stabilization window)
4. Cluster Autoscaler will remove underutilized nodes (4 → 1)

**Troubleshooting:**

| Issue | Cause | Fix |
|-------|-------|-----|
| HPA shows `<unknown>` CPU | Metrics Server not running | `kubectl get pods -n kube-system \| grep metrics` |
| HPA not scaling | CPU below threshold | Increase load or lower `targetCPUUtilization` |
| Pods stuck in Pending | Node full, CA not scaling | Check CA logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=cluster-autoscaler` |
| Nodes not scaling | Node group at max_size | Increase `max_size` in Terraform node group |

**HPA Scaling Formula:**

```
desiredReplicas = ceil[currentReplicas × (currentMetricValue / desiredMetricValue)]

Example:
- Current replicas: 1
- Current CPU: 140%
- Target CPU: 70%
- Desired replicas = ceil(1 × 140/70) = ceil(2.0) = 2 pods
```

#### Service Accounts & RBAC

Service Accounts provide identity for pods to authenticate with the Kubernetes API and external services (like AWS). Each microservice has its own Service Account following the **principle of least privilege**.

**Service Accounts:**

| Service Account | Used By | Purpose |
|-----------------|---------|---------|
| `gateway-sa` | API Gateway | Service discovery, list endpoints |
| `auth-sa` | Auth Service | Read secrets for JWT/credentials |
| `product-sa` | Product Service | S3 access for product images (IRSA) |
| `order-sa` | Order Service | SQS access for order queue (IRSA) |
| `cart-sa` | Cart Service | Basic K8s API access |
| `category-sa` | Category Service | Basic K8s API access |
| `user-sa` | User Service | Basic K8s API access |
| `notification-sa` | Notification Service | SES access for emails (IRSA) |
| `registry-sa` | Eureka | Service discovery |
| `web-app-sa` | Frontend | No K8s API access (most restricted) |

**RBAC Roles:**

| Role | Permissions | Bound To |
|------|-------------|----------|
| `service-discovery-role` | List services, endpoints, pods | gateway-sa, registry-sa |
| `secret-reader-role` | Read secrets | auth-sa |
| `configmap-reader-role` | Read configmaps | All backend services |

**Use Cases:**

1. **Pod-to-API-Server Authentication**: Pods authenticate to K8s API using mounted service account tokens
2. **AWS IAM Roles for Service Accounts (IRSA)**: Pods assume AWS IAM roles without access keys
3. **Least Privilege Security**: Each service gets only the permissions it needs
4. **Audit & Compliance**: Track which service identity performed actions

**Validation Commands:**
```bash
# List service accounts
kubectl get serviceaccounts -n ecommerce

# Check pod's service account
kubectl get pods -n ecommerce -o custom-columns='POD:metadata.name,SA:spec.serviceAccountName'

# Test RBAC permissions
kubectl auth can-i list services -n ecommerce --as=system:serviceaccount:ecommerce:gateway-sa
```

#### CoreDNS (Cluster DNS)

CoreDNS is automatically installed by EKS and provides DNS resolution for service discovery within the cluster.

**How Services Communicate:**
```
┌─────────────┐   DNS Query    ┌─────────────┐   Returns IP   ┌─────────────┐
│ gateway-pod │ ─────────────► │  CoreDNS    │ ─────────────► │  auth-svc   │
│             │  "auth-svc"    │             │  "10.0.1.15"   │  10.0.1.15  │
└─────────────┘                └─────────────┘                └─────────────┘
```

**DNS Names for Services:**

| Service | Short DNS (same namespace) | Full FQDN |
|---------|---------------------------|-----------|
| Auth | `auth-svc` | `auth-svc.ecommerce.svc.cluster.local` |
| Gateway | `gateway-svc` | `gateway-svc.ecommerce.svc.cluster.local` |
| Registry | `registry-svc` | `registry-svc.ecommerce.svc.cluster.local` |

**Validation Commands:**
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution from a pod
kubectl exec -it <pod-name> -n ecommerce -- nslookup auth-svc
```

### Terraform (Infrastructure as Code)

- Infrastructure provisioned using Terraform, ensuring reproducibility and automation.
- Terraform manage:
  - [VPC](./terraform/vpc.tf) ([subnets](./terraform/vpc-subnets.tf), [Internet Gateway](./terraform/vpc-internet-gateway.tf), [NAT Gateway](/terraform/vpc-nat-gateway.tf), [route tables](./terraform/vpc-route-tables.tf)).
  - [EKS Cluster](./terraform/eks-cluster.tf) (Control Plane, [Managed Node Groups](./terraform/eks-node-groups.tf), [Access Entry]((./terraform/eks-access-entries.tf)), [Metrics-server](./terraform/eks-metrics-server.tf), [Application Load Balancer Controller](./terraform/eks-alb-controller.tf), [Cluster Autoscaler](./terraform/eks-cluster-autoscaler.tf)).
  - [ECR Repositories](./terraform/ecr_registries.tf) for storing Docker images.

### CI/CD with GitHub Actions

- [Separate workflow files](./.github/workflows) per service for isolation and independent deployments.
- Workflow stages:
  - Build & test
  - Build Docker image and push to ECR
  - Deploy/update Helm release on EKS

## 🖥️ How to run locally?

### Prerequistics

Make sure you have the following tools installed locally:
- JAVA Development Kit (JDK 21)
- Maven
- Node.js
- npm
- Git
  
### Step 1: Fork and Clone the Repository

1. Fork the repository to your GitHub account.

2. Clone the forked repository to your local machine.

```bash
git clone https://github.com/<your-username>/Fullstack-E-commerce-web-application
```


### Step 2: Setting up databases.

1. Create the following databases in MongoDB Atlas and update the `spring.data.mongodb.uri` value in `application.yml` file of each service:

- `purely_auth_service`
- `purely_category_service`
- `purely_product_service`
- `purely_cart_service`
- `purely_order_service`

2. You can find sample data for products and categories to get started [here](./sample-data/).

### Step 3: Setting up e-mail configurations

1. In the `notification-service`, configure the following credentials in the [`application.properties`](./microservice-backend/notification-service/src/main/resources/application.properties) file to enable email sending functionality:

```properties
spring.mail.username=YOUR_USERNAME
spring.mail.password=YOUR_PASSWORD
```

Replace `YOUR_USERNAME` and `YOUR_PASSWORD` with your actual email service credentials.

### Step 4: Run the microservices.

1. First run [`service-registry`](./microservice-backend/service-registry/). Access the Eureka dashboard at [`http://localhost:8761`](http://localhost:8761). Next run the other services. 

```
mvn springboot:run
```

2. Make sure all the services are up and running in the [Eureka Dashboard](http://localhost:8761) as below.
   
<img width="960" alt="Eureka Dashboard" src="assets/eureka-dashboard.png" />

### Step 5: Run the frontend

1. Navigate to [frontend direcory](./frontend/).
```
cd ./frontend
```

2. Install dependencies.
```
npm install
```

3. Update API_BASE_URL in [`apiConfig.js`](/frontend/src/api-service/apiConfig.jsx).

```js
const API_BASE_URL =  "http://localhost:8080"
```

3. Run the app.
```
npm run dev
```

Access the application at [`http://localhost:5173/`](http://localhost:5173/)

## ☁️ How to deploy to Amazon EKS?

### Prerequistics

Make sure you have the following tools installed locally:
- kubectl
- Helm
- AWS CLI
- ekctl
- Terraform

### Step 1: Containerization

- Each component (frontend, service-registry, api-gateway, and microservices) has its own Dockerfile.
- You don’t need to change anything here. The components will be automatically built and push images to Amazon ECR when running CI/CD.
  
### Step 2: Kubernetes Orchestration

- Each service is deployed as a separate Helm chart under [`/helm-charts`](`/helm-charts`) directory. Leave them as that.
- No need to modify the chart structure unless adding new services or debugging purposes.

### Step 3: AWS Infrastructure  

- AWS resources are provisioned using Terraform manifests in the [`terraform/`](terraform/) directory.
- By default, you can’t directly access an eks cluster without the **AmazonEKSClusterAdminPolicy**.
  - For each user who needs access (root, GitHub Actions IAM user, local AWS CLI user), you must create an access entry in the cluster.
  - In this project:  Access entries are defined in [`terraform/eks_access_entry.tf`](terraform/eks_access_entry.tf).
  - Update IAM usernames for GitHub Actions and local CLI in [terraform/variables.tf](terraform/variables.tf).

- Then, run the following commands:
  
```
terraform init
terraform plan
terraform apply
```

- This will create a VPC, subnets (2 public, 2 private), an Internet Gateway, a NAT Gateway, and route tables. You can verify the networking setup from `AWS console > VPC > Resource Map`.

<img width="960" alt="VPC Resource Map" src="assets/vpc-resource-map.png" />

- This will deploy an EKS cluster (purely-cluster), EKS node groups, Application Load Balancer controller, Metrics server, and Cluster autoscaler.
- After Terraform finishes, update your kubeconfig (Ensure the local AWS CLI user has an access entry in the EKS cluster.

```
aws eks update-kubeconfig --region YOUR_REGION --name YOUR_CLUSTER_NAME
```

<img width="960" alt="Update kubeconfig" src="assets/update-kube-config.png" />

- Next, ensure that nodes, Application Load Balancer controller, Metrics server, and Cluster autoscaler are installed properly.

<img width="960" alt="EKS Cluster" src="assets/verify-cluster-kube-system.png" />

### Step 4: CI/CD with GitHub Actions

- IAM User for CI/CD
  - Create an IAM user with permissions to EKS and ECR.
  - Ensure this user has an access entry in the EKS cluster.
- Add the following secrets to your GitHub repository:

| Secret | Value |
| ------- | -------- |
| `AWS_ACCESS_KEY_ID` | Access key of IAM user|
| `AWS_REGION` | `us-east-1` (unless you’re using a different AWS region) |
| `AWS_SECRET_ACCESS_KEY` | Secret access key of IAM user |
|`ECR_AUTH_REPOSITORY`| `purely_auth_registry` (unless you're using a different name for ECR repository of Auth service) |
| `ECR_CART_REPOSITORY` | `purely_cart_registry` (unless you're using a different name for ECR repository of Cart service) |
| `ECR_CATEGORY_REPOSITORY` | `purely_category_registry` (unless you're using a different name for ECR repository of Category service) |
| `ECR_GATEWAY_REPOSITORY` | `purely_gayeway_registry` (unless you're using a different name for ECR repository of API Gateway) |
| `ECR_NOTIFICATION_REPOSITORY` | `purely_notification_registry` (unless you're using a different name for ECR repository of Notification service) |
| `ECR_ORDER_REPOSITORY` | `purely_order_registry` (unless you're using a different name for ECR repository of Order service) |
| `ECR_PRODUCT_REPOSITORY` |  `purely_product_registry` (unless you're using a different name for ECR repository of Product service) |
| `ECR_REGISTRY_REPOSITORY` | `purely_service_registry` (unless you're using a different name for ECR repository of Service Registry)  |
| `ECR_USER_REPOSITORY` | `purely_user_registry` (unless you're using a different name for ECR repository of User service)  |
| `ECR_WEB_REPOSITORY` | `purely_web_registry` (unless you're using a different name for ECR repository of Frontend)  |
| `EKS_CLUSTER` |  `purely-cluster` (unless you're using a different name for EKS cluster) |
| `SPRING_DATA_MONGODB_URI_AUTH` | Database URI of auth service from MongoDB Atlas |
| `SPRING_DATA_MONGODB_URI_CART` |  Database URI of cart service from MongoDB Atlas |
| `SPRING_DATA_MONGODB_URI_CATEGORY` | Database URI of category service from MongoDB Atlas |
| `SPRING_DATA_MONGODB_URI_ORDER` | Database URI of order service from MongoDB Atlas |
| `SPRING_DATA_MONGODB_URI_PRODUCT` | Database URI of product service from MongoDB Atlas |
| `SPRING_MAIL_PASSWORD` | Your mail app password  |
| `SPRING_MAIL_USERNAME` | Your mail |

- Each service has its own workflow file (ensuring isolation). Trigger workflows from GitHub Actions. Once completed, services will be live in your EKS cluster.

✅ Deployment Complete!

- Verify cluster resources:
  - Nodes
<img width="960" alt="Verify Nodes" src="assets/verify-nodes.png" />

  - Deployment
<img width="960" alt="Verify Deployment" src="assets/verify-deployments.png" />

  - Horizontal Pod Autoscaler
<img width="960" alt="Verify HPA" src="assets/verify-hpa.png" />

  - Service
<img width="960" alt="Verify Service" src="assets/verify-svc.png" />

  - Ingress
<img width="960" alt="Verify Ingress" src="assets/verify-ingress.png" />

<img width="960" alt="Describe Ingress" src="assets/ingress-describe.png" /> 

  - Verify the Eureka server via port forwarding
<img width="960" alt="Eureka Dashboard Port forward" src="assets/verify-eureka.png" />

<img width="960" alt="Eureka Dashboard" src="assets/eureka-dashboard-port-forward.png" /> 

Copy the Ingress DNS address from the `kubectl get ingress` and open it in your browser to view the live application.

## Demo video

https://github.com/user-attachments/assets/d648cb16-6008-44b0-ad2a-b6752df40702
# Test
#   T e s t   c o m m e n t 
 
 

# BASE (values.yaml) - COMPLETE with all settings
web:
  label: web-app              # ← Stays (not in override)
  replicas: 3                 # ← OVERWRITTEN by dev
  containerPort: 80           # ← Stays (not in override)
  image:
    repository: ...           # ← Stays (not in override)
  resources:
    requests:
      cpu: 100m               # ← OVERWRITTEN by dev (50m)
      memory: 128Mi           # ← OVERWRITTEN by dev (64Mi)
  autoscaling:
    enabled: true             # ← OVERWRITTEN by dev (false)
    minReplicas: 3            # ← Stays (not in override)
    maxReplicas: 20           # ← Stays (not in override)
  service:
    type: ClusterIP           # ← Stays (not in override)
    port: 80                  # ← Stays (not in override)
  pdb:
    enabled: true             # ← OVERWRITTEN by dev (false)
  healthCheck:
    path: /                   # ← Stays (not in override)
  affinity:
    enabled: true             # ← OVERWRITTEN by dev (false)

# OVERRIDE (dev/web-app.yaml) - Only differences
web:
  replicas: 1                 # Override: 3 → 1
  resources:
    requests:
      cpu: 50m                # Override: 100m → 50m
      memory: 64Mi            # Override: 128Mi → 64Mi
  autoscaling:
    enabled: false            # Override: true → false
  pdb:
    enabled: false            # Override: true → false
  affinity:
    enabled: false            # Override: true → false
config:
  VITE_API_GATEWAY_URL: http://localhost:8080  # Override URL


  GitHub → Settings → Environments

├── production (current)
│   └── Secrets:
│       ├── AWS_ACCESS_KEY_ID (prod account)
│       ├── AWS_SECRET_ACCESS_KEY (prod account)
│       ├── EKS_CLUSTER: prod-eks-cluster
│       └── ECR_WEB_REPOSITORY: web-app
│
└── dev (new - for dev account)
    └── Secrets:
        ├── AWS_ACCESS_KEY_ID (dev account)
        ├── AWS_SECRET_ACCESS_KEY (dev account)
        ├── EKS_CLUSTER: dev-eks-cluster
        └── ECR_WEB_REPOSITORY: web-app


        ┌─────────────────────────────────────────────────────────────────────────────┐
│                           HELM CHART STRUCTURE                               │
│                                                                              │
│  helm-charts/api-gateway/                                                   │
│  │                                                                           │
│  ├── templates/                    ← TEMPLATES (Reusable for ALL envs)      │
│  │   ├── deployment.yaml           ← Has {{ .Values.xxx }} placeholders     │
│  │   ├── service.yaml              ← Has {{ .Values.xxx }} placeholders     │
│  │   ├── configmap.yaml            ← Has {{ .Values.xxx }} placeholders     │
│  │   └── hpa.yaml                  ← Has {{ .Values.xxx }} placeholders     │
│  │                                                                           │
│  └── values.yaml                   ← DEFAULT VALUES (Production)            │
│                                                                              │
│  environments/                                                               │
│  ├── dev/api-gateway.yaml          ← VALUE OVERRIDES ONLY (not templates)   │
│  ├── qa/api-gateway.yaml           ← VALUE OVERRIDES ONLY (not templates)   │
│  └── prod/api-gateway.yaml         ← VALUE OVERRIDES ONLY (if needed)       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘


manual steps I have done

before we deploy the helm charts and required k8s config
during the aws resource creation we need to create kubectl
awscli v2, helm etc... required services on bastion host

# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Make it executable
chmod +x kubectl

# Move to PATH
sudo mv kubectl /usr/local/bin/

# Verify installation
kubectl version --client

if you get this kind of issue , its a aws cli issue mostly

error: exec plugin: invalid apiversion "client.authentication.k8s.io/v1alpha1"

need to upgrade to aws cli v2 the update the kube config

# Delete old kubeconfig
rm -f ~/.kube/config

# Regenerate kubeconfig with new API version
aws eks update-kubeconfig --region us-east-1 --name SAP-dev-eksdemo

then now i can able to get the kubectl get nodes command

1. Service Registry  → Base service discovery
2. Auth Service      → Authentication
3. User Service      → User management
4. Category Service  → Product categories
5. Product Service   → Product catalog
6. Cart Service      → Shopping cart
7. Order Service     → Order processing
8. Notification Service → Notifications
9. API Gateway       → Routes all traffic
10. Web App          → Frontend
11. Ingress ALB      → Load balancer routing

auth pods in pending state due to insufficient cpu

need to check the pod describe status and do the helm commands frm bastion host

# Check the release status
helm status service-registry -n ecommerce

# Rollback to previous version (or initial state)
helm rollback service-registry 0 -n ecommerce

# Or for auth-service
helm rollback auth-service 0 -n ecommerce

# Delete the stuck release
helm uninstall service-registry -n ecommerce --no-hooks

# Or if that doesn't work, delete with kubectl
kubectl delete secret -l owner=helm,name=service-registry -n ecommerce

# Then re-run the CI/CD workflow


# Check what's happening
helm list -n ecommerce -a

# Check for pending operations
kubectl get all -n ecommerce

# Check pods status
kubectl get pods -n ecommerce

# Clean up all stuck releases in ecommerce namespace
for release in $(helm list -n ecommerce -a --pending -q); do
  echo "Rolling back $release..."
  helm rollback $release 0 -n ecommerce || helm uninstall $release -n ecommerce --no-hooks
done

# Verify
helm list -n ecommerce -a

below commands we need to run when pods getting the createconfigmaperror

# Delete existing auth deployment and HPA
kubectl delete hpa auth-hpa -n ecommerce --ignore-not-found
kubectl delete deployment auth-depl -n ecommerce --ignore-not-found
kubectl delete pods -l app=auth -n ecommerce --force --grace-period=0

# Delete stuck helm release
helm uninstall auth-service -n ecommerce --no-hooks 2>/dev/null || true
kubectl delete secret -l owner=helm,name=auth-service -n ecommerce --ignore-not-found

# Verify cleanup
kubectl get all -n ecommerce
helm list -n ecommerce -a

# Clean up auth resources
helm uninstall auth-service -n ecommerce --no-hooks 2>/dev/null || true
kubectl delete deployment auth-depl -n ecommerce --ignore-not-found
kubectl delete pods -l app=auth -n ecommerce --force --grace-period=0
kubectl delete configmap auth-config-map -n ecommerce --ignore-not-found
kubectl delete secret auth-secret -n ecommerce --ignore-not-found

# Verify configmaps exist
kubectl get configmap -n ecommerce
kubectl get secret -n ecommerce

# Check if namespace exists
kubectl get namespace ecommerce


the error we got in auth service related to mongodb secret mismatch 

pod showing the below status

Back-off restarting failed container auth-container in pod auth-depl-645f944444-cz7xf_ecommerce(0ea8287d-3ba9-4398-b2c4-d9923130ad4a) and status is crashbacklooppff but it was an application mongodb conn issue

when we dont have db conn from the app pod, we can see the above
error in pod events but pod staus is showing crashbackloopoff

when we are missing some required env values/secrets in configmaps or secrets we getting the  pod status below

gateway-depl-7b598bfbc5-c6r8p 0/1 CreateContainerConfigError 0 52s

in events - Error some secret_name cant find

ok, ah specific env var miss aiendi ani findout chesaka
adhi pettesi pipeline run chestey UPGRADE FAILED ani error
ochi pipeline fail avutadi

so, bastion host nundi elanti cases lo few commands run cheyyali

1, delete the deploy of that service
2. uninstall the helm service

appatiki avvakapotey rerun chesaka e below error vastadi

UPGRADE FAILED: another operation is in progress. install/ugrade

dhanniki e cmnds run cheyali

# Check the status of the release
helm status api-gateway -n ecommerce

# List all releases and their status
helm list -n ecommerce -a

# If the release is stuck in "pending-install" or "pending-upgrade", rollback:
helm rollback api-gateway -n ecommerce

# Or if it's stuck badly, uninstall and let the workflow redeploy:
helm uninstall api-gateway -n ecommerce

appatiki avvakaunda e belowe error vastey

status - pending-install when I run above rollback command getting the below eerror

ERROR: release has no 0 version

# Force delete the stuck release
helm uninstall api-gateway -n ecommerce --no-hooks

# If that fails, delete the secret that tracks the release
kubectl delete secret -l name=api-gateway,owner=helm -n ecommerce

E paina 2 commands run chestey helm list nundi chart del ipothundi

------------

eadaina pod lo health check probes fail ipoiena sare crashloop
backoff error vastadi status lo
alaney backoff error tho paatu liveness probes fail ayyayi ani chupistadi events lo

dhiniki app code changes/sg rules check cheskoni resolve cheyyali
e error lo 0/1 chupisthundi READY daggara

-----

ALB auto-generates rules - When you use pathType: Prefix, the ALB Load Balancer Controller automatically creates multiple listener rules to handle the prefix matching properly

when we see below in secrets

sh.helm.release.v1.api-gateway.v1    helm.sh/release.v1
sh.helm.release.v1.api-gateway.v2    helm.sh/release.v1
sh.helm.release.v1.cart-service.v1   helm.sh/release.v1

# First deployment
helm install api-gateway helm-charts/api-gateway
# Creates: sh.helm.release.v1.api-gateway.v1

# Second deployment (upgrade)
helm upgrade api-gateway helm-charts/api-gateway
# Creates: sh.helm.release.v1.api-gateway.v2

# Third deployment
helm upgrade api-gateway helm-charts/api-gateway
# Creates: sh.helm.release.v1.api-gateway.v3

when we do helm rollback it back to the previous versions
of services, deployments, rs, pods


# Check current history
helm history api-gateway -n ecommerce

# Output:
# REVISION  STATUS      DESCRIPTION
# 1         superseded  Install complete
# 2         superseded  Upgrade complete
# 3         deployed    Upgrade complete    ← Current

# Rollback to revision 1
helm rollback api-gateway 1 -n ecommerce

# Check history again
helm history api-gateway -n ecommerce

# Output:
# REVISION  STATUS      DESCRIPTION
# 1         superseded  Install complete
# 2         superseded  Upgrade complete
# 3         superseded  Upgrade complete
# 4         deployed    Rollback to 1       ← New current (same as v1)

That's Kubernetes default behavior! When you don't specify a strategy, Kubernetes automatically applies these defaults:

Kubernetes Default Strategy

spec:
  strategy:
    type: RollingUpdate      # Default (not Recreate)
    rollingUpdate:
      maxSurge: 25%          # Default
      maxUnavailable: 25%    # Default

      You don't need to add strategy if defaults work for you. But I added explicit values to your web-app for:

Clarity - Anyone reading knows the intent
Consistency - Same behavior regardless of replica count
Documentation - Self-documenting infrastructure
The change I made earlier to web-app deployment just makes the implicit default explicit.

# This should work for Eureka
kubectl exec -it $(kubectl get pod -n ecommerce -l app=auth -o jsonpath='{.items[0].metadata.name}') -n ecommerce -- curl -s http://registry-svc:80/eureka/apps 

the abpve coomand used to test the conn between the pod to pod
here we did for auth pod conecting to registry or not. connected
it generates a some xml content for confirmaion

that port is mandatory , we need to get heat from the srvc ports


test pod to pod communication b/w diff nodes

kubectl exec -it deploy/auth -n ecommerce -- /bin/sh -c "curl -s http://registry-svc:80/actuator/health"

will get the xml kind of file if we can access
