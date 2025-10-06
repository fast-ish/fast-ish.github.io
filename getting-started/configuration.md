# Configuration Guide

## Overview

The aws-webapp-infra deployment is configured entirely through the `cdk.context.json` file. This file defines your AWS account details, region, domain configuration, and all infrastructure parameters. Understanding how these inputs flow through the system is essential for successful deployment.

## Configuration File Structure

### Location

```bash
aws-webapp-infra/infra/cdk.context.json
```

### Template

A template is provided at `cdk.context.template.json`:

```json
{
  "host:id": "xyz",
  "host:organization": "your-org-name",
  "host:account": "000000000000",
  "host:region": "us-west-2",
  "host:name": "production",
  "host:alias": "webapp",
  "host:environment": "prototype",
  "host:version": "v1",
  "host:domain": "example.com",
  "hosted:id": "abc",
  "hosted:organization": "your-org-name",
  "hosted:account": "000000000000",
  "hosted:region": "us-west-2",
  "hosted:name": "webapp",
  "hosted:alias": "api",
  "hosted:environment": "prototype",
  "hosted:version": "v1",
  "hosted:domain": "example.com",
  "hosted:ses:hosted:zone": "Z1234567890ABC",
  "hosted:ses:email": "noreply@example.com",
  "hosted:tags": [],
  "availability-zones:account=000000000000:region=us-west-2": [
    "us-west-2a",
    "us-west-2b",
    "us-west-2c",
    "us-west-2d"
  ]
}
```

## Required Parameters

### AWS Account Configuration

| Parameter | Description | Example | How It's Used |
|-----------|-------------|---------|---------------|
| `hosted:account` | Your AWS account ID (12 digits) | `123456789012` | - IAM role ARNs<br>- Resource naming<br>- Cross-stack references |
| `hosted:region` | AWS region for deployment | `us-west-2` | - Resource placement<br>- Availability zone selection<br>- Regional service endpoints |

**Where it's used:**
```java
// infra/src/main/java/fasti/sh/webapp/Launch.java
Environment env = Environment.builder()
    .account(app.getNode().getContext("hosted:account"))
    .region(app.getNode().getContext("hosted:region"))
    .build();
```

### Environment & Versioning

| Parameter | Description | Example | How It's Used |
|-----------|-------------|---------|---------------|
| `hosted:environment` | Environment name | `prototype`, `production` | Maps to resource templates path:<br>`infra/src/main/resources/{environment}/` |
| `hosted:version` | Infrastructure version | `v1`, `v2` | Maps to version-specific configs:<br>`infra/src/main/resources/{environment}/{version}/` |

**Configuration template resolution:**
```
User provides: environment=prototype, version=v1
        ↓
System loads: infra/src/main/resources/prototype/v1/conf.mustache
        ↓
Template populated with context values
        ↓
Converted to DeploymentConf Java object
```

### SES (Email Service) Configuration

| Parameter | Description | Example | How It's Used |
|-----------|-------------|---------|---------------|
| `hosted:domain` | Your registered domain | `example.com` | - SES email identity<br>- DNS record creation<br>- Email sending domain |
| `hosted:ses:hosted:zone` | Route 53 Hosted Zone ID | `Z1234567890ABC` | - Automated DKIM DNS records<br>- Email verification records<br>- SPF/DMARC setup |
| `hosted:ses:email` | Verification email address | `noreply@example.com` | - SES identity verification<br>- Cognito email sender<br>- System notifications |

**In the SES stack:**
```java
// infra/src/main/java/fasti/sh/webapp/stack/nested/SesNestedStack.java
EmailIdentity emailIdentity = EmailIdentity.Builder.create(this, "EmailIdentity")
    .identity(Identity.domain(context.get("hosted:domain")))
    .dkimSigning(true)
    .build();

// Automatic DNS record creation
HostedZone hostedZone = HostedZone.fromHostedZoneAttributes(this, "Zone",
    HostedZoneAttributes.builder()
        .hostedZoneId(context.get("hosted:ses:hosted:zone"))
        .zoneName(context.get("hosted:domain"))
        .build()
);
```

### Organizational Metadata

| Parameter | Description | Example | How It's Used |
|-----------|-------------|---------|---------------|
| `hosted:id` | Unique deployment identifier | `abc123` | Resource naming and tagging |
| `hosted:organization` | Organization name | `mycompany` | Resource tags and naming |
| `hosted:name` | Deployment name | `production-webapp` | CloudFormation stack naming |
| `hosted:alias` | Short alias for resources | `api` | DNS records, resource prefixes |

**Resource naming pattern:**
```java
String stackName = String.format("%s-%s-%s",
    context.get("hosted:organization"),  // mycompany
    context.get("hosted:name"),          // production-webapp
    context.get("hosted:alias")          // api
);
// Result: mycompany-production-webapp-api
```

## Configuration Flow

### Step 1: User Provides Input

User creates or edits `cdk.context.json` with their specific values:

```bash
cd aws-webapp-infra/infra
cp cdk.context.template.json cdk.context.json

# Edit with your values
vim cdk.context.json
```

**Critical inputs:**
- AWS Account ID (from AWS Console → Account Settings)
- AWS Region (where you want resources deployed)
- Domain name (must be registered in Route 53)
- Hosted Zone ID (from Route 53 console)
- Email address (for SES verification)

### Step 2: CDK App Reads Context

```java
// infra/src/main/java/fasti/sh/webapp/Launch.java
public static void main(String[] args) {
    App app = new App();

    // Read context values
    String account = (String) app.getNode().getContext("hosted:account");
    String region = (String) app.getNode().getContext("hosted:region");
    String environment = (String) app.getNode().getContext("hosted:environment");
    String version = (String) app.getNode().getContext("hosted:version");

    // Create environment
    Environment env = Environment.builder()
        .account(account)
        .region(region)
        .build();

    // Create deployment
    new DeploymentStack(app, "WebAppStack", env, environment, version);

    app.synth();
}
```

### Step 3: Template Processing

Context values populate Mustache templates:

**Template:** `infra/src/main/resources/prototype/v1/conf.mustache`
```yaml
common:
  account: {{hosted:account}}
  region: {{hosted:region}}
  environment: {{hosted:environment}}

ses:
  domain: {{hosted:domain}}
  hostedZoneId: {{hosted:ses:hosted:zone}}
  email: {{hosted:ses:email}}

auth:
  userPoolName: {{hosted:organization}}-{{hosted:name}}-userpool

api:
  name: {{hosted:organization}}-{{hosted:name}}-api
```

**After substitution:**
```yaml
common:
  account: 123456789012
  region: us-west-2
  environment: prototype

ses:
  domain: example.com
  hostedZoneId: Z1234567890ABC
  email: noreply@example.com

auth:
  userPoolName: mycompany-production-webapp-userpool

api:
  name: mycompany-production-webapp-api
```

### Step 4: Java Configuration Object

Template is converted to strongly-typed Java object:

```java
// infra/src/main/java/fasti/sh/webapp/stack/DeploymentConf.java
public class DeploymentConf {
    private Common common;
    private SesConf ses;
    private AuthConf auth;
    private DbConf db;
    private ApiConf api;

    // Getters/setters
}

// Used in nested stacks
DeploymentConf config = loadConfig(environment, version);
new AuthNestedStack(this, "Auth", config.getAuth());
new SesNestedStack(this, "Ses", config.getSes());
```

### Step 5: CloudFormation Resource Creation

Configuration values drive resource creation:

```java
// Cognito User Pool
UserPool userPool = UserPool.Builder.create(this, "UserPool")
    .userPoolName(config.getAuth().getUserPoolName())  // From template
    .signInAliases(SignInAliases.builder().email(true).build())
    .selfSignUpEnabled(true)
    .build();

// API Gateway
RestApi api = RestApi.Builder.create(this, "Api")
    .restApiName(config.getApi().getName())  // From template
    .deployOptions(StageOptions.builder()
        .stageName("v1")
        .build())
    .build();
```

## Common Configuration Scenarios

### Scenario 1: Development Environment

```json
{
  "hosted:account": "111111111111",
  "hosted:region": "us-west-2",
  "hosted:environment": "prototype",
  "hosted:version": "v1",
  "hosted:organization": "mycompany",
  "hosted:name": "dev",
  "hosted:alias": "webapp-dev",
  "hosted:domain": "dev.example.com",
  "hosted:ses:hosted:zone": "Z1111111111111",
  "hosted:ses:email": "dev-noreply@example.com"
}
```

**Result:**
- Stack Name: `mycompany-dev-webapp-dev`
- User Pool: `mycompany-dev-userpool`
- API Gateway: `mycompany-dev-api`
- SES Domain: `dev.example.com`

### Scenario 2: Production Environment

```json
{
  "hosted:account": "222222222222",
  "hosted:region": "us-east-1",
  "hosted:environment": "production",
  "hosted:version": "v1",
  "hosted:organization": "mycompany",
  "hosted:name": "prod",
  "hosted:alias": "webapp",
  "hosted:domain": "example.com",
  "hosted:ses:hosted:zone": "Z2222222222222",
  "hosted:ses:email": "noreply@example.com"
}
```

**Result:**
- Stack Name: `mycompany-prod-webapp`
- User Pool: `mycompany-prod-userpool`
- API Gateway: `mycompany-prod-api`
- SES Domain: `example.com`

### Scenario 3: Multi-Region Deployment

Deploy the same configuration to multiple regions by changing only the region parameter:

**US-West-2:**
```json
{
  "hosted:account": "333333333333",
  "hosted:region": "us-west-2",
  "hosted:name": "prod-west",
  ...
}
```

**EU-West-1:**
```json
{
  "hosted:account": "333333333333",
  "hosted:region": "eu-west-1",
  "hosted:name": "prod-eu",
  ...
}
```

## How Configuration Affects Stack Outputs

The configuration drives what gets exported:

```java
// Output naming uses configuration values
CfnOutput.Builder.create(this, "UserPoolId")
    .exportName(String.format("%s-userpoolid",
        config.getCommon().getOrganization()))
    .value(userPool.getUserPoolId())
    .build();
```

**For organization = "mycompany":**
- Export name: `mycompany-userpoolid`
- Can be imported by: `Fn.importValue("mycompany-userpoolid")`

## Validating Your Configuration

Before deploying, validate your configuration:

```bash
# Synthesize CloudFormation templates
cd aws-webapp-infra/infra
cdk synth

# Check for errors in output
# Look for template validation messages
```

**Common validation errors:**

| Error | Cause | Fix |
|-------|-------|-----|
| `Account ID must be 12 digits` | Invalid account format | Use numeric account ID without hyphens |
| `Hosted zone not found` | Wrong zone ID or region | Verify in Route 53 console |
| `Domain not verified` | SES domain not set up | Complete SES domain verification first |
| `Region not supported` | Service unavailable | Choose supported region |

## Prerequisites Checklist

Before configuring, ensure you have:

- [ ] AWS Account ID (12 digits)
- [ ] Target AWS region determined
- [ ] Domain registered in Route 53
- [ ] Route 53 Hosted Zone created
- [ ] Hosted Zone ID retrieved
- [ ] Email address for SES verification
- [ ] CDK bootstrapped in target account/region

## Environment-Specific Templates

Different environments can have different configurations:

```
infra/src/main/resources/
├── prototype/
│   └── v1/
│       ├── conf.mustache          # Dev configuration
│       ├── auth/userpool.mustache
│       └── api/user.mustache
└── production/
    └── v1/
        ├── conf.mustache          # Production configuration
        ├── auth/userpool.mustache
        └── api/user.mustache
```

**Example differences:**

**Prototype:**
- DynamoDB: On-demand billing
- Lambda: 256MB memory
- Cognito: Simple password policy

**Production:**
- DynamoDB: Provisioned capacity with auto-scaling
- Lambda: 1024MB memory
- Cognito: Strict password policy, MFA required

## Complete Configuration Examples

### Druid Architecture (Full Example)

**File**: `aws-druid-infra/cdk.context.json`

<details>
<summary>Click to expand complete Druid configuration</summary>

```json
{
  "host:id": "xyz",
  "host:organization": "stxkxs",
  "host:account": "123456789012",
  "host:region": "us-west-2",
  "host:name": "vanilla",
  "host:alias": "eks",
  "host:environment": "prototype",
  "host:version": "v1",
  "host:domain": "stxkxs.io",

  "hosted:id": "fff",
  "hosted:organization": "data",
  "hosted:account": "123456789012",
  "hosted:region": "us-west-2",
  "hosted:name": "data",
  "hosted:alias": "analytics",
  "hosted:environment": "prototype",
  "hosted:version": "v1",
  "hosted:domain": "data.stxkxs.io",

  "hosted:eks:grafana:instanceId": "123456",
  "hosted:eks:grafana:key": "glc_your_access_policy_token_here",
  "hosted:eks:grafana:lokiHost": "https://logs-prod-123.grafana.net",
  "hosted:eks:grafana:lokiUsername": "123456",
  "hosted:eks:grafana:prometheusHost": "https://prometheus-prod-123-prod-us-west-0.grafana.net",
  "hosted:eks:grafana:prometheusUsername": "123456",
  "hosted:eks:grafana:tempoHost": "https://tempo-prod-123-prod-us-west-0.grafana.net/tempo",
  "hosted:eks:grafana:tempoUsername": "123456",
  "hosted:eks:grafana:pyroscopeHost": "https://profiles-prod-123.grafana.net:443",

  "hosted:eks:druid:release": "streaming",

  "hosted:eks:administrators": [
    {
      "username": "administrator001",
      "role": "arn:aws:iam::123456789012:role/AWSReservedSSO_AdministratorAccess_abc123def456",
      "email": "admin@example.com"
    }
  ],

  "hosted:eks:users": [],
  "hosted:tags": [],

  "availability-zones:account=123456789012:region=us-west-2": [
    "us-west-2a",
    "us-west-2b",
    "us-west-2c",
    "us-west-2d"
  ],

  "acknowledged-issue-numbers": [
    32775
  ]
}
```

**Required changes**:
- Replace `123456789012` with your AWS account ID
- Update `hosted:eks:grafana:*` fields with your Grafana Cloud credentials
- Update `hosted:eks:administrators` with your IAM role ARN
- Change `hosted:id`, `hosted:organization`, `hosted:domain` to your values

</details>

### WebApp Architecture (Full Example)

**File**: `aws-webapp-infra/infra/cdk.context.json`

<details>
<summary>Click to expand complete WebApp configuration</summary>

```json
{
  "host:id": "xyz",
  "host:organization": "stxkxs",
  "host:account": "123456789012",
  "host:region": "us-west-2",
  "host:name": "vanilla",
  "host:alias": "webapp",
  "host:environment": "prototype",
  "host:version": "v1",
  "host:domain": "stxkxs.io",

  "hosted:id": "app",
  "hosted:organization": "acme-corp",
  "hosted:account": "123456789012",
  "hosted:region": "us-west-2",
  "hosted:name": "webapp",
  "hosted:alias": "production",
  "hosted:environment": "production",
  "hosted:version": "v1",
  "hosted:domain": "example.com",

  "hosted:ses:hosted:zone": "Z1234567890ABC",
  "hosted:ses:email": "noreply@example.com",

  "hosted:tags": [],

  "availability-zones:account=123456789012:region=us-west-2": [
    "us-west-2a",
    "us-west-2b",
    "us-west-2c",
    "us-west-2d"
  ]
}
```

**Required changes**:
- Replace `123456789012` with your AWS account ID
- Update `hosted:ses:hosted:zone` with your Route 53 Hosted Zone ID
- Update `hosted:ses:email` with your verified SES email address
- Change `hosted:id`, `hosted:organization`, `hosted:domain` to your values

</details>

### Quick Configuration Checklist

**Before deploying**, ensure you've configured:

**All Deployments**:
- [ ] `host:account` and `hosted:account` = Your AWS account ID
- [ ] `host:region` and `hosted:region` = Target AWS region
- [ ] `hosted:id` = Unique 3-letter identifier
- [ ] `hosted:domain` = Your domain name
- [ ] `availability-zones` = AZs for your region

**Druid Only**:
- [ ] All `hosted:eks:grafana:*` fields with Grafana Cloud credentials
- [ ] `hosted:eks:administrators` with your IAM role ARN
- [ ] `hosted:eks:druid:release` = Deployment name (e.g., "streaming")

**WebApp Only**:
- [ ] `hosted:ses:hosted:zone` = Route 53 Hosted Zone ID
- [ ] `hosted:ses:email` = Verified SES email address

## Next Steps

- [Quick Start →](/getting-started/quickstart.md) - Deploy in 10 minutes
- [Core Concepts →](/getting-started/concepts.md) - Understand the yaml → model → construct pattern
- [Deploy Your Configuration →](/getting-started/setup.md)
- [Service Quotas →](/getting-started/service-quotas.md) - Verify AWS limits
- [Launch Checklist →](/getting-started/launch.md) - Pre-deployment verification
