# Networking Issues

## VPC Connectivity

### Lambda Cannot Access Internet

**Symptoms**:
- Lambda function timeouts when calling external APIs
- Cannot download dependencies from npm/PyPI
- AWS SDK calls timeout

**Diagnosis**:
```bash
# Check Lambda VPC configuration
aws lambda get-function-configuration \
  --function-name <function-name> \
  --query 'VpcConfig'

# Verify NAT Gateways exist and are running
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[*].[NatGatewayId,State,SubnetId]'
```

**Solution**:
1. Verify Lambda attached to private subnets (not public)
2. Verify NAT Gateways running in public subnets
3. Check route tables route `0.0.0.0/0` to NAT Gateway

**WebApp VPC Routes**:
```bash
# Check private subnet route table
aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=*private*" \
  --query 'RouteTables[*].Routes'

# Should show:
# - 192.168.0.0/16 → local
# - 0.0.0.0/0 → nat-gateway
```

### DynamoDB Connection Timeouts from Lambda

**Cause**: Lambda in VPC using NAT Gateway (expensive and slower)

**Solution**: Add DynamoDB VPC Gateway Endpoint

```java
import software.amazon.awscdk.services.ec2.GatewayVpcEndpoint;
import software.amazon.awscdk.services.ec2.GatewayVpcEndpointAwsService;

GatewayVpcEndpoint.Builder.create(this, "DynamoDBEndpoint")
  .vpc(vpc)
  .service(GatewayVpcEndpointAwsService.DYNAMODB)
  .build();
```

**Verify endpoint**:
```bash
aws ec2 describe-vpc-endpoints \
  --filters "Name=service-name,Values=com.amazonaws.us-west-2.dynamodb"
```

## EKS Networking

### Pods Cannot Pull Images from ECR

**Symptoms**:
```
Failed to pull image: 403 Forbidden
```

**Diagnosis**:
```bash
# Check if nodes can reach ECR
kubectl run -it test --image=busybox --restart=Never -- \
  nslookup <account-id>.dkr.ecr.us-west-2.amazonaws.com
```

**Solutions**:

**Option 1**: Add VPC Endpoints for ECR (recommended)
```java
// ECR API endpoint
InterfaceVpcEndpoint.Builder.create(this, "ECRApiEndpoint")
  .vpc(vpc)
  .service(InterfaceVpcEndpointAwsService.ECR)
  .privateDnsEnabled(true)
  .build();

// ECR Docker endpoint
InterfaceVpcEndpoint.Builder.create(this, "ECRDkrEndpoint")
  .vpc(vpc)
  .service(InterfaceVpcEndpointAwsService.ECR_DOCKER)
  .privateDnsEnabled(true)
  .build();

// S3 endpoint (ECR uses S3 for layers)
GatewayVpcEndpoint.Builder.create(this, "S3Endpoint")
  .vpc(vpc)
  .service(GatewayVpcEndpointAwsService.S3)
  .build();
```

**Option 2**: Verify IAM permissions
```bash
# Check node IAM role
aws eks describe-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name> \
  --query 'nodegroup.nodeRole'

# Verify role has AmazonEC2ContainerRegistryReadOnly policy
aws iam list-attached-role-policies --role-name <role-name>
```

### Pods Cannot Communicate with Each Other

**Symptoms**: Service-to-service calls fail

**Diagnosis**:
```bash
# Test pod-to-pod networking
kubectl run test-1 --image=nginx
kubectl run test-2 --image=busybox --restart=Never -it -- \
  wget -O- http://<test-1-pod-ip>
```

**Solutions**:

**Check CNI plugin**:
```bash
# Verify aws-node daemonset running
kubectl get daemonset -n kube-system aws-node

# Check CNI plugin logs
kubectl logs -n kube-system -l k8s-app=aws-node
```

**Check security groups**:
```bash
# Verify cluster security group allows pod communication
aws eks describe-cluster \
  --name <cluster-name> \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId'
```

### LoadBalancer Service Stuck in Pending

**Symptoms**:
```bash
kubectl get svc
# NAME         TYPE           EXTERNAL-IP   PORT(S)
# my-service   LoadBalancer   <pending>     80:31234/TCP
```

**Diagnosis**:
```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n aws-load-balancer deploy/aws-load-balancer-controller

# Check service events
kubectl describe svc <service-name>
```

**Common issues**:
1. AWS Load Balancer Controller not installed
2. IAM permissions missing
3. Subnets not tagged for auto-discovery

**Solution**: Verify subnet tags
```bash
# Public subnets need this tag for ALB:
# kubernetes.io/role/elb = 1

# Private subnets need this tag for NLB:
# kubernetes.io/role/internal-elb = 1

aws ec2 describe-subnets \
  --filters "Name=tag:kubernetes.io/role/elb,Values=1"
```

## DNS Issues

### Cannot Resolve Internal DNS Names

**Symptoms**: Pods cannot resolve service names

**Diagnosis**:
```bash
# Check CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run -it dnstest --image=busybox --restart=Never -- \
  nslookup kubernetes.default
```

**Solutions**:

**Restart CoreDNS**:
```bash
kubectl rollout restart -n kube-system deployment/coredns
```

**Check DNS configuration**:
```bash
# View CoreDNS config
kubectl get configmap -n kube-system coredns -o yaml
```

### Cannot Resolve External DNS Names

**Cause**: VPC DNS settings or CoreDNS configuration

**Check VPC DNS**:
```bash
aws ec2 describe-vpcs \
  --vpc-ids <vpc-id> \
  --query 'Vpcs[*].[EnableDnsSupport,EnableDnsHostnames]'

# Both should be true
```

**Solution**: Verify VPC configuration
```yaml
# In conf.mustache, these should be true:
vpc:
  enableDnsSupport: true
  enableDnsHostnames: true
```

## Security Group Issues

### Connection Refused/Timeout

**Diagnosis**:
```bash
# From source, test connection
kubectl run -it nettest --image=busybox --restart=Never -- \
  nc -zv <target-ip> <port>

# Check security groups
aws ec2 describe-security-groups \
  --group-ids <sg-id>
```

**Common patterns**:

**Allow inbound on port**:
```bash
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port <port> \
  --source-group <source-sg-id>
```

**WebApp API Gateway → Lambda**:
- Lambda security group must allow inbound from API Gateway VPC endpoint security group
- Usually auto-configured by CDK

## MSK (Kafka) Connectivity

### Druid Cannot Connect to MSK

**Symptoms**: Druid MiddleManager pods can't ingest from Kafka

**Diagnosis**:
```bash
# Get MSK bootstrap servers
aws kafka get-bootstrap-brokers \
  --cluster-arn <cluster-arn>

# Test connectivity from pod
kubectl run -n druid kafka-test --image=wurstmeister/kafka:latest -it --rm -- \
  kafka-broker-api-versions.sh --bootstrap-server <bootstrap-servers>
```

**Solutions**:

**Check security group**:
```bash
# MSK security group must allow inbound 9092 (or 9094 for TLS) from EKS nodes
aws kafka describe-cluster --cluster-arn <arn> \
  --query 'ClusterInfo.BrokerNodeGroupInfo.SecurityGroups'
```

**Verify IAM permissions** (MSK Serverless uses IAM):
```bash
# Check Druid service account IAM role has kafka-cluster permissions
kubectl get sa -n druid <druid-sa-name> -o yaml
```

## RDS Connectivity

### Druid Cannot Connect to RDS Metadata Database

**Symptoms**: Druid Coordinator fails to start with database connection errors

**Diagnosis**:
```bash
# Get RDS endpoint
aws rds describe-db-instances \
  --db-instance-identifier <instance-id> \
  --query 'DBInstances[0].Endpoint'

# Test from pod
kubectl run -n druid pg-test --image=postgres:15 -it --rm -- \
  psql -h <rds-endpoint> -U <username> -d druid
```

**Solutions**:

**Check security group**:
```bash
# RDS security group must allow PostgreSQL (5432) from EKS nodes
aws rds describe-db-instances \
  --db-instance-identifier <instance-id> \
  --query 'DBInstances[0].VpcSecurityGroups'
```

**Verify credentials**:
```bash
# Check Secrets Manager secret
aws secretsmanager get-secret-value \
  --secret-id <druid-metadata-secret>
```

## Troubleshooting Tools

### Network Diagnostic Pod

```bash
# Deploy debug pod with network tools
kubectl run netshoot --image=nicolaka/netshoot -it --rm -- bash

# Inside pod:
# - ping <ip>
# - nc -zv <host> <port>
# - dig <domain>
# - traceroute <ip>
# - iftop (network traffic)
```

### Check Route Tables

```bash
# List all route tables in VPC
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'RouteTables[*].[RouteTableId,Tags[?Key==`Name`].Value|[0],Routes]'
```

### Verify VPC Endpoints

```bash
# List VPC endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=<vpc-id>"

# Check endpoint status (should be "available")
```

## Related Documentation

- [Druid VPC →](/druid/vpc.md)
- [WebApp VPC →](/webapp/vpc.md)
- [Common Errors →](common-errors.md)
- [EKS Pod Failures →](eks-pod-failures.md)
