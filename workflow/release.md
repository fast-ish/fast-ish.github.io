# Release

## Overview

A **Release** represents a specific deployment of infrastructure (webapp or druid) with a defined configuration. When a contributor launches a release, it triggers the CodePipeline that synthesizes CloudFormation templates and deploys resources to AWS.

Releases are the culmination of all workflow inputs - they combine Synthesizer, Organization, Team, and Contributor configuration into a complete infrastructure deployment.

## What is a Release?

### Conceptual Definition

A Release defines:

- **Infrastructure Type**: webapp or druid
- **Environment**: prototype, production, etc.
- **Version**: v1, v2, etc.
- **Configuration**: Domain, email, resource settings
- **Deployment Target**: Which synthesizer/organization/team

### Configuration Structure

```typescript
interface Release {
  // Identification
  id: string;                    // Unique release ID
  name: string;                  // Release name
  type: 'webapp' | 'druid';      // Infrastructure type

  // Parent relationships
  team: string;                  // Parent team ID
  organization: string;          // Parent organization ID
  synthesizer: string;           // Parent synthesizer ID

  // Environment configuration
  environment: string;           // Environment name (e.g., "production")
  version: string;               // Version (e.g., "v1")

  // WebApp specific configuration
  webapp?: {
    domain: string;              // Primary domain
    ses: {
      hostedZoneId: string;      // Route 53 hosted zone ID
      email: string;             // SES verification email
    };
  };

  // Druid specific configuration
  druid?: {
    clusterSize: string;         // small, medium, large
    storageSize: number;         // GB of storage
  };

  // Deployment metadata
  status: ReleaseStatus;
  lastDeployment?: Deployment;

  // Settings
  createdAt: string;
  updatedAt: string;
}

type ReleaseStatus = 'draft' | 'validated' | 'deployed' | 'failed';

interface Deployment {
  id: string;
  startTime: string;
  endTime?: string;
  status: 'in_progress' | 'success' | 'failed';
  contributor: string;
  stackOutputs?: Record<string, string>;
}
```

## How Release Inputs Flow to CloudFormation

### Complete Data Flow

```
User creates release with inputs:
├── type: webapp
├── environment: production
├── version: v1
├── domain: acme.com
└── ses:
    ├── hostedZoneId: Z1234567890ABC
    └── email: noreply@acme.com

Combined with parent resources:
├── Synthesizer:
│   ├── account: 123456789012
│   └── region: us-west-2
│
├── Organization:
│   ├── name: acme-corp
│   └── tags: [...]
│
└── Team:
    └── name: platform-team

        ↓

Generated cdk.context.json:
{
  "host:id": "org_abc123",
  "host:organization": "acme-corp",
  "host:account": "351619759866",
  "host:region": "us-west-2",
  "hosted:id": "rel_xyz789",
  "hosted:organization": "acme-corp",
  "hosted:account": "123456789012",
  "hosted:region": "us-west-2",
  "hosted:name": "production",
  "hosted:alias": "webapp",
  "hosted:environment": "production",
  "hosted:version": "v1",
  "hosted:domain": "acme.com",
  "hosted:ses:hosted:zone": "Z1234567890ABC",
  "hosted:ses:email": "noreply@acme.com"
}

        ↓

Template resolution:
Path: aws-webapp-infra/infra/src/main/resources/production/v1/conf.mustache

        ↓

CloudFormation synthesis:
- NetworkNestedStack.template.json
- SesNestedStack.template.json
- AuthNestedStack.template.json
- DbNestedStack.template.json
- ApiNestedStack.template.json

        ↓

Resources created in AWS:
- VPC: acme-corp-production-vpc
- User Pool: acme-corp-production-userpool
- API: acme-corp-production-api
- Table: acme-corp-production-user-table
- SES: acme.com (verified)
```

## Release Types

### WebApp Release

**Purpose:** Deploy serverless web application infrastructure

**Components created:**
- VPC with public/private subnets
- Cognito User Pool with app client
- API Gateway with Lambda functions
- DynamoDB tables
- SES email identity
- Route 53 DNS records

**Required configuration:**
```typescript
interface WebAppRelease {
  type: 'webapp';
  environment: string;         // Maps to template directory
  version: string;             // Maps to template version
  domain: string;              // SES and Route 53 domain
  ses: {
    hostedZoneId: string;      // Route 53 zone for DNS automation
    email: string;             // Email for SES verification
  };
}
```

**Example:**
```json
{
  "id": "rel_webapp_prod_001",
  "name": "webapp-production-v1",
  "type": "webapp",
  "environment": "production",
  "version": "v1",
  "webapp": {
    "domain": "acme.com",
    "ses": {
      "hostedZoneId": "Z1234567890ABC",
      "email": "noreply@acme.com"
    }
  }
}
```

**Results in CloudFormation:**
```yaml
# VPC
VPC:
  Type: AWS::EC2::VPC
  Properties:
    CidrBlock: 192.168.0.0/16
    Tags:
      - Key: Name
        Value: acme-corp-production-vpc

# Cognito User Pool
UserPool:
  Type: AWS::Cognito::UserPool
  Properties:
    UserPoolName: acme-corp-production-userpool
    # Config from production/v1/auth/userpool.mustache

# SES Identity
EmailIdentity:
  Type: AWS::SES::EmailIdentity
  Properties:
    EmailIdentity: acme.com  # From release.webapp.domain

# Route 53 DKIM Records
DkimRecord1:
  Type: AWS::Route53::RecordSet
  Properties:
    HostedZoneId: Z1234567890ABC  # From release.webapp.ses.hostedZoneId
```

### Druid Release

**Purpose:** Deploy Apache Druid analytics infrastructure

**Components created:**
- EKS cluster with Karpenter
- RDS PostgreSQL (metadata store)
- S3 buckets (deep storage)
- MSK Kafka cluster
- Druid pods via Helm
- Load balancers

**Required configuration:**
```typescript
interface DruidRelease {
  type: 'druid';
  environment: string;
  version: string;
  druid: {
    clusterSize: 'small' | 'medium' | 'large';
    storageSize: number;         // GB
    kafkaEnabled: boolean;
  };
}
```

**Example:**
```json
{
  "id": "rel_druid_prod_001",
  "name": "druid-production-v1",
  "type": "druid",
  "environment": "production",
  "version": "v1",
  "druid": {
    "clusterSize": "large",
    "storageSize": 500,
    "kafkaEnabled": true
  }
}
```

## Release Launch Process

### Step 1: Validation

Before deployment, the release is validated:

```typescript
// API endpoint: POST /api/release/{releaseId}/verify
const validationChecks = [
  {
    name: 'Synthesizer Access',
    check: () => validateSynthesizerAccess(release.synthesizer)
  },
  {
    name: 'DNS Configuration',
    check: () => validateHostedZone(release.webapp.ses.hostedZoneId)
  },
  {
    name: 'Email Deliverability',
    check: () => validateSESEmail(release.webapp.ses.email)
  },
  {
    name: 'Resource Quotas',
    check: () => validateTeamQuotas(release.team)
  },
  {
    name: 'IAM Permissions',
    check: () => validateIAMRoles(release.synthesizer)
  }
];
```

**Validation response:**
```json
{
  "releaseId": "rel_webapp_prod_001",
  "valid": true,
  "checks": [
    {"name": "Synthesizer Access", "status": "passed"},
    {"name": "DNS Configuration", "status": "passed"},
    {"name": "Email Deliverability", "status": "warning", "message": "Email not yet verified"},
    {"name": "Resource Quotas", "status": "passed"},
    {"name": "IAM Permissions", "status": "passed"}
  ]
}
```

### Step 2: Launch Trigger

Contributor triggers deployment:

```typescript
// API endpoint: POST /api/release/{releaseId}/launch
// Request body:
{
  "contributor": "contrib_alice123",
  "environment": "production",
  "approvalRequired": true
}
```

**EventBridge event published:**
```json
{
  "version": "0",
  "id": "evt_deploy_abc123",
  "detail-type": "Release Launch",
  "source": "fastish.release",
  "time": "2024-01-15T10:30:00Z",
  "region": "us-west-2",
  "detail": {
    "subscriber_id": "sub_acme_corp",
    "release_id": "rel_webapp_prod_001",
    "contributor_id": "contrib_alice123",
    "contributor_email": "alice@acme-corp.com",
    "type": "webapp",
    "action": "deploy",
    "environment": "production",
    "version": "v1"
  }
}
```

### Step 3: Pipeline Execution

EventBridge triggers CodePipeline in `spaz-infra`:

**Pipeline stages:**

1. **Code** (2-3 minutes)
   - Fetches cdk-common repository
   - Fetches aws-webapp-infra repository
   - Outputs: Source code artifacts

2. **Build** (3-5 minutes)
   - Runs `mvn install` on both repos
   - Compiles dependencies
   - Outputs: M2 artifact (Maven cache)

3. **Prepare** (1-2 minutes)
   - Aggregates release configuration
   - Generates `cdk.context.json`
   - Environment variables used:
     ```bash
     subscriber_id="sub_acme_corp"
     release_id="rel_webapp_prod_001"
     contributor_email="alice@acme-corp.com"
     ```
   - Outputs: WEBAPP_PREPARED artifact with `cdk.context.json`

4. **Synth** (2-3 minutes)
   - Runs `cdk synth`
   - Processes Mustache templates
   - Generates CloudFormation templates
   - Outputs: WEBAPP_SYNTHESIZED artifact (cdk.out/)

5. **Deploy** (15-25 minutes)
   - Assumes deployment role in subscriber account
   - Runs `cdk deploy`
   - Creates CloudFormation stacks:
     ```
     DeploymentStack (main)
     ├── NetworkNestedStack (5 min)
     ├── SesNestedStack (3 min)
     ├── AuthNestedStack (8 min) [waits for SES]
     ├── DbNestedStack (2 min)
     └── ApiNestedStack (7 min) [waits for Auth]
     ```
   - Outputs: WEBAPP_DEPLOYED artifact with deployment metadata

6. **Publish** (1 minute)
   - Extracts stack outputs
   - Publishes to DynamoDB
   - Sends notifications
   - Outputs: WEBAPP_PUBLISHED artifact

**Total time:** ~25-40 minutes

### Step 4: Post-Deployment

**Stack outputs captured:**
```json
{
  "deploymentId": "deploy_20240115_103000",
  "releaseId": "rel_webapp_prod_001",
  "stackName": "acme-corp-production-webapp",
  "status": "deployed",
  "outputs": {
    "webappuserpoolid": "us-west-2_ABC123XYZ",
    "webappuserpoolclientid": "1a2b3c4d5e6f7g8h9i0j",
    "webappapigwid": "abc123xyz9",
    "webappapigwendpoint": "https://abc123xyz9.execute-api.us-west-2.amazonaws.com/v1",
    "webappusertableid": "acme-corp-production-user-table",
    "webappsesidentityarn": "arn:aws:ses:us-west-2:123456789012:identity/acme.com"
  },
  "deployedAt": "2024-01-15T10:55:00Z",
  "deployedBy": "alice@acme-corp.com"
}
```

**Notification sent:**
```
Subject: Deployment Complete: webapp-production-v1

Your deployment has completed successfully!

Release: webapp-production-v1
Environment: production
Stack: acme-corp-production-webapp
Duration: 25 minutes
Deployed by: alice@acme-corp.com

Outputs:
- User Pool ID: us-west-2_ABC123XYZ
- API Endpoint: https://abc123xyz9.execute-api.us-west-2.amazonaws.com/v1

Next steps:
1. Verify SES email (check inbox for noreply@acme.com)
2. Export stack outputs to .env.local
3. Deploy Next.js application

View deployment: https://portal.fasti.sh/deployments/deploy_20240115_103000
```

## Environment & Version Templates

### Template Directory Structure

```
aws-webapp-infra/infra/src/main/resources/
├── prototype/
│   └── v1/
│       ├── conf.mustache
│       ├── auth/
│       │   ├── userpool.mustache
│       │   └── triggers.mustache
│       └── api/
│           └── user.mustache
│
└── production/
    ├── v1/
    │   ├── conf.mustache
    │   ├── auth/
    │   │   ├── userpool.mustache
    │   │   └── triggers.mustache
    │   └── api/
    │       └── user.mustache
    │
    └── v2/
        ├── conf.mustache
        └── ...
```

### Environment Differences

**Prototype environment:**
```yaml
# prototype/v1/auth/userpool.mustache
passwordPolicy:
  minimumLength: 8
  requireUppercase: false
  requireNumbers: false
  requireSymbols: false

mfaConfiguration: OPTIONAL

deviceTracking:
  enabled: false
```

**Production environment:**
```yaml
# production/v1/auth/userpool.mustache
passwordPolicy:
  minimumLength: 12
  requireUppercase: true
  requireNumbers: true
  requireSymbols: true

mfaConfiguration: REQUIRED

deviceTracking:
  enabled: true
```

### Version Migration

**v1 → v2 migration:**

```typescript
// Release configuration
{
  "name": "webapp-production-v2",
  "type": "webapp",
  "environment": "production",
  "version": "v2",  // Changed from v1
  ...
}
```

**What changes:**
- Template path: `production/v2/` instead of `production/v1/`
- New features added in v2 templates
- Backward-compatible changes
- Migration guide for existing deployments

## Configuration Examples

### Example 1: Development WebApp Release

```json
{
  "id": "rel_webapp_dev_001",
  "name": "webapp-development-v1",
  "type": "webapp",
  "environment": "prototype",
  "version": "v1",
  "team": "team_platform",
  "organization": "org_acme_dev",
  "synthesizer": "synth_dev",
  "webapp": {
    "domain": "dev.acme-corp.com",
    "ses": {
      "hostedZoneId": "Z1111111111111",
      "email": "dev-noreply@acme-corp.com"
    }
  },
  "status": "validated"
}
```

### Example 2: Production WebApp Release

```json
{
  "id": "rel_webapp_prod_001",
  "name": "webapp-production-v1",
  "type": "webapp",
  "environment": "production",
  "version": "v1",
  "team": "team_platform",
  "organization": "org_acme",
  "synthesizer": "synth_prod",
  "webapp": {
    "domain": "acme.com",
    "ses": {
      "hostedZoneId": "Z2222222222222",
      "email": "noreply@acme.com"
    }
  },
  "status": "deployed",
  "lastDeployment": {
    "id": "deploy_20240115_103000",
    "startTime": "2024-01-15T10:30:00Z",
    "endTime": "2024-01-15T10:55:00Z",
    "status": "success",
    "contributor": "alice@acme-corp.com"
  }
}
```

### Example 3: Druid Analytics Release

```json
{
  "id": "rel_druid_prod_001",
  "name": "druid-analytics-v1",
  "type": "druid",
  "environment": "production",
  "version": "v1",
  "team": "team_data",
  "organization": "org_acme",
  "synthesizer": "synth_prod",
  "druid": {
    "clusterSize": "large",
    "storageSize": 1000,
    "kafkaEnabled": true
  },
  "status": "deployed"
}
```

## Best Practices

1. **Release Naming**
   - Include type, environment, version: `webapp-production-v1`
   - Use consistent naming across releases
   - Avoid special characters

2. **Environment Strategy**
   - Always test in prototype first
   - Use separate releases for dev/staging/prod
   - Mirror production configuration in staging

3. **Version Management**
   - Start with v1
   - Create v2 for breaking changes
   - Maintain backward compatibility when possible
   - Document migration paths

4. **SES Configuration**
   - Verify email address before first deployment
   - Use dedicated email per environment (dev@, noreply@)
   - Monitor bounce rates and complaints
   - Request production access if in sandbox

5. **Deployment Timing**
   - Deploy during low-traffic periods
   - Allow 30-45 minutes for full deployment
   - Have rollback plan ready
   - Monitor CloudWatch during deployment

## Troubleshooting

### SES Email Not Verified

**Error:** `Email identity is not verified`

**Solution:**
1. Check email inbox for verification link
2. Resend verification from SES console
3. Verify domain instead of individual email
4. Check spam folder

### Hosted Zone Not Found

**Error:** `Hosted zone Z123... does not exist`

**Solution:**
1. Verify zone ID is correct (from Route 53 console)
2. Check zone is in correct AWS account
3. Ensure zone is for correct domain
4. Verify CDK has access to Route 53

### Stack Already Exists

**Error:** `Stack acme-corp-production-webapp already exists`

**Solution:**
1. Check for existing deployment
2. Delete old stack if no longer needed
3. Use different organization/environment/name
4. Update existing stack instead of creating new

### Deployment Timeout

**Error:** `Stack deployment exceeded timeout`

**Solution:**
1. Check CloudFormation events for stuck resources
2. Verify IAM roles have correct permissions
3. Check VPC/subnet configuration
4. Increase timeout if resources are slow to create

## Next Steps

- [Using Stack Outputs →](/webapp/overview.md#using-stack-outputs-in-nextjs)
- [Monitoring Deployments →](/webapp/overview.md#monitoring--observability)
- [WebApp Architecture →](/webapp/overview.md)
- [Druid Architecture →](/druid/overview.md)
