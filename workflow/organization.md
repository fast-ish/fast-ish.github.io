# Organization

## Overview

An **Organization** is a logical grouping of teams and resources within a Synthesizer. It provides resource naming conventions, tagging policies, and organizational structure for your infrastructure deployments.

Organizations map to real-world organizational boundaries such as:
- GitHub organizations
- Business units
- Product lines
- Customer divisions (in multi-tenant scenarios)

## What is an Organization?

### Conceptual Definition

An Organization establishes the top-level namespace and governance policies for all resources deployed within it. It serves as:

- **Naming Prefix**: All resources inherit the organization name
- **Tag Source**: Defines tags applied to all child resources
- **Access Boundary**: IAM policies can scope to organization level
- **Cost Center**: Enables cost tracking and allocation

### Configuration Structure

```typescript
interface Organization {
  // Identification
  id: string;                    // Unique organization ID
  name: string;                  // Organization name (e.g., "acme-corp", "engineering")

  // Parent relationship
  synthesizer: string;           // Parent synthesizer ID

  // Metadata
  description?: string;          // Human-readable description
  tags: Tag[];                   // Resource tags

  // Governance
  costCenter?: string;           // Cost allocation identifier
  owner?: string;                // Organization owner email

  // Settings
  createdAt: string;             // Creation timestamp
  updatedAt: string;             // Last update timestamp
}

interface Tag {
  key: string;
  value: string;
}
```

## How Organization Inputs Are Used

### 1. Organization Name → Resource Naming

**Input:**
```json
{
  "name": "acme-corp"
}
```

**Used in `cdk.context.json`:**
```json
{
  "platform:organization": "acme-corp",
  "deployment:organization": "acme-corp"
}
```

**Flows to CloudFormation stack naming:**
```java
// DeploymentStack.java
String stackName = String.format("%s-%s-%s",
    context.get("deployment:organization"),  // acme-corp
    context.get("deployment:name"),          // production
    context.get("deployment:alias")          // webapp
);
// Result: acme-corp-production-webapp
```

**Applied to resource names:**

**Cognito User Pool:**
```yaml
UserPool:
  Type: AWS::Cognito::UserPool
  Properties:
    UserPoolName: acme-corp-production-userpool
```

**DynamoDB Table:**
```yaml
UserTable:
  Type: AWS::DynamoDB::Table
  Properties:
    TableName: acme-corp-production-user-table
```

**API Gateway:**
```yaml
RestApi:
  Type: AWS::ApiGateway::RestApi
  Properties:
    Name: acme-corp-production-api
```

**Lambda Functions:**
```yaml
UserApiFunction:
  Type: AWS::Lambda::Function
  Properties:
    FunctionName: acme-corp-production-user-api
```

**S3 Buckets:**
```yaml
AssetsBucket:
  Type: AWS::S3::Bucket
  Properties:
    BucketName: acme-corp-production-assets
```

### 2. Organization ID → Resource Identification

**Input:**
```json
{
  "id": "org_abc123xyz"
}
```

**Used in `cdk.context.json`:**
```json
{
  "platform:id": "org_abc123xyz",
  "deployment:id": "org_abc123xyz"
}
```

**Applied to resource IDs:**
```java
// CDK construct IDs
String constructId = String.format("%s-%s-%s",
    config.getId(),        // org_abc123xyz
    config.getType(),      // webapp
    resourceType           // vpc, auth, db, etc.
);

// Example: org_abc123xyz-webapp-vpc
// Example: org_abc123xyz-webapp-auth
```

**Used in CloudFormation logical IDs:**
```yaml
Resources:
  OrgAbc123xyzWebappVpc:
    Type: AWS::EC2::VPC

  OrgAbc123xyzWebappAuthUserPool:
    Type: AWS::Cognito::UserPool

  OrgAbc123xyzWebappDbUserTable:
    Type: AWS::DynamoDB::Table
```

### 3. Tags → Resource Tagging

**Input:**
```json
{
  "tags": [
    {"key": "Organization", "value": "acme-corp"},
    {"key": "CostCenter", "value": "engineering"},
    {"key": "Environment", "value": "production"},
    {"key": "ManagedBy", "value": "Fastish"}
  ]
}
```

**Used in `cdk.context.json`:**
```json
{
  "deployment:tags": [
    {"key": "Organization", "value": "acme-corp"},
    {"key": "CostCenter", "value": "engineering"},
    {"key": "Environment", "value": "production"},
    {"key": "ManagedBy", "value": "Fastish"}
  ]
}
```

**Applied to all CloudFormation resources:**
```java
// DeploymentStack.java
Tags.of(this).add("Organization", config.getTag("Organization"));
Tags.of(this).add("CostCenter", config.getTag("CostCenter"));
Tags.of(this).add("Environment", config.getTag("Environment"));
Tags.of(this).add("ManagedBy", config.getTag("ManagedBy"));
```

**Results in CloudFormation:**
```yaml
VPC:
  Type: AWS::EC2::VPC
  Properties:
    Tags:
      - Key: Organization
        Value: acme-corp
      - Key: CostCenter
        Value: engineering
      - Key: Environment
        Value: production
      - Key: ManagedBy
        Value: Fastish

UserPool:
  Type: AWS::Cognito::UserPool
  Properties:
    UserPoolTags:
      Organization: acme-corp
      CostCenter: engineering
      Environment: production
      ManagedBy: Fastish

UserTable:
  Type: AWS::DynamoDB::Table
  Properties:
    Tags:
      - Key: Organization
        Value: acme-corp
      - Key: CostCenter
        Value: engineering
      - Key: Environment
        Value: production
      - Key: ManagedBy
        Value: Fastish
```

**Benefits of tagging:**
- **Cost Allocation**: Track costs by organization, cost center, environment
- **Resource Discovery**: Find all resources for an organization
- **Access Control**: IAM policies can filter by tags
- **Compliance**: Audit and governance requirements
- **Automation**: Scripts can filter resources by tags

### 4. Cost Center → Billing & Cost Tracking

**Input:**
```json
{
  "costCenter": "engineering-platform"
}
```

**Applied as tag:**
```yaml
Tags:
  - Key: CostCenter
    Value: engineering-platform
```

**Used in AWS Cost Explorer:**
```bash
# Get costs for this organization
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://filter.json

# filter.json
{
  "Tags": {
    "Key": "Organization",
    "Values": ["acme-corp"]
  }
}
```

**Cost allocation reports:**
```sql
-- Example Athena query on Cost and Usage Report
SELECT
  line_item_usage_account_id,
  resource_tags_user_organization,
  resource_tags_user_cost_center,
  SUM(line_item_blended_cost) as total_cost
FROM
  cur_database.cur_table
WHERE
  resource_tags_user_organization = 'acme-corp'
  AND year = '2024'
  AND month = '01'
GROUP BY
  line_item_usage_account_id,
  resource_tags_user_organization,
  resource_tags_user_cost_center
```

### 5. Owner → Access Control & Notifications

**Input:**
```json
{
  "owner": "platform-team@acme-corp.com"
}
```

**Applied as tag:**
```yaml
Tags:
  - Key: Owner
    Value: platform-team@acme-corp.com
```

**Used in notifications:**
```yaml
# SNS topic for deployment events
DeploymentTopic:
  Type: AWS::SNS::Topic
  Properties:
    TopicName: acme-corp-production-deployments
    Subscription:
      - Protocol: email
        Endpoint: platform-team@acme-corp.com  # From organization.owner

# CloudWatch alarm actions
HighErrorRateAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmActions:
      - !Ref DeploymentTopic
    AlarmDescription: !Sub "High error rate for ${Organization} resources"
```

**Used in IAM policies:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "cloudformation:DescribeStacks",
      "cloudformation:ListStackResources"
    ],
    "Resource": "*",
    "Condition": {
      "StringEquals": {
        "aws:ResourceTag/Organization": "acme-corp",
        "aws:ResourceTag/Owner": "platform-team@acme-corp.com"
      }
    }
  }]
}
```

## Organization Hierarchy & Relationships

### Relationship to Synthesizer

```
Synthesizer (AWS Account: 123456789012, Region: us-west-2)
    ├── Organization: acme-corp
    │   ├── Team: platform-team
    │   ├── Team: product-team
    │   └── Team: data-team
    │
    └── Organization: acme-labs
        ├── Team: research-team
        └── Team: innovation-team
```

**Multiple organizations in same synthesizer:**
- Share same AWS account and region
- Isolated by naming and tagging
- Separate cost tracking
- Different access policies

### Organization Context in Deployment

**Pipeline variables:**
```bash
# spaz-infra CodePipeline stage
subscriber_id="sub_abc123"      # Maps to synthesizer
release_id="rel_xyz789"         # Maps to specific release
organization="acme-corp"        # Organization name
```

**Prepare stage generates:**
```json
{
  "platform:organization": "acme-corp",
  "deployment:organization": "acme-corp",
  "deployment:name": "production",
  "deployment:environment": "production"
}
```

**Template resolution:**
```
Path: aws-webapp-infra/infra/src/main/resources/production/v1/conf.mustache

Template:
---
common:
  organization: {{platform:organization}}
  name: {{deployment:name}}

auth:
  userPoolName: {{platform:organization}}-{{deployment:name}}-userpool

api:
  name: {{platform:organization}}-{{deployment:name}}-api

db:
  tables:
    - name: {{platform:organization}}-{{deployment:name}}-user-table
```

## Common Organization Patterns

### Pattern 1: Single Organization (Small Teams)

```json
{
  "synthesizer": "production",
  "organizations": [
    {
      "name": "myapp",
      "tags": [
        {"key": "Environment", "value": "production"}
      ]
    }
  ]
}
```

**Use case:** Small team, single product, simple structure

**Resources created:**
- `myapp-production-userpool`
- `myapp-production-api`
- `myapp-production-user-table`

### Pattern 2: Environment-Based Organizations

```json
{
  "synthesizer": "shared-account",
  "organizations": [
    {
      "name": "myapp-dev",
      "tags": [
        {"key": "Environment", "value": "development"}
      ]
    },
    {
      "name": "myapp-staging",
      "tags": [
        {"key": "Environment", "value": "staging"}
      ]
    },
    {
      "name": "myapp-prod",
      "tags": [
        {"key": "Environment", "value": "production"}
      ]
    }
  ]
}
```

**Use case:** Separate environments in same AWS account

**Resources created:**
- `myapp-dev-production-userpool`
- `myapp-staging-production-userpool`
- `myapp-prod-production-userpool`

### Pattern 3: Product Line Organizations

```json
{
  "synthesizer": "shared-account",
  "organizations": [
    {
      "name": "product-a",
      "costCenter": "product-a-team",
      "owner": "product-a@acme-corp.com"
    },
    {
      "name": "product-b",
      "costCenter": "product-b-team",
      "owner": "product-b@acme-corp.com"
    }
  ]
}
```

**Use case:** Multiple products sharing infrastructure

**Benefits:**
- Separate cost tracking per product
- Different ownership and access
- Shared AWS account reduces overhead

### Pattern 4: Customer/Tenant Organizations (Multi-Tenant SaaS)

```json
{
  "synthesizer": "saas-platform",
  "organizations": [
    {
      "name": "customer-alpha",
      "tags": [
        {"key": "CustomerId", "value": "cust_001"},
        {"key": "Tier", "value": "enterprise"}
      ]
    },
    {
      "name": "customer-beta",
      "tags": [
        {"key": "CustomerId", "value": "cust_002"},
        {"key": "Tier", "value": "professional"}
      ]
    }
  ]
}
```

**Use case:** SaaS platform with dedicated infrastructure per customer

**Benefits:**
- Complete resource isolation per customer
- Separate billing and cost tracking
- Customer-specific configurations
- Compliance and data sovereignty requirements

## Configuration Examples

### Example 1: Basic Organization

```json
{
  "id": "org_abc123",
  "name": "acme-corp",
  "synthesizer": "synth_production",
  "description": "ACME Corporation production infrastructure",
  "tags": [
    {"key": "Organization", "value": "acme-corp"},
    {"key": "ManagedBy", "value": "Fastish"}
  ]
}
```

**Results in:**
- Stack: `acme-corp-production-webapp`
- User Pool: `acme-corp-production-userpool`
- API: `acme-corp-production-api`

### Example 2: Organization with Cost Tracking

```json
{
  "id": "org_xyz789",
  "name": "platform-engineering",
  "synthesizer": "synth_shared",
  "costCenter": "eng-platform-1001",
  "owner": "platform-team@acme-corp.com",
  "tags": [
    {"key": "Organization", "value": "platform-engineering"},
    {"key": "CostCenter", "value": "eng-platform-1001"},
    {"key": "Department", "value": "Engineering"},
    {"key": "Owner", "value": "platform-team@acme-corp.com"}
  ]
}
```

**Benefits:**
- Track costs by cost center `eng-platform-1001`
- Filter resources by `Department: Engineering`
- Notifications sent to `platform-team@acme-corp.com`

### Example 3: Multi-Environment Organization

```json
{
  "id": "org_dev123",
  "name": "myapp-development",
  "synthesizer": "synth_dev",
  "tags": [
    {"key": "Organization", "value": "myapp-development"},
    {"key": "Environment", "value": "development"},
    {"key": "AutoShutdown", "value": "true"}
  ]
}
```

**Special tags:**
- `AutoShutdown: true` → Lambda can shutdown resources overnight
- `Environment: development` → Lower resource quotas, relaxed policies

## Troubleshooting

### Naming Conflicts

**Error:** `Stack with name 'acme-corp-production-webapp' already exists`

**Cause:** Organization name + environment creates duplicate stack name

**Solutions:**
1. Use unique organization names:
   - ❌ `acme-corp` (for both dev and prod)
   - ✅ `acme-corp-dev` and `acme-corp-prod`

2. Use different synthesizers for environments
3. Include region in organization name for multi-region

### Tag Limit Exceeded

**Error:** `Too many tags for resource`

**Cause:** AWS limits tags to 50 per resource

**Solution:** Prioritize essential tags:
- Organization
- Environment
- CostCenter
- Owner
- ManagedBy

Remove verbose or redundant tags.

### Resource Name Too Long

**Error:** `Resource name exceeds maximum length`

**Cause:** `organization-name-environment-alias-resource-type` too long

**Solutions:**
1. Use shorter organization names:
   - ❌ `acme-corporation-engineering-platform`
   - ✅ `acme-eng-platform`

2. Use aliases instead of full names:
   - ❌ `production-webapp-api-gateway`
   - ✅ `prod-api`

3. AWS resource name limits:
   - S3 bucket: 63 characters
   - Lambda function: 64 characters
   - DynamoDB table: 255 characters
   - Cognito User Pool: 128 characters

## Best Practices

1. **Naming Convention**
   - Use lowercase with hyphens: `my-org` not `MyOrg` or `my_org`
   - Keep names under 20 characters
   - Avoid special characters except hyphens

2. **Tagging Strategy**
   - Always include: Organization, Environment, ManagedBy
   - Optional: CostCenter, Owner, Department
   - Use consistent tag keys across all organizations

3. **Cost Allocation**
   - Activate cost allocation tags in AWS Billing
   - Use CostCenter tags for chargeback
   - Review Cost Explorer by tag monthly

4. **Documentation**
   - Document organization purpose and ownership
   - Maintain tag standards document
   - Keep organization configurations in version control

5. **Access Control**
   - Use tag-based IAM policies
   - Grant organization-level access to teams
   - Implement least-privilege access

## Next Steps

- [Team Configuration →](/workflow/teams.md)
- [Contributor Management →](/workflow/contributors.md)
- [Creating Releases →](/workflow/release.md)
- [Synthesizer Setup →](/workflow/synthesizer.md)
