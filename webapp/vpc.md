# WebApp VPC

## Overview

The WebApp VPC provides network isolation and security for the multi-tenant SaaS application infrastructure. It uses a standard 3-tier architecture with public and private subnets across three Availability Zones.

**Network**: CIDR `192.168.0.0/16`

## Configuration

### How Configuration is Used

Follows the [yaml → model → construct pattern](/getting-started/concepts.md#the-yaml--model--construct-pattern).

**Input (cdk.context.json)**:
```json
{
  "hosted:id": "app",
  "hosted:region": "us-west-2",
  "hosted:domain": "stxkxs.io"
}
```

**Template (production/v1/conf.mustache)**:
```yaml
vpc:
  name: {{hosted:id}}-webapp-vpc        # app-webapp-vpc
  cidr: 192.168.0.0/16
  ipProtocol: ipv4_only
  natGateways: 2
  createInternetGateway: true
  availabilityZones:
    - {{hosted:region}}a                # us-west-2a
    - {{hosted:region}}b                # us-west-2b
    - {{hosted:region}}c                # us-west-2c
  enableDnsSupport: true
  enableDnsHostnames: true
  defaultInstanceTenancy: default
```

**CDK Construct**: [`VpcConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/vpc/VpcConstruct.java)

## Network Architecture

```
VPC (192.168.0.0/16)
│
├── Availability Zone A (us-west-2a)
│   ├── Public Subnet    (192.168.0.0/24)
│   └── Private Subnet   (192.168.3.0/24)
│
├── Availability Zone B (us-west-2b)
│   ├── Public Subnet    (192.168.1.0/24)
│   └── Private Subnet   (192.168.4.0/24)
│
└── Availability Zone C (us-west-2c)
    ├── Public Subnet    (192.168.2.0/24)
    └── Private Subnet   (192.168.5.0/24)
```

## Subnets

### Public Subnets

**CIDR Mask**: `/24` (256 addresses per subnet)

**Subnet Type**: `public`

**Configuration**:
```yaml
subnets:
  - name: public
    cidrMask: 24
    reserved: false
    subnetType: public
    mapPublicIpOnLaunch: false
```

**What lives here**:
- NAT Gateways (for private subnet internet access)
- Internet Gateway attachment point
- Potential future ALB/NLB targets

**Routing**:
- `0.0.0.0/0` → Internet Gateway (direct internet access)
- `192.168.0.0/16` → Local (VPC internal)

### Private Subnets

**CIDR Mask**: `/24` (256 addresses per subnet)

**Subnet Type**: `private_with_egress`

**Configuration**:
```yaml
subnets:
  - name: private
    cidrMask: 24
    reserved: false
    subnetType: private_with_egress
```

**What lives here**:
- Lambda functions (API Gateway integrations)
- DynamoDB VPC endpoints (if configured)
- Future EC2 instances or ECS tasks

**Routing**:
- `0.0.0.0/0` → NAT Gateway (outbound internet via NAT in public subnet)
- `192.168.0.0/16` → Local (VPC internal)

## NAT Gateways

**Count**: 2 (for high availability)

**Purpose**: Provide outbound internet access for resources in private subnets

**Configuration**:
```yaml
natGateways: 2
```

**Placement**:
- NAT Gateway 1: Public subnet in AZ-A
- NAT Gateway 2: Public subnet in AZ-B

**Benefit**: If one AZ fails, the other NAT Gateway continues serving traffic

**Cost**: ~$0.045/hour per NAT Gateway + data processing charges (~$0.045/GB)

## Internet Gateway

**Purpose**: Provides inbound and outbound internet connectivity for public subnets

**Configuration**:
```yaml
createInternetGateway: true
```

**Attached to**: VPC

## DNS Configuration

### DNS Support

**Enabled**: `true`

**Purpose**: Enables DNS resolution within the VPC

**Configuration**:
```yaml
enableDnsSupport: true
```

**What this provides**:
- Route 53 Resolver available at `192.168.0.2`
- VPC resources can resolve public DNS names
- Enables private hosted zones

### DNS Hostnames

**Enabled**: `true`

**Purpose**: Assigns DNS names to EC2 instances

**Configuration**:
```yaml
enableDnsHostnames: true
```

**Format**: `ip-192-168-0-10.us-west-2.compute.internal`

## Resource Tagging

All VPC resources are tagged for organization and cost allocation:

```yaml
tags:
  "{{hosted:domain}}:resource-type": vpc
  "{{hosted:domain}}:category": network
  "{{hosted:domain}}:type": network
  "{{hosted:domain}}:cidrMask": 24
  "{{hosted:domain}}:component": {{hosted:id}}-webapp-vpc
  "{{hosted:domain}}:part-of": "{{synthesizer:name}}:{{hosted:organization}}:{{hosted:name}}:{{hosted:alias}}:webapp"
```

**Example** (for `hosted:id: "app"`, `hosted:domain: "stxkxs.io"`):
```yaml
tags:
  "stxkxs.io:resource-type": vpc
  "stxkxs.io:category": network
  "stxkxs.io:type": network
  "stxkxs.io:cidrMask": 24
  "stxkxs.io:component": app-webapp-vpc
  "stxkxs.io:part-of": "prod:acme:webapp:app:webapp"
```

## Post-Deployment Customizations

### Adding VPC Endpoints

VPC endpoints reduce NAT Gateway costs and improve security. See [Druid VPC Customizations](/druid/vpc.md#post-deployment-customizations-optional) for examples using AWS CDK constructs.

**Recommended endpoints for WebApp**:

**DynamoDB Gateway Endpoint**:
```java
GatewayVpcEndpoint.Builder.create(this, "DynamoDBEndpoint")
  .vpc(vpcConstruct.getVpc())
  .service(GatewayVpcEndpointAwsService.DYNAMODB)
  .build();
```

**Secrets Manager Interface Endpoint**:
```java
InterfaceVpcEndpoint.Builder.create(this, "SecretsManagerEndpoint")
  .vpc(vpcConstruct.getVpc())
  .service(InterfaceVpcEndpointAwsService.SECRETS_MANAGER)
  .privateDnsEnabled(true)
  .build();
```

**CloudWatch Logs Interface Endpoint**:
```java
InterfaceVpcEndpoint.Builder.create(this, "CloudWatchLogsEndpoint")
  .vpc(vpcConstruct.getVpc())
  .service(InterfaceVpcEndpointAwsService.CLOUDWATCH_LOGS)
  .privateDnsEnabled(true)
  .build();
```

CDK Reference: [`GatewayVpcEndpoint`](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_ec2.GatewayVpcEndpoint.html), [`InterfaceVpcEndpoint`](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_ec2.InterfaceVpcEndpoint.html)

## Cost Estimate

**VPC**: Free

**Subnets**: Free

**Internet Gateway**: Free

**NAT Gateways**: ~$65-70/month
- 2 NAT Gateways × $0.045/hour × 730 hours = ~$66/month
- Plus data processing: ~$0.045/GB processed

**Total**: ~$65-100/month (depending on data transfer)

**Optimization**: Consider using a single NAT Gateway for non-production environments to reduce costs by 50%.

## Accessing VPC Resources

### From AWS Console

1. Open **VPC Dashboard** in AWS Console
2. Filter by tag: `stxkxs.io:component = app-webapp-vpc`
3. View:
   - VPC details
   - Subnets across AZs
   - Route tables
   - NAT Gateways
   - Internet Gateway

### Using AWS CLI

**List VPCs**:
```bash
aws ec2 describe-vpcs \
  --filters "Name=tag:stxkxs.io:component,Values=app-webapp-vpc"
```

**List Subnets**:
```bash
aws ec2 describe-subnets \
  --filters "Name=tag:stxkxs.io:component,Values=app-webapp-vpc"
```

**Get NAT Gateways**:
```bash
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=vpc-abc123"
```

## Security Considerations

### Network Isolation

- **Private subnets** have no direct internet access (only via NAT)
- Lambda functions cannot receive inbound traffic from internet
- All inbound traffic must go through API Gateway

### Security Groups

Default security groups are restrictive. See individual component docs for security group configurations:
- [API Gateway Security](api-gateway.md#security)
- [DynamoDB Access](dynamodb.md#security)
- [Cognito Security](authentication.md#security)

## Troubleshooting

### Lambda functions cannot access internet

**Symptoms**:
- Lambda timeouts when calling external APIs
- Cannot download dependencies

**Check**:
```bash
# Verify Lambda is in private subnet
aws lambda get-function-configuration --function-name app-webapp-api-user

# Verify NAT Gateways are running
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available"
```

**Fix**: Ensure Lambda functions are attached to private subnets and NAT Gateways are healthy.

### DynamoDB connection timeouts

**Cause**: Lambda in VPC cannot reach DynamoDB service endpoint

**Fix**: Add DynamoDB VPC Gateway Endpoint (see customizations above)

## Related Documentation

- [WebApp Overview →](overview.md)
- [API Gateway →](api-gateway.md) - Uses this VPC
- [Authentication →](authentication.md) - Cognito integrated with VPC
- [Core Concepts →](/getting-started/concepts.md) - Understanding the configuration pattern
