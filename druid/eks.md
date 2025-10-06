# EKS Cluster

## Overview

The EKS (Elastic Kubernetes Service) cluster provides the Kubernetes orchestration platform for running Apache Druid and all supporting services. This cluster is configured with managed addons, custom Helm charts, and intelligent autoscaling via Karpenter.

## Cluster Configuration

### Core Settings

**Kubernetes Version**: `1.33`

**Cluster Name**: `{hosted:id}-eks`
- Example: `fff-eks`

**Endpoint Access**: Public and Private
- Public: Allows kubectl access from anywhere
- Private: Enables nodes to communicate with control plane privately

**Control Plane Logging**: Complete audit trail
- API server logs
- Audit logs
- Authenticator logs
- Controller manager logs
- Scheduler logs

### How Configuration is Used

**Input (cdk.context.json)**:
```json
{
  "deployment:id": "fff",
  "deployment:region": "us-west-2"
}
```

**Template (eks section in conf.mustache)**:
```yaml
eks:
  name: {{deployment:id}}-eks        # fff-eks
  version: "1.33"
  endpointAccess: public_and_private
  prune: true
  loggingTypes:
    - api
    - audit
    - authenticator
    - controller_manager
    - scheduler
```

**CDK Construct Used**: AWS CDK [`Cluster`](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_eks.Cluster.html)

**What gets created**:
```java
// EKS Cluster using CDK L2 Construct
Cluster.Builder.create(this, "EksCluster")
  .clusterName("fff-eks")
  .version(KubernetesVersion.V1_33)
  .vpc(vpc)
  .vpcSubnets(Arrays.asList(
    SubnetSelection.builder().subnetType(SubnetType.PUBLIC).build(),
    SubnetSelection.builder().subnetType(SubnetType.PRIVATE_WITH_EGRESS).build()
  ))
  .endpointAccess(EndpointAccess.PUBLIC_AND_PRIVATE)
  .clusterLogging(Arrays.asList(
    ClusterLoggingTypes.API,
    ClusterLoggingTypes.AUDIT,
    ClusterLoggingTypes.AUTHENTICATOR,
    ClusterLoggingTypes.CONTROLLER_MANAGER,
    ClusterLoggingTypes.SCHEDULER
  ))
  .build();
```

## AWS Managed Addons

### 1. VPC CNI (Container Network Interface)

**Purpose**: Provides pod networking using AWS VPC IP addresses

**Version**: `v1.20.1-eksbuild.3`

**Configuration**:
```yaml
awsVpcCni:
  name: vpc-cni
  version: v1.20.1-eksbuild.3
  preserveOnDelete: false
  resolveConflicts: preserve
```

**Service Account with IRSA**:
```yaml
serviceAccount:
  name: aws-node
  namespace: kube-system
  role:
    name: {id}-vpc-cni
    managedPolicyNames:
      - AmazonEKS_CNI_Policy
```

**What it does**:
- Assigns VPC IP addresses to pods
- Enables pods to communicate directly with AWS services
- Manages ENI (Elastic Network Interface) allocation
- Supports security groups for pods

**CloudFormation Resources Created**:
- IAM Role: `{id}-vpc-cni`
- IAM Policy attachment: `AmazonEKS_CNI_Policy`
- Kubernetes ServiceAccount: `aws-node` in `kube-system` namespace

### 2. EBS CSI Driver

**Purpose**: Manages Amazon EBS volumes for persistent storage

**Version**: `v1.48.0-eksbuild.1`

**Configuration**:
```yaml
awsEbsCsi:
  name: aws-ebs-csi-driver
  version: v1.48.0-eksbuild.1
  serviceAccount:
    name: ebs-csi-controller-sa
    namespace: kube-system
    role:
      name: {id}-aws-ebs-csi-sa
      managedPolicyNames:
        - service-role/AmazonEBSCSIDriverPolicy
      customPolicies:
        - name: {id}-eks-ebs-encryption
          policy: policy/kms-eks-ebs-encryption.mustache
```

**KMS Encryption**:
```yaml
kms:
  alias: {id}-eks-ebs-encryption
  description: "eks ebs csi volume encryption"
  enabled: true
  enableKeyRotation: false
  keyUsage: encrypt_decrypt
  keySpec: symmetric_default
```

**Default Storage Class**:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  kmsKeyId: alias/{id}-eks-ebs-encryption
volumeBindingMode: WaitForFirstConsumer
```

**What it does**:
- Dynamically provisions EBS volumes for PersistentVolumeClaims
- Encrypts volumes using KMS
- Manages volume lifecycle (create, attach, detach, delete)
- Supports volume snapshots and resizing

**CloudFormation Resources Created**:
- KMS Key: `alias/{id}-eks-ebs-encryption`
- IAM Role: `{id}-aws-ebs-csi-sa`
- IAM Policy: `{id}-eks-ebs-encryption` (custom KMS policy)
- StorageClass: `ebs-sc` (set as default)

### 3. CoreDNS

**Purpose**: Kubernetes cluster DNS for service discovery

**Version**: `v1.12.3-eksbuild.1`

**Configuration**:
```yaml
coreDns:
  name: coredns
  version: v1.12.3-eksbuild.1
  preserveOnDelete: false
  resolveConflicts: overwrite
```

**What it does**:
- Resolves Kubernetes service names to cluster IPs
- Provides DNS for pod-to-pod communication
- Caches DNS queries for performance

### 4. Kube-proxy

**Purpose**: Network proxy that maintains network rules on nodes

**Version**: `v1.33.3-eksbuild.6`

**Configuration**:
```yaml
kubeProxy:
  name: kube-proxy
  version: v1.33.3-eksbuild.6
  preserveOnDelete: false
  resolveConflicts: overwrite
```

**What it does**:
- Manages iptables rules for service routing
- Enables service discovery and load balancing
- Routes traffic to correct pod backends

### 5. Pod Identity Agent

**Purpose**: Provides IAM roles for service accounts (IRSA)

**Version**: `v1.3.8-eksbuild.2`

**Configuration**:
```yaml
podIdentityAgent:
  name: eks-pod-identity-agent
  version: v1.3.8-eksbuild.2
  preserveOnDelete: false
  resolveConflicts: overwrite
```

**What it does**:
- Injects AWS credentials into pods based on service account annotations
- Enables pods to assume IAM roles
- Provides temporary security credentials
- Essential for all AWS service integrations (S3, RDS, MSK, etc.)

### 6. CloudWatch Container Insights

**Purpose**: AWS-native monitoring and observability

**Version**: `v4.3.1-eksbuild.1`

**Configuration**:
```yaml
containerInsights:
  name: amazon-cloudwatch-observability
  version: v4.3.1-eksbuild.1
  serviceAccount:
    name: cloudwatch-agent
    namespace: amazon-cloudwatch
    role:
      name: {id}-cloudwatch-agent-sa
      managedPolicyNames:
        - CloudWatchAgentServerPolicy
        - AWSXrayWriteOnlyAccess
```

**What it does**:
- Collects metrics from containers and nodes
- Ships logs to CloudWatch Logs
- Traces requests with AWS X-Ray
- Provides dashboards for cluster health

**CloudFormation Resources Created**:
- IAM Role: `{id}-cloudwatch-agent-sa`
- Namespace: `amazon-cloudwatch`
- ServiceAccount: `cloudwatch-agent`

## Helm Chart Addons

### 1. Cert-Manager

**Purpose**: Automates TLS certificate management

**Chart**: `jetstack/cert-manager v1.18.2`

**Configuration**:
```yaml
certManager:
  chart:
    name: cert-manager
    repository: https://charts.jetstack.io
    release: cert-manager
    version: v1.18.2
    namespace: cert-manager
```

**What it does**:
- Issues certificates from Let's Encrypt or other ACME providers
- Automatically renews certificates before expiration
- Manages Certificate, Issuer, and ClusterIssuer resources

### 2. CSI Secrets Store Driver

**Purpose**: Mounts secrets from external stores as volumes

**Chart**: `secrets-store-csi-driver v1.4.8`

**Configuration**:
```yaml
csiSecretsStore:
  chart:
    name: secrets-store-csi-driver
    repository: https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
    release: csi-secrets
    version: 1.4.8
    namespace: aws-secrets-store
```

**What it does**:
- Provides CSI driver interface for secrets
- Mounts secrets as files in pod volumes
- Syncs secrets to Kubernetes secrets (optional)

### 3. AWS Secrets Store Provider

**Purpose**: AWS-specific provider for CSI Secrets Store

**Chart**: `aws/secrets-store-csi-driver-provider-aws v1.0.1`

**Configuration**:
```yaml
awsSecretsStore:
  chart:
    name: secrets-store-csi-driver-provider-aws
    repository: https://aws.github.io/secrets-store-csi-driver-provider-aws
    release: aws-secrets
    version: 1.0.1
    namespace: aws-secrets-store
```

**What it does**:
- Fetches secrets from AWS Secrets Manager
- Fetches parameters from SSM Parameter Store
- Provides secrets to pods as mounted files

### 4. Karpenter

**Purpose**: Advanced Kubernetes cluster autoscaler

**Chart**: `karpenter/karpenter v1.6.3`

**Configuration**:
```yaml
karpenter:
  chart:
    name: karpenter
    repository: oci://public.ecr.aws/karpenter/karpenter
    release: karpenter
    version: 1.6.3
    namespace: kube-system
```

**Pod Identity (IRSA)**:
```yaml
podIdentity:
  metadata:
    name: {id}-karpenter-sa
    namespace: kube-system
  role:
    name: {id}-karpenter-sa
    customPolicies:
      - name: {id}-karpenter
        policy: policy/karpenter.mustache
      - name: {id}-karpenter-interrupt
        policy: policy/karpenter-interrupt.mustache
```

**What it does**:
- Provisions nodes based on pending pod requirements
- Optimizes instance types for workload
- Automatically scales down underutilized nodes
- Handles spot instance interruptions via SQS
- Much faster than Cluster Autoscaler (seconds vs minutes)

**CloudFormation Resources Created**:
- IAM Role: `{id}-karpenter-sa`
- IAM Policies: `{id}-karpenter`, `{id}-karpenter-interrupt`
- SQS Queue: `{id}-karpenter` (for interruption handling)

### 5. AWS Load Balancer Controller

**Purpose**: Manages AWS ALB/NLB from Kubernetes

**Chart**: `aws/aws-load-balancer-controller v1.13.4`

**Configuration**:
```yaml
awsLoadBalancer:
  chart:
    name: aws-load-balancer-controller
    repository: https://aws.github.io/eks-charts
    release: aws-load-balancer-controller
    version: 1.13.4
    namespace: aws-load-balancer
  serviceAccount:
    name: {id}-aws-load-balancer-sa
    namespace: aws-load-balancer
    role:
      name: {id}-aws-load-balancer-sa
      customPolicies:
        - name: {id}-aws-load-balancer-controller
          policy: policy/aws-load-balancer-controller.mustache
```

**What it does**:
- Creates ALB from Kubernetes Ingress resources
- Creates NLB from Kubernetes Service type LoadBalancer
- Manages target groups and routing rules
- Integrates with AWS WAF and AWS Certificate Manager

**CloudFormation Resources Created**:
- IAM Role: `{id}-aws-load-balancer-sa`
- IAM Policy: `{id}-aws-load-balancer-controller`

### 6. Alloy Operator

**Purpose**: Manages Grafana Alloy instances

**Chart**: `grafana/alloy-operator v0.3.8`

**Configuration**:
```yaml
alloyOperator:
  chart:
    name: alloy-operator
    repository: https://grafana.github.io/helm-charts
    release: alloy-operator
    version: 0.3.8
    namespace: alloy-system
```

**What it does**:
- Provides CRDs for Alloy configuration
- Manages Alloy agent lifecycle
- Required by k8s-monitoring chart v3+

### 7. Grafana Kubernetes Monitoring

**Purpose**: Complete observability stack for Kubernetes

**Chart**: `grafana/k8s-monitoring v3.3.2`

**Configuration**:
```yaml
grafana:
  chart:
    name: k8s-monitoring
    repository: https://grafana.github.io/helm-charts
    release: k8s-monitoring
    version: 3.3.2
    namespace: monitoring
```

**Configured with Grafana Cloud endpoints**:
- Prometheus (metrics): `hosted:eks:grafana:prometheusHost`
- Loki (logs): `hosted:eks:grafana:lokiHost`
- Tempo (traces): `hosted:eks:grafana:tempoHost`
- Pyroscope (profiles): `hosted:eks:grafana:pyroscopeHost`
- API Key: `hosted:eks:grafana:key`

**What it does**:
- Deploys Grafana Alloy agents to all nodes
- Collects metrics from kubelet, cAdvisor, kube-state-metrics
- Ships logs from all pods to Loki
- Sends traces to Tempo
- Sends profiling data to Pyroscope

## Node Groups

### Core Node Group

**Name**: `{id}-core-node`

**AMI Type**: Bottlerocket x86_64

**Instance Configuration**:
```yaml
- name: {id}-core-node
  amiType: bottlerocket_x86_64
  instanceClass: m5a
  instanceSize: large       # m5a.large
  capacityType: on_demand
  desiredSize: 2
  minSize: 2
  maxSize: 6
```

**IAM Role**:
```yaml
role:
  name: {id}-core-node
  principal:
    type: service
    value: ec2.amazonaws.com
  managedPolicyNames:
    - AmazonEKSWorkerNodePolicy
    - AmazonEC2ContainerRegistryReadOnly
    - AmazonSSMManagedInstanceCore
```

**Labels**:
```yaml
labels:
  "{domain}/resource-type": node
  "{domain}/category": compute
  "{domain}/type": core-node
  "{domain}/component": eks
  "karpenter.sh/discovery": {id}-vpc
```

**What it does**:
- Provides baseline capacity for the cluster
- Runs system pods (CoreDNS, Karpenter, etc.)
- Uses Bottlerocket OS for security and reliability
- On-demand instances for stability

**CloudFormation Resources Created**:
- EC2 Auto Scaling Group
- Launch Template
- IAM Role: `{id}-core-node`
- IAM Instance Profile

## Access Control

### Administrators

**Input**:
```json
{
  "deployment:eks:administrators": [
    {
      "username": "administrator001",
      "role": "arn:aws:iam::000000000000:role/AWSReservedSSO_AdministratorAccess_abc",
      "email": "admin@example.com"
    }
  ]
}
```

**Creates aws-auth ConfigMap entry**:
```yaml
mapRoles:
  - rolearn: arn:aws:iam::000000000000:role/AWSReservedSSO_AdministratorAccess_abc
    username: administrator001
    groups:
      - system:masters
```

**Grants**:
- Full cluster admin access
- Can create/delete any Kubernetes resources
- Can modify cluster configuration

### Users (Read-only)

**Input**:
```json
{
  "deployment:eks:users": [
    {
      "username": "developer001",
      "role": "arn:aws:iam::000000000000:role/AWSReservedSSO_DeveloperAccess_abc",
      "email": "dev@example.com"
    }
  ]
}
```

**Creates aws-auth ConfigMap entry**:
```yaml
mapRoles:
  - rolearn: arn:aws:iam::000000000000:role/AWSReservedSSO_DeveloperAccess_abc
    username: developer001
    groups:
      - view-only
```

**Grants**:
- Read-only access to most resources
- Can view pods, services, deployments
- Cannot modify cluster state

## Resource Tagging

All EKS resources are tagged:

```yaml
tags:
  "{domain}:resource-type": eks
  "{domain}:category": eks
  "{domain}:type": analytics
  "{domain}:component": {id}-eks
  "{domain}:part-of": "{organization}.{name}.{alias}"
  "karpenter.sh/discovery": {id}-vpc
```

**Special tag**: `karpenter.sh/discovery`
- Enables Karpenter to discover this cluster
- Used to find VPC and subnets for node provisioning

## Stack Outputs

After deployment, the EKS nested stack provides:

```yaml
Outputs:
  ClusterName:
    Value: {id}-eks
    Export: {stackName}-EksClusterName

  ClusterEndpoint:
    Value: https://ABC123.gr7.{region}.eks.amazonaws.com
    Export: {stackName}-EksClusterEndpoint

  ClusterSecurityGroupId:
    Value: sg-abc123
    Export: {stackName}-EksClusterSecurityGroupId

  ClusterOidcIssuer:
    Value: oidc.eks.{region}.amazonaws.com/id/ABC123
    Export: {stackName}-EksClusterOidcIssuer
```

## Accessing the Cluster

### Update kubeconfig

```bash
aws eks update-kubeconfig --name {id}-eks --region {region}
```

**Example**:
```bash
aws eks update-kubeconfig --name fff-eks --region us-west-2
```

### Verify Access

```bash
# Check cluster info
kubectl cluster-info

# List nodes
kubectl get nodes

# List all pods
kubectl get pods -A

# Check addons
kubectl get pods -n kube-system
kubectl get pods -n aws-load-balancer
kubectl get pods -n monitoring
```

## Next Steps

- [Apache Druid Deployment →](druid.md)
- [MSK Integration →](msk.md)
- [Grafana Observability →](grafana.md)
- [VPC Configuration →](vpc.md)
