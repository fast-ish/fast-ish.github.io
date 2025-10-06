# Core Concepts

## The yaml → model → construct Pattern

All Fastish infrastructure follows a consistent configuration pattern that transforms user inputs into AWS resources through four stages.

### Architecture Overview

```
User Input → Mustache Templates → Java Models → CDK Constructs → AWS Resources
(JSON)        (YAML)                (Records)      (Classes)         (CloudFormation)
```

This pattern ensures:
- **Type safety**: Configuration is validated at compile time
- **Consistency**: All infrastructure uses the same approach
- **Extensibility**: Easy to add new resources following existing patterns
- **Documentation**: Configuration schema is self-documenting through code

## Stage 1: User Input (cdk.context.json)

Users configure deployments by editing `cdk.context.json` in their infrastructure repository.

**Location**:
- Druid: `aws-druid-infra/cdk.context.json`
- WebApp: `aws-webapp-infra/infra/cdk.context.json`

**Example**:
```json
{
  "deployment:id": "fff",
  "deployment:organization": "data",
  "deployment:account": "000000000000",
  "deployment:region": "us-west-2",
  "deployment:name": "analytics",
  "deployment:alias": "eks",
  "deployment:environment": "prototype",
  "deployment:version": "v1",
  "deployment:domain": "data.stxkxs.io"
}
```

**Key-Value Pairs**:
- `hosted:id` - 3-letter deployment identifier (e.g., `fff`)
- `hosted:organization` - Organization name for tagging and billing
- `hosted:account` - AWS account ID (12 digits)
- `hosted:region` - AWS region (e.g., `us-west-2`)
- `hosted:name` - Deployment name (e.g., `analytics`)
- `hosted:alias` - Deployment type (e.g., `eks`, `webapp`)
- `hosted:environment` - Environment tier (maps to template directory)
- `hosted:version` - API version (maps to template subdirectory)
- `hosted:domain` - Domain name for tagging and DNS

See [Configuration Reference →](configuration.md) for all available parameters.

## Stage 2: Mustache Templates (YAML)

Templates use [Mustache](https://mustache.github.io/) syntax to resolve context variables into structured YAML configuration.

**Template Location Pattern**:
```
src/main/resources/{environment}/{version}/
```

**Example**: For `environment: "prototype"` and `version: "v1"`:
```
aws-druid-infra/src/main/resources/prototype/v1/
├── conf.mustache              # Main configuration
├── eks/
│   ├── addons.mustache        # EKS addons config
│   ├── node-groups.mustache   # Node group definitions
│   └── observability.mustache # Monitoring setup
└── druid/
    ├── values.mustache        # Druid Helm values
    └── setup/
        ├── storage.mustache   # S3 and RDS config
        └── ingestion.mustache # MSK config
```

**Template Example** (`conf.mustache`):
```yaml
deployment:
  common:
    id: {{deployment:id}}                    # Resolves to: fff
    organization: {{deployment:organization}} # Resolves to: data
    domain: {{deployment:domain}}            # Resolves to: data.stxkxs.io

  vpc:
    name: {{deployment:id}}-vpc              # Resolves to: fff-vpc
    cidr: 10.0.0.0/16
    natGateways: 2

  eks:
    name: {{deployment:id}}-eks              # Resolves to: fff-eks
    version: "1.33"
```

**Variable Resolution**:
- `{{deployment:id}}` → `fff`
- `{{deployment:organization}}` → `data`
- `{{deployment:id}}-vpc` → `fff-vpc`

**Conditional Rendering**:
```yaml
{{#hosted:eks:administrators}}
administrators:
  - username: {{username}}
    role: {{role}}
    email: {{email}}
{{/hosted:eks:administrators}}
```

## Stage 3: Java Models (Type-Safe Configuration)

Mustache templates are parsed into strongly-typed Java records that validate configuration structure.

**Model Location**: `cdk-common/src/main/java/fasti/sh/model/aws/`

**Example Model** (`NetworkConf.java`):
```java
package fasti.sh.model.aws.vpc;

public record NetworkConf(
  String name,                      // Required: VPC name
  String cidr,                      // Required: CIDR block
  IpProtocol ipProtocol,            // Required: IPv4 or IPv6
  int natGateways,                  // Required: NAT gateway count
  List<Subnet> subnets,             // Required: Subnet definitions
  List<String> availabilityZones,   // Required: AZ list
  boolean enableDnsHostnames,       // Required: DNS configuration
  boolean enableDnsSupport,         // Required: DNS configuration
  Map<String, String> tags          // Required: Resource tags
) {}
```

**Benefits**:
- **Compile-time validation**: Missing fields cause build errors
- **IDE support**: Autocomplete and type checking
- **Documentation**: Field types document expected values
- **Immutability**: Records are immutable by default

**Model Hierarchy**:
```
DeploymentConf
├── Common (id, organization, tags)
├── NetworkConf (VPC configuration)
├── EksConf (Kubernetes cluster)
└── DruidConf (Apache Druid setup)
```

## Stage 4: CDK Constructs (Infrastructure Code)

Java models are passed to CDK constructs that create AWS CloudFormation resources.

**Construct Location**: `cdk-common/src/main/java/fasti/sh/execute/aws/`

**Example Construct** (`VpcConstruct.java`):
```java
public class VpcConstruct extends Construct {
  private final Vpc vpc;

  public VpcConstruct(Construct scope, Common common, NetworkConf conf) {
    super(scope, id("vpc", conf.name()));

    this.vpc = Vpc.Builder.create(this, conf.name())
      .vpcName(conf.name())                  // "fff-vpc"
      .ipAddresses(IpAddresses.cidr(conf.cidr()))  // "10.0.0.0/16"
      .availabilityZones(conf.availabilityZones()) // ["us-west-2a", "us-west-2b", "us-west-2c"]
      .natGateways(conf.natGateways())             // 2
      .enableDnsSupport(conf.enableDnsSupport())   // true
      .enableDnsHostnames(conf.enableDnsHostnames()) // true
      .subnetConfiguration(
        conf.subnets().stream()
          .map(subnet -> SubnetConfiguration.builder()
            .name(subnet.name())
            .cidrMask(subnet.cidrMask())
            .subnetType(subnet.subnetType())
            .build())
          .toList()
      )
      .build();
  }

  public Vpc getVpc() {
    return this.vpc;
  }
}
```

**CDK Construct Reference**: [AWS CDK API Documentation](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-construct-library.html)

## Stage 5: AWS Resources (CloudFormation)

CDK synthesizes Java constructs into CloudFormation templates that AWS deploys as infrastructure.

**CloudFormation Output** (from VpcConstruct):
```yaml
Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: fff-vpc
        - Key: data.stxkxs.io:organization
          Value: data

  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.0.0/24
      AvailabilityZone: us-west-2a

  NATGateway1:
    Type: AWS::EC2::NatGateway
    Properties:
      AllocationId: !GetAtt NATGateway1EIP.AllocationId
      SubnetId: !Ref PublicSubnet1
```

## Complete Example: VPC Deployment

### 1. User Input
```json
{
  "deployment:id": "app",
  "deployment:region": "us-east-1"
}
```

### 2. Mustache Template Resolves
```yaml
vpc:
  name: {{deployment:id}}-vpc    # "app-vpc"
  cidr: 10.0.0.0/16
  availabilityZones:
    - {{deployment:region}}a     # "us-east-1a"
    - {{deployment:region}}b     # "us-east-1b"
```

### 3. Java Model Validates
```java
NetworkConf conf = new NetworkConf(
  "app-vpc",
  "10.0.0.0/16",
  IpProtocol.IPV4_ONLY,
  2,
  List.of(/* subnets */),
  List.of("us-east-1a", "us-east-1b"),
  true,
  true,
  Map.of("Name", "app-vpc")
);
```

### 4. CDK Construct Creates
```java
Vpc vpc = Vpc.Builder.create(this, "app-vpc")
  .vpcName("app-vpc")
  .ipAddresses(IpAddresses.cidr("10.0.0.0/16"))
  .availabilityZones(List.of("us-east-1a", "us-east-1b"))
  .natGateways(2)
  .build();
```

### 5. AWS Deploys CloudFormation
```
CloudFormation Stack: app-vpc
├── VPC (vpc-abc123)
├── Internet Gateway (igw-xyz789)
├── 2 Public Subnets
├── 2 Private Subnets
└── 2 NAT Gateways
```

## Available Constructs

Fastish provides CDK constructs for all major AWS services:

**Compute & Orchestration**:
- [`EksNestedStack`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/eks/EksNestedStack.java) - Amazon EKS clusters
- [`NodeGroupsConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/eks/NodeGroupsConstruct.java) - EKS managed node groups
- [`KarpenterConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/eks/addon/KarpenterConstruct.java) - Karpenter autoscaler
- [`LambdaConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/lambda/LambdaConstruct.java) - AWS Lambda functions

**Networking**:
- [`VpcConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/vpc/VpcConstruct.java) - Amazon VPC
- [`NetworkNestedStack`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/vpc/NetworkNestedStack.java) - Complete network stack
- [`SecurityGroupConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/vpc/SecurityGroupConstruct.java) - Security groups

**Storage & Databases**:
- [`BucketConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/s3/BucketConstruct.java) - Amazon S3 buckets
- [`DynamoDbConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/dynamodb/DynamoDbConstruct.java) - DynamoDB tables
- [`RdsConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/rds/RdsConstruct.java) - RDS databases

**Messaging & Streaming**:
- [`MskConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/msk/MskConstruct.java) - Amazon MSK (Kafka)
- [`SqsConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/sqs/SqsConstruct.java) - Amazon SQS queues

**Application Services**:
- [`RestApiConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/apigw/RestApiConstruct.java) - API Gateway REST APIs
- [`UserPoolConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/cognito/UserPoolConstruct.java) - Cognito User Pools
- [`IdentityConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/ses/IdentityConstruct.java) - Amazon SES email

**Security & Access**:
- [`RoleConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/iam/RoleConstruct.java) - IAM roles
- [`SecretConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/secretsmanager/SecretConstruct.java) - Secrets Manager secrets
- [`KmsConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/kms/KmsConstruct.java) - KMS encryption keys

See the [cdk-common repository](https://github.com/fast-ish/cdk-common/tree/main/src/main/java/fasti/sh/execute/aws) for the complete list.

## Benefits of This Pattern

### 1. Type Safety
Configuration errors are caught at compile time, not deployment time:
```java
// Compiler error: missing required field
NetworkConf conf = new NetworkConf(
  "vpc-name",
  "10.0.0.0/16"
  // ERROR: Missing remaining required fields
);
```

### 2. IDE Support
Full autocomplete and inline documentation:
```java
// IDE shows all available methods and parameter types
vpc.Builder.create(this, "vpc")
  .vpcName(...)      // String expected
  .natGateways(...)  // Integer expected
```

### 3. Reusability
Constructs are modular and composable:
```java
// Use VpcConstruct in multiple stacks
VpcConstruct vpc = new VpcConstruct(this, common, vpcConfig);

// Pass to other constructs
EksConstruct eks = new EksConstruct(this, common, eksConfig, vpc.getVpc());
```

### 4. Testability
Configuration and infrastructure are both testable:
```java
@Test
void testVpcConfiguration() {
  NetworkConf conf = loadConfig("test-config.yaml");
  assertEquals("test-vpc", conf.name());
  assertEquals(2, conf.natGateways());
}
```

### 5. Consistency
All infrastructure follows the same pattern, making it predictable and maintainable.

## Next Steps

- [Configuration Reference →](configuration.md) - All available configuration options
- [Quick Start →](quickstart.md) - Deploy your first stack
- [Druid Architecture →](/druid/overview.md) - Example using this pattern
- [WebApp Architecture →](/webapp/overview.md) - Example using this pattern
