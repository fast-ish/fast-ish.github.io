# Workflow Overview

## Introduction

The Fastish deployment workflow orchestrates infrastructure deployment through a series of hierarchical resources that map user inputs to AWS CloudFormation stacks. Understanding this workflow is essential for successfully deploying and managing your infrastructure.

## Workflow Hierarchy

The workflow follows a logical hierarchy:

```
Synthesizer (AWS Environment)
    ↓
Organizations (Logical Grouping)
    ↓
Teams (Development Teams)
    ↓
Contributors (Individual Developers)
    ↓
Releases (Infrastructure Deployments)
```

Each level serves a specific purpose and contributes configuration to the final CloudFormation deployment.

## High-Level Flow

### 1. User Provides Configuration

Users input configuration at various levels:

**Synthesizer Level:**
- AWS Account ID
- AWS Region
- External ID (for cross-account access)
- CDK Bootstrap outputs

**Organization Level:**
- Organization name
- Tags and metadata
- Resource naming prefixes

**Team Level:**
- Team name
- Access permissions
- Resource quotas

**Release Level:**
- Release type (webapp, druid)
- Environment (prototype, production)
- Version (v1, v2)
- Domain configuration
- SES email settings

### 2. Configuration Aggregation

These inputs are aggregated into `cdk.context.json`:

```json
{
  "deployment:account": "123456789012",
  "deployment:region": "us-west-2",
  "deployment:organization": "acme-corp",
  "deployment:name": "production",
  "deployment:environment": "production",
  "deployment:version": "v1",
  "deployment:domain": "acme.com",
  "deployment:ses:hosted:zone": "Z1234567890ABC",
  "deployment:ses:email": "noreply@acme.com"
}
```

### 3. Deployment Pipeline Execution

The deployment happens through CodePipeline in `spaz-infra`:

```
User triggers release
    ↓
EventBridge Rule fires
    ↓
CodePipeline starts
    ↓
[Code] → [Build] → [Prepare] → [Synth] → [Deploy] → [Publish]
    ↓
CloudFormation creates resources
    ↓
Stack outputs published
```

### 4. Resource Creation

CloudFormation creates infrastructure based on configuration:

- VPC with subnets across 3 AZs
- Cognito User Pool with custom config
- DynamoDB tables
- SES domain identity with DKIM
- API Gateway with Lambda functions
- All supporting resources (IAM roles, security groups, etc.)

## How Inputs Flow to CloudFormation

### Synthesizer → AWS Environment

**What it provides:**
```typescript
interface Synthesizer {
  account: string;           // AWS Account ID
  region: string;            // AWS Region
  externalId: string;        // Cross-account access key
  cdk: {
    assetsBucket: string;    // S3 bucket for CDK assets
    imagesRepo: string;      // ECR repository
    kmsKeyId: string;        // KMS key for encryption
    roles: {
      handshake: string;     // Validation role ARN
      deploy: string;        // Deployment role ARN
      exec: string;          // CloudFormation execution role ARN
    }
  }
}
```

**Used in:**
- CDK app environment configuration
- Cross-account role assumption
- Asset upload locations
- Resource encryption

**Maps to `cdk.context.json`:**
```json
{
  "deployment:account": "<synthesizer.account>",
  "deployment:region": "<synthesizer.region>"
}
```

### Organization → Resource Naming & Tagging

**What it provides:**
```typescript
interface Organization {
  id: string;                // Unique organization ID
  name: string;              // Organization name
  tags: Tag[];               // Resource tags
}
```

**Used in:**
- CloudFormation stack naming
- Resource naming conventions
- Cost allocation tags
- Access control policies

**Maps to `cdk.context.json`:**
```json
{
  "deployment:organization": "<organization.name>",
  "deployment:id": "<organization.id>",
  "deployment:tags": [
    {"key": "Organization", "value": "<organization.name>"},
    {"key": "ManagedBy", "value": "Fastish"}
  ]
}
```

**Example resource naming:**
```java
// Stack name format
String stackName = String.format("%s-%s-%s",
    organization,  // acme-corp
    name,          // production
    alias          // webapp
);
// Result: acme-corp-production-webapp

// User Pool name format
String userPoolName = String.format("%s-%s-userpool",
    organization,  // acme-corp
    name           // production
);
// Result: acme-corp-production-userpool
```

### Team → Access & Permissions

**What it provides:**
```typescript
interface Team {
  id: string;                // Team ID
  name: string;              // Team name
  organization: string;      // Parent organization
  permissions: string[];     // IAM policy statements
}
```

**Used in:**
- IAM role creation for team members
- Resource access policies
- CloudWatch Logs permissions
- S3 bucket policies

**Not directly in `cdk.context.json`** but affects:
- IAM policies attached to roles
- Resource-based policies
- CloudFormation stack policies

### Contributor → Individual Access

**What it provides:**
```typescript
interface Contributor {
  id: string;                // Contributor ID
  name: string;              // Contributor name
  email: string;             // Email address
  team: string;              // Parent team
  role: string;              // Role type (admin, developer, viewer)
}
```

**Used in:**
- Cognito user creation (if applicable)
- IAM user/role mapping
- Access logging and audit trails

### Release → Infrastructure Configuration

**What it provides:**
```typescript
interface Release {
  type: 'webapp' | 'druid';  // Infrastructure type
  environment: string;        // prototype, production
  version: string;            // v1, v2, etc.
  domain: string;             // Primary domain
  ses: {
    hostedZoneId: string;    // Route 53 zone
    email: string;            // Verification email
  };
  variables: {
    subscriber_id: string;    // Subscriber identifier
    release_id: string;       // Release identifier
  }
}
```

**Maps to `cdk.context.json`:**
```json
{
  "deployment:environment": "<release.environment>",
  "deployment:version": "<release.version>",
  "deployment:domain": "<release.domain>",
  "deployment:ses:hosted:zone": "<release.ses.hostedZoneId>",
  "deployment:ses:email": "<release.ses.email>"
}
```

**Example configuration resolution:**

```
Release inputs:
  - type: webapp
  - environment: production
  - version: v1
  - domain: acme.com

Results in:
  1. Template path: aws-webapp-infra/infra/src/main/resources/production/v1/
  2. Configuration loaded: production/v1/conf.mustache
  3. Resources created: Production-grade configurations
     - DynamoDB: Provisioned capacity with auto-scaling
     - Lambda: 1024MB memory
     - Cognito: Strict password policy, MFA required
```

## Pipeline Stages Explained

The `spaz-infra` CodePipeline orchestrates deployment with these stages:

### Stage 1: Code

**Purpose:** Fetch source code repositories

**Actions:**
1. **Fetch cdk-common:**
   - Repository: `fast-ish/cdk-common`
   - Branch: `main`
   - Output: `COMMON_CDK` artifact

2. **Fetch aws-webapp-infra:**
   - Repository: `fast-ish/aws-webapp-infra`
   - Branch: `main`
   - Output: `WEBAPP_STACK` artifact

**Inputs used:** None (uses default GitHub connection)

**Outputs:** Source code artifacts for subsequent stages

### Stage 2: Build

**Purpose:** Compile dependencies

**Action: Maven Install**
- Project: `mvn` CodeBuild project
- Command: `mvn install --quiet`
- Repositories:
  - `$CODEBUILD_SRC_DIR_COMMON_CDK` (cdk-common)
  - `$CODEBUILD_SRC_DIR` (aws-webapp-infra)

**Environment variables:**
```bash
command="install --quiet"
repositories=["$CODEBUILD_SRC_DIR_COMMON_CDK", "$CODEBUILD_SRC_DIR"]
```

**Inputs used:**
- Source code artifacts

**Outputs:**
- `M2` artifact (Maven local repository with compiled dependencies)

### Stage 3: Prepare

**Purpose:** Generate `cdk.context.json` from user inputs

**Action: Webapp Context Preparation**
- Project: `webapp` CodeBuild project
- Stack: `webapp.v1`
- Flags: `--prepare --list`

**What happens:**
1. Reads release configuration (subscriber_id, release_id)
2. Fetches organization, team, contributor metadata
3. Generates `cdk.context.json` with all inputs:

```json
{
  "platform:id": "<organization.id>",
  "platform:organization": "<organization.name>",
  "platform:account": "351619759866",
  "platform:region": "us-west-2",
  "deployment:id": "<release.id>",
  "deployment:organization": "<organization.name>",
  "deployment:account": "<synthesizer.account>",
  "deployment:region": "<synthesizer.region>",
  "deployment:name": "<release.name>",
  "deployment:environment": "<release.environment>",
  "deployment:version": "<release.version>",
  "deployment:domain": "<release.domain>",
  "deployment:ses:hosted:zone": "<release.ses.hostedZoneId>",
  "deployment:ses:email": "<release.ses.email>"
}
```

**Environment variables:**
```bash
stack="webapp.v1"
flags="--prepare --list"
subscriber_id="#{variables.subscriber_id}"
release_id="#{variables.release_id}"
```

**Inputs used:**
- All workflow hierarchy data (synthesizer, org, team, release)

**Outputs:**
- `WEBAPP_PREPARED` artifact (contains `cdk.context.json`)

### Stage 4: Synth

**Purpose:** Synthesize CloudFormation templates

**Action: CDK Synth**
- Project: `webapp` CodeBuild project
- Stack: `webapp.v1`
- Flags: `--synth`
- Command: `cdk synth`

**What happens:**
1. CDK reads `cdk.context.json`
2. Processes Mustache templates with context values
3. Generates CloudFormation templates
4. Creates `cdk.out/` directory with:
   - `DeploymentStack.template.json` (main stack)
   - `NetworkNestedStack.template.json`
   - `SesNestedStack.template.json`
   - `AuthNestedStack.template.json`
   - `DbNestedStack.template.json`
   - `ApiNestedStack.template.json`
   - Asset manifests

**Environment variables:**
```bash
stack="webapp.v1"
flags="--synth"
subscriber_id="#{variables.subscriber_id}"
release_id="#{variables.release_id}"
```

**Inputs used:**
- `cdk.context.json` from Prepare stage
- All configuration drives template generation

**Outputs:**
- `WEBAPP_SYNTHESIZED` artifact (CloudFormation templates)

### Stage 5: Deploy

**Purpose:** Deploy CloudFormation stacks to AWS

**Action: CDK Deploy**
- Project: `webapp` CodeBuild project
- Stack: `webapp.v1`
- Flags: `--deploy`
- Command: `cdk deploy`

**What happens:**
1. CDK assumes subscriber's deployment role (using externalId)
2. Creates CloudFormation change sets
3. Executes change sets to create/update resources
4. Creates resources in this order:
   - NetworkNestedStack (VPC)
   - SesNestedStack (Email)
   - AuthNestedStack (Cognito) [waits for SES]
   - DbNestedStack (DynamoDB)
   - ApiNestedStack (API Gateway + Lambda) [waits for Auth]

**Environment variables:**
```bash
stack="webapp.v1"
flags="--deploy"
subscriber_id="#{variables.subscriber_id}"
release_id="#{variables.release_id}"
```

**Inputs used:**
- CloudFormation templates from Synth stage
- Synthesizer CDK roles for deployment
- All configuration embedded in templates

**Outputs:**
- `WEBAPP_DEPLOYED` artifact (deployment metadata)
- CloudFormation stacks in subscriber's AWS account

### Stage 6: Publish

**Purpose:** Publish stack outputs

**Action: Publish Outputs**
- Project: `publish` CodeBuild project
- Assets: `stack/cdk.out`

**What happens:**
1. Extracts CloudFormation stack outputs
2. Publishes outputs to DynamoDB
3. Stores deployment metadata
4. Sends notifications (SNS/EventBridge)

**Stack outputs captured:**
```json
{
  "webappuserpoolid": "us-west-2_ABC123XYZ",
  "webappuserpoolclientid": "1a2b3c4d5e6f7g8h9i0j",
  "webappapigwid": "abc123xyz9",
  "webappusertableid": "acme-corp-production-user-table",
  "webappsesidentityarn": "arn:aws:ses:us-west-2:123456789012:identity/acme.com"
}
```

**Environment variables:**
```bash
assets="stack/cdk.out"
subscriber_id="#{variables.subscriber_id}"
release_id="#{variables.release_id}"
```

**Inputs used:**
- Deployment outputs from Deploy stage

**Outputs:**
- `WEBAPP_PUBLISHED` artifact (published outputs)
- Outputs available via API/CloudFormation exports

## Event-Driven Triggers

### EventBridge Listener

The pipeline is triggered by EventBridge events:

**Event pattern:**
```json
{
  "source": ["fastish.release"],
  "detail-type": ["Release Launch"],
  "detail": {
    "type": ["webapp"],
    "action": ["deploy"]
  }
}
```

**Event payload example:**
```json
{
  "version": "0",
  "id": "uuid",
  "detail-type": "Release Launch",
  "source": "fastish.release",
  "time": "2024-01-15T10:30:00Z",
  "region": "us-west-2",
  "resources": [],
  "detail": {
    "subscriber_id": "sub_abc123",
    "release_id": "rel_xyz789",
    "type": "webapp",
    "action": "deploy",
    "environment": "production",
    "version": "v1"
  }
}
```

**Pipeline variables extracted:**
- `subscriber_id` from `$.detail.subscriber_id`
- `release_id` from `$.detail.release_id`

## Configuration to CloudFormation Mapping

### VPC Configuration

**Input:**
```json
{
  "deployment:region": "us-west-2"
}
```

**CloudFormation resource:**
```yaml
VPC:
  Type: AWS::EC2::VPC
  Properties:
    CidrBlock: 192.168.0.0/16
    EnableDnsSupport: true
    EnableDnsHostnames: true
    Tags:
      - Key: Name
        Value: !Sub ${Organization}-${Environment}-vpc
```

### Cognito User Pool

**Input:**
```json
{
  "deployment:organization": "acme-corp",
  "deployment:name": "production",
  "deployment:environment": "production",
  "deployment:version": "v1"
}
```

**Template resolution:**
```
Path: aws-webapp-infra/infra/src/main/resources/production/v1/auth/userpool.mustache

Template content:
---
name: {{deployment:organization}}-{{deployment:name}}-userpool
passwordPolicy:
  minimumLength: 12
  requireLowercase: true
  requireUppercase: true
  requireNumbers: true
  requireSymbols: true
mfaConfiguration: OPTIONAL
```

**CloudFormation resource:**
```yaml
UserPool:
  Type: AWS::Cognito::UserPool
  Properties:
    UserPoolName: acme-corp-production-userpool
    Policies:
      PasswordPolicy:
        MinimumLength: 12
        RequireLowercase: true
        RequireUppercase: true
        RequireNumbers: true
        RequireSymbols: true
    MfaConfiguration: OPTIONAL
```

### SES Domain Identity

**Input:**
```json
{
  "deployment:domain": "acme.com",
  "deployment:ses:hosted:zone": "Z1234567890ABC",
  "deployment:ses:email": "noreply@acme.com"
}
```

**CloudFormation resources:**
```yaml
EmailIdentity:
  Type: AWS::SES::EmailIdentity
  Properties:
    EmailIdentity: acme.com
    DkimSigningAttributes:
      NextSigningKeyLength: RSA_2048_BIT
    DkimAttributes:
      SigningEnabled: true

# Automatic DKIM DNS records created via CDK in Route 53
DkimRecord1:
  Type: AWS::Route53::RecordSet
  Properties:
    HostedZoneId: Z1234567890ABC
    Name: <dkim-token-1>._domainkey.acme.com
    Type: CNAME
    TTL: 300
    ResourceRecords:
      - <ses-dkim-value-1>.dkim.amazonses.com
```

## Next Steps

- [Synthesizer Configuration →](/workflow/synthesizer.md)
- [Organization Setup →](/workflow/organization.md)
- [Team Management →](/workflow/teams.md)
- [Creating Releases →](/workflow/release.md)
