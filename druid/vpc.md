# VPC (Virtual Private Cloud)

## Overview

The VPC provides network isolation and connectivity for the EKS cluster, Apache Druid, and all AWS resources. It's configured with public and private subnets across multiple Availability Zones for high availability.

## VPC Configuration

### Core Settings

**VPC Name**: `{id}-vpc`

**Example**: `fff-vpc`

**CIDR Block**: `10.0.0.0/16`

**IP Protocol**: IPv4 only

**DNS Support**: Enabled

**DNS Hostnames**: Enabled

**Tenancy**: Default

### How Configuration is Used

**Input (cdk.context.json)**:
```json
{
  "hosted:id": "fff",
  "hosted:region": "us-west-2"
}
```

**Template (vpc section in conf.mustache)**:
```yaml
vpc:
  name: {{hosted:id}}-vpc          # fff-vpc
  cidr: 10.0.0.0/16
  ipProtocol: ipv4_only
  natGateways: 2
  createInternetGateway: true
  availabilityZones:
    - {{hosted:region}}a           # us-west-2a
    - {{hosted:region}}b           # us-west-2b
    - {{hosted:region}}c           # us-west-2c
  enableDnsSupport: true
  enableDnsHostnames: true
  defaultInstanceTenancy: default
```

**Creates CloudFormation**:
```yaml
VPC:
  Type: AWS::EC2::VPC
  Properties:
    CidrBlock: 10.0.0.0/16
    EnableDnsSupport: true
    EnableDnsHostnames: true
    Tags:
      - Key: Name
        Value: fff-vpc
```

## Availability Zones

**Configured AZs**: 3

**Regions**:
- `{region}a` - Availability Zone A
- `{region}b` - Availability Zone B
- `{region}c` - Availability Zone C

**Example for us-west-2**:
- `us-west-2a`
- `us-west-2b`
- `us-west-2c`

**Why 3 AZs?**
- **High Availability**: Survives single AZ failure
- **MSK Requirement**: 3 brokers across 3 AZs
- **EKS Best Practice**: Distributes control plane and nodes

## Subnets

### Public Subnets

**Count**: 3 (one per AZ)

**CIDR Mask**: /24 (256 IP addresses each)

**CIDR Ranges**:
- `10.0.0.0/24` (us-west-2a)
- `10.0.1.0/24` (us-west-2b)
- `10.0.2.0/24` (us-west-2c)

**Configuration**:
```yaml
- name: public
  cidrMask: 24
  reserved: false
  subnetType: public
  mapPublicIpOnLaunch: false
```

**Resources deployed**:
- Internet Gateway (attached)
- NAT Gateways (2)
- Load Balancers (ALB/NLB)
- Bastion hosts (optional)

**Route Table**:
```yaml
PublicRouteTable:
  Routes:
    - DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway
```

**Tags**:
```yaml
tags:
  "{domain}:resource-type": subnet
  "{domain}:category": network
  "{domain}:type": public
  "{domain}:cidrMask": 24
  "{domain}:component": {id}-vpc
  "{domain}:part-of": "{organization}.{name}.{alias}"
  "karpenter.sh/discovery": {id}-vpc
```

### Private Subnets with Egress

**Count**: 3 (one per AZ)

**CIDR Mask**: /24 (256 IP addresses each)

**CIDR Ranges**:
- `10.0.128.0/24` (us-west-2a)
- `10.0.129.0/24` (us-west-2b)
- `10.0.130.0/24` (us-west-2c)

**Configuration**:
```yaml
- name: private
  cidrMask: 24
  reserved: false
  subnetType: private_with_egress
```

**Resources deployed**:
- EKS worker nodes
- Druid pods
- RDS database instances
- MSK broker nodes
- All containerized workloads

**Route Table**:
```yaml
PrivateRouteTable:
  Routes:
    - DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NATGateway
```

**Tags**:
```yaml
tags:
  "{domain}:resource-type": subnet
  "{domain}:category": network
  "{domain}:type": private_with_egress
  "{domain}:cidrMask": 24
  "{domain}:component": {id}-vpc
  "{domain}:part-of": "{organization}.{name}.{alias}"
  "karpenter.sh/discovery": {id}-vpc
```

**Special Tag**: `karpenter.sh/discovery`
- Enables Karpenter to discover these subnets
- Karpenter provisions nodes in these subnets automatically

## NAT Gateways

**Count**: 2

**Purpose**: Provides internet access for private subnets

**Placement**:
- NAT Gateway 1: Public subnet in AZ-A
- NAT Gateway 2: Public subnet in AZ-B

**Why 2 NAT Gateways?**
- **High Availability**: If one AZ fails, other continues
- **Reduced Cross-AZ Charges**: Each private subnet routes through NAT in same AZ
- **Cost Balance**: 2 provides HA without excessive cost (vs 3)

**Configuration**:
```yaml
natGateways: 2
createInternetGateway: true
```

**Creates CloudFormation**:
```yaml
NATGateway1:
  Type: AWS::EC2::NatGateway
  Properties:
    AllocationId: !GetAtt NATGateway1EIP.AllocationId
    SubnetId: !Ref PublicSubnet1

NATGateway1EIP:
  Type: AWS::EC2::EIP
  Properties:
    Domain: vpc
```

## Internet Gateway

**Purpose**: Provides internet connectivity for public subnets

**Attached to**: VPC

**Configuration**:
```yaml
createInternetGateway: true
```

**Creates CloudFormation**:
```yaml
InternetGateway:
  Type: AWS::EC2::InternetGateway
  Properties:
    Tags:
      - Key: Name
        Value: {id}-igw

VPCGatewayAttachment:
  Type: AWS::EC2::VPCGatewayAttachment
  Properties:
    VpcId: !Ref VPC
    InternetGatewayId: !Ref InternetGateway
```

## Security Groups

While security groups are defined elsewhere, the VPC provides the network boundary for:

### EKS Cluster Security Group
- Controls access to EKS control plane
- Allows communication from worker nodes
- Allows kubectl access (if public endpoint enabled)

### EKS Node Security Group
- Allows inter-node communication
- Allows pods to communicate
- Allows control plane to communicate with nodes

### MSK Cluster Security Group
- Allows Kafka broker communication (port 9092, 9094)
- Allows ZooKeeper communication (port 2181, if used)
- Restricts access to EKS worker nodes only

### RDS Security Group
- Allows PostgreSQL access (port 5432)
- Restricts access to Druid pods only

## Post-Deployment Customizations (Optional)

The VPC is deployed using CDK constructs from `cdk-common`. To add optional features like VPC endpoints or flow logs, you can extend the infrastructure using AWS CDK L2 constructs.

### Adding VPC Endpoints

VPC endpoints reduce NAT Gateway costs and improve security by providing direct access to AWS services.

**Approach**: Extend `NetworkNestedStack` in your infrastructure repository (e.g., `aws-druid-infra` or `aws-webapp-infra`)

**Example - S3 Gateway Endpoint**:

```java
import software.amazon.awscdk.services.ec2.GatewayVpcEndpoint;
import software.amazon.awscdk.services.ec2.GatewayVpcEndpointAwsService;

// In your NetworkNestedStack or DeploymentStack
GatewayVpcEndpoint s3Endpoint = GatewayVpcEndpoint.Builder.create(this, "S3Endpoint")
  .vpc(vpcConstruct.getVpc())
  .service(GatewayVpcEndpointAwsService.S3)
  .build();
```

**CDK Reference**: [`GatewayVpcEndpoint`](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_ec2.GatewayVpcEndpoint.html)

**Benefits**:
- Direct access to S3 without NAT Gateway
- Reduced data transfer costs
- Lower latency for Druid deep storage operations

**Example - ECR Interface Endpoints**:

```java
import software.amazon.awscdk.services.ec2.InterfaceVpcEndpoint;
import software.amazon.awscdk.services.ec2.InterfaceVpcEndpointAwsService;

// ECR API endpoint
InterfaceVpcEndpoint ecrApiEndpoint = InterfaceVpcEndpoint.Builder.create(this, "ECRApiEndpoint")
  .vpc(vpcConstruct.getVpc())
  .service(InterfaceVpcEndpointAwsService.ECR)
  .privateDnsEnabled(true)
  .subnets(SubnetSelection.builder()
    .subnetType(SubnetType.PRIVATE_WITH_EGRESS)
    .build())
  .build();

// ECR Docker endpoint
InterfaceVpcEndpoint ecrDkrEndpoint = InterfaceVpcEndpoint.Builder.create(this, "ECRDkrEndpoint")
  .vpc(vpcConstruct.getVpc())
  .service(InterfaceVpcEndpointAwsService.ECR_DOCKER)
  .privateDnsEnabled(true)
  .subnets(SubnetSelection.builder()
    .subnetType(SubnetType.PRIVATE_WITH_EGRESS)
    .build())
  .build();
```

**CDK Reference**: [`InterfaceVpcEndpoint`](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_ec2.InterfaceVpcEndpoint.html)

**Benefits**:
- Pull Docker images without internet access
- Enhanced security for private EKS clusters
- Faster container image pulls

**Other useful VPC endpoints**:
- **DynamoDB**: `GatewayVpcEndpointAwsService.DYNAMODB`
- **Secrets Manager**: `InterfaceVpcEndpointAwsService.SECRETS_MANAGER`
- **CloudWatch Logs**: `InterfaceVpcEndpointAwsService.CLOUDWATCH_LOGS`
- **STS**: `InterfaceVpcEndpointAwsService.STS`

### Adding VPC Flow Logs

Monitor network traffic for security analysis and troubleshooting.

**Approach**: Add to `NetworkNestedStack` using CDK `FlowLog` construct

**Example**:

```java
import software.amazon.awscdk.services.ec2.FlowLog;
import software.amazon.awscdk.services.ec2.FlowLogDestination;
import software.amazon.awscdk.services.ec2.FlowLogTrafficType;
import software.amazon.awscdk.services.logs.LogGroup;
import software.amazon.awscdk.services.logs.RetentionDays;

// Create log group for flow logs
LogGroup flowLogGroup = LogGroup.Builder.create(this, "VpcFlowLogGroup")
  .logGroupName("/aws/vpc/flowlogs/" + conf.name())
  .retention(RetentionDays.ONE_WEEK)
  .build();

// Create flow log
FlowLog.Builder.create(this, "VpcFlowLog")
  .resourceType(FlowLogResourceType.fromVpc(vpcConstruct.getVpc()))
  .destination(FlowLogDestination.toCloudWatchLogs(flowLogGroup))
  .trafficType(FlowLogTrafficType.ALL)
  .build();
```

**CDK Reference**: [`FlowLog`](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_ec2.FlowLog.html)

**Captures**:
- Source and destination IPs
- Ports and protocols
- Accept/reject decisions
- Bytes and packets transferred

**Alternative destinations**:
- **S3**: `FlowLogDestination.toS3(bucket)`
- **Kinesis Data Firehose**: `FlowLogDestination.toKinesisDataFirehoseDestination(deliveryStream)`

### Implementation Steps

1. **Locate your infrastructure stack**:
   - For Druid: `aws-druid-infra/src/main/java/fasti/sh/druid/stack/DeploymentStack.java`
   - For WebApp: `aws-webapp-infra/infra/src/main/java/fasti/sh/webapp/stack/DeploymentStack.java`

2. **Access the VPC construct**:
   ```java
   // In DeploymentStack.java after NetworkNestedStack creation
   Vpc vpc = networkNestedStack.getVpcConstruct().getVpc();
   ```

3. **Add CDK constructs** as shown in examples above

4. **Rebuild and deploy**:
   ```bash
   mvn clean install
   cdk diff    # Preview changes
   cdk deploy  # Apply changes
   ```

## Resource Tagging

All VPC resources are tagged:

```yaml
tags:
  "{domain}:resource-type": vpc
  "{domain}:category": network
  "{domain}:type": network
  "{domain}:cidrMask": 24
  "{domain}:component": {id}-vpc
  "{domain}:part-of": "{organization}.{name}.{alias}"
```

**Example**:
```yaml
tags:
  "data.stxkxs.io:resource-type": vpc
  "data.stxkxs.io:category": network
  "data.stxkxs.io:type": network
  "data.stxkxs.io:cidrMask": 24
  "data.stxkxs.io:component": fff-vpc
  "data.stxkxs.io:part-of": data.analytics.eks
```

## Stack Outputs

After deployment, the VPC nested stack provides:

```yaml
Outputs:
  VpcId:
    Value: vpc-abc123
    Export: {stackName}-VpcId

  VpcCidr:
    Value: 10.0.0.0/16
    Export: {stackName}-VpcCidr

  PublicSubnetIds:
    Value: !Join [',', [!Ref PublicSubnet1, !Ref PublicSubnet2, !Ref PublicSubnet3]]
    Export: {stackName}-PublicSubnetIds

  PrivateSubnetIds:
    Value: !Join [',', [!Ref PrivateSubnet1, !Ref PrivateSubnet2, !Ref PrivateSubnet3]]
    Export: {stackName}-PrivateSubnetIds

  AvailabilityZones:
    Value: !Join [',', [us-west-2a, us-west-2b, us-west-2c]]
    Export: {stackName}-AvailabilityZones
```

## Network Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                      Internet Gateway                         │
└────────────────────────────┬─────────────────────────────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │                                         │
┌───────▼──────────┐  ┌─────────────────┐  ┌────▼──────────────┐
│  Public Subnet   │  │  Public Subnet  │  │  Public Subnet    │
│  us-west-2a      │  │  us-west-2b     │  │  us-west-2c       │
│  10.0.0.0/24     │  │  10.0.1.0/24    │  │  10.0.2.0/24      │
│                  │  │                 │  │                   │
│  NAT Gateway 1───┼──┼─ NAT Gateway 2  │  │  Load Balancers   │
└────────┬─────────┘  └────────┬────────┘  └───────────────────┘
         │                     │
         │                     │
┌────────▼─────────┐  ┌────────▼────────┐  ┌───────────────────┐
│  Private Subnet  │  │  Private Subnet │  │  Private Subnet   │
│  us-west-2a      │  │  us-west-2b     │  │  us-west-2c       │
│  10.0.128.0/24   │  │  10.0.129.0/24  │  │  10.0.130.0/24    │
│                  │  │                 │  │                   │
│  EKS Nodes       │  │  EKS Nodes      │  │  EKS Nodes        │
│  Druid Pods      │  │  Druid Pods     │  │  Druid Pods       │
│  RDS Database    │  │  RDS Read Rep   │  │  MSK Brokers      │
└──────────────────┘  └─────────────────┘  └───────────────────┘
```

## IP Address Planning

### Total Available IPs

**VPC CIDR**: `10.0.0.0/16` = 65,536 addresses

**Public Subnets**: 3 × 256 = 768 addresses
**Private Subnets**: 3 × 256 = 768 addresses
**Reserved**: AWS reserves 5 IPs per subnet
**Usable**: ~1,500 addresses

### IP Allocation

**Per Private Subnet** (~251 usable IPs):
- EKS Nodes: 2-10 IPs
- Pods (with VPC CNI): ~200-240 IPs
- RDS: 1-2 IPs
- MSK: 1 IP per broker
- Reserved: 5 IPs (AWS)

**VPC CNI Pod Addressing**:
- Each pod gets a VPC IP address
- ENIs attached to nodes
- Secondary IPs allocated from subnet
- Enables security groups for pods

## Troubleshooting

### Subnet IP Exhaustion

**Symptoms**:
- Pods stuck in `Pending` state
- Node scaling fails
- Error: "InsufficientFreeAddressesInSubnet"

**Solutions**:
1. Add more subnets with larger CIDR blocks
2. Enable prefix assignment mode for VPC CNI
3. Use secondary CIDR blocks

### NAT Gateway Bandwidth

**Symptoms**:
- Slow S3 uploads/downloads
- High data transfer costs
- Connection timeouts

**Solutions**:
1. Add more NAT Gateways (one per AZ)
2. Use S3 VPC Gateway Endpoint
3. Monitor CloudWatch metrics for NAT Gateway

### Cross-AZ Traffic Costs

**Symptoms**:
- High data transfer charges
- Unexpected AWS bill increases

**Solutions**:
1. Use topology-aware routing for services
2. Configure pod anti-affinity to keep related pods in same AZ
3. Use local volumes where possible

## Next Steps

- [EKS Cluster →](eks.md)
- [Apache Druid Deployment →](druid.md)
- [MSK Integration →](msk.md)
- [Grafana Observability →](grafana.md)
