# Teams

## Overview

A **Team** represents a group of contributors (developers, operators) working together within an Organization. Teams provide access control, resource isolation, and collaboration boundaries for infrastructure management.

Teams map to real-world team structures:
- Development teams (frontend, backend, platform)
- Operational teams (SRE, DevOps)
- Business units (product, marketing, analytics)
- Project teams

## What is a Team?

### Conceptual Definition

A Team establishes:

- **Access Boundaries**: IAM policies scoped to team resources
- **Resource Quotas**: Limits on what the team can deploy
- **Collaboration Space**: Shared infrastructure and releases
- **Cost Allocation**: Team-level cost tracking

### Configuration Structure

```typescript
interface Team {
  // Identification
  id: string;                    // Unique team ID
  name: string;                  // Team name (e.g., "platform-team", "product-team")

  // Parent relationships
  organization: string;          // Parent organization ID
  synthesizer: string;           // Parent synthesizer ID

  // Metadata
  description?: string;          // Human-readable description
  tags: Tag[];                   // Team-specific tags

  // Access control
  permissions: Permission[];     // IAM permissions granted to team

  // Resource limits
  quotas?: ResourceQuota;        // Optional resource quotas

  // Settings
  createdAt: string;
  updatedAt: string;
}

interface Permission {
  service: string;               // AWS service (e.g., "lambda", "dynamodb")
  actions: string[];             // Allowed actions
  resources?: string[];          // Resource ARN patterns
}

interface ResourceQuota {
  maxLambdaFunctions?: number;
  maxDynamoDBTables?: number;
  maxS3Buckets?: number;
  maxCostPerMonth?: number;
}
```

## How Team Inputs Are Used

### 1. Team Name → Resource Naming & Access

**Input:**
```json
{
  "name": "platform-team"
}
```

**Used in resource naming:**
```java
// Optional team-specific resources
String teamResourceName = String.format("%s-%s-%s",
    organization,      // acme-corp
    team,             // platform-team
    resourceType      // logs, metrics, etc.
);
// Result: acme-corp-platform-team-logs
```

**Applied to tags:**
```yaml
Tags:
  - Key: Team
    Value: platform-team
```

**Used in IAM policy conditions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["cloudformation:*"],
    "Resource": "*",
    "Condition": {
      "StringEquals": {
        "aws:ResourceTag/Team": "platform-team"
      }
    }
  }]
}
```

### 2. Permissions → IAM Policy Generation

**Input:**
```json
{
  "permissions": [
    {
      "service": "lambda",
      "actions": ["lambda:GetFunction", "lambda:ListFunctions"],
      "resources": ["arn:aws:lambda:*:*:function:acme-corp-*"]
    },
    {
      "service": "dynamodb",
      "actions": ["dynamodb:DescribeTable", "dynamodb:ListTables"],
      "resources": ["arn:aws:dynamodb:*:*:table/acme-corp-*"]
    },
    {
      "service": "logs",
      "actions": ["logs:FilterLogEvents", "logs:GetLogEvents"],
      "resources": ["arn:aws:logs:*:*:log-group:/aws/lambda/acme-corp-*"]
    }
  ]
}
```

**Generates IAM policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LambdaAccess",
      "Effect": "Allow",
      "Action": [
        "lambda:GetFunction",
        "lambda:ListFunctions"
      ],
      "Resource": "arn:aws:lambda:*:*:function:acme-corp-*"
    },
    {
      "Sid": "DynamoDBAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:ListTables"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/acme-corp-*"
    },
    {
      "Sid": "CloudWatchLogsAccess",
      "Effect": "Allow",
      "Action": [
        "logs:FilterLogEvents",
        "logs:GetLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/lambda/acme-corp-*"
    }
  ]
}
```

**Attached to team role:**
```yaml
PlatformTeamRole:
  Type: AWS::IAM::Role
  Properties:
    RoleName: acme-corp-platform-team-role
    AssumeRolePolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Principal:
            AWS: !Sub arn:aws:iam::${AWS::AccountId}:root
          Action: sts:AssumeRole
          Condition:
            StringEquals:
              sts:ExternalId: !Ref TeamExternalId
    ManagedPolicyArns:
      - !Ref PlatformTeamPolicy
    Tags:
      - Key: Team
        Value: platform-team
      - Key: Organization
        Value: acme-corp
```

### 3. Resource Quotas → Service Control Policies

**Input:**
```json
{
  "quotas": {
    "maxLambdaFunctions": 50,
    "maxDynamoDBTables": 20,
    "maxS3Buckets": 10,
    "maxCostPerMonth": 5000
  }
}
```

**Enforced via Service Control Policies (SCPs):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LimitLambdaFunctions",
      "Effect": "Deny",
      "Action": ["lambda:CreateFunction"],
      "Resource": "*",
      "Condition": {
        "NumericGreaterThan": {
          "lambda:FunctionCount": "50"
        },
        "StringEquals": {
          "aws:ResourceTag/Team": "platform-team"
        }
      }
    }
  ]
}
```

**Monitored via CloudWatch:**
```yaml
LambdaCountAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: platform-team-lambda-count-warning
    MetricName: LambdaFunctionCount
    Namespace: AWS/Lambda
    Statistic: Sum
    Period: 300
    EvaluationPeriods: 1
    Threshold: 45  # 90% of quota
    ComparisonOperator: GreaterThanThreshold
    AlarmActions:
      - !Ref TeamNotificationTopic

CostAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: platform-team-cost-warning
    MetricName: EstimatedCharges
    Namespace: AWS/Billing
    Statistic: Maximum
    Period: 21600  # 6 hours
    EvaluationPeriods: 1
    Threshold: 4500  # 90% of $5000 quota
    ComparisonOperator: GreaterThanThreshold
    Dimensions:
      - Name: Currency
        Value: USD
    AlarmActions:
      - !Ref TeamNotificationTopic
```

### 4. Tags → Cost Allocation & Discovery

**Input:**
```json
{
  "tags": [
    {"key": "Team", "value": "platform-team"},
    {"key": "CostCenter", "value": "eng-platform-cc-001"},
    {"key": "Manager", "value": "jane.doe@acme-corp.com"}
  ]
}
```

**Applied to team-managed resources:**
```yaml
# All resources created by platform-team get these tags
Resources:
  TeamLambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      Tags:
        - Key: Team
          Value: platform-team
        - Key: CostCenter
          Value: eng-platform-cc-001
        - Key: Manager
          Value: jane.doe@acme-corp.com
        - Key: Organization
          Value: acme-corp  # Inherited from organization
```

**Used for cost tracking:**
```bash
# Get costs for platform-team
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Team \
  --filter '{
    "Tags": {
      "Key": "Team",
      "Values": ["platform-team"]
    }
  }'
```

## Team Hierarchy & Relationships

### Relationship Structure

```
Synthesizer: production (AWS Account: 123456789012)
    └── Organization: acme-corp
        ├── Team: platform-team
        │   ├── Contributor: alice@acme-corp.com (admin)
        │   ├── Contributor: bob@acme-corp.com (developer)
        │   └── Release: webapp-v1-production
        │
        ├── Team: product-team
        │   ├── Contributor: charlie@acme-corp.com (admin)
        │   └── Release: webapp-v2-production
        │
        └── Team: data-team
            ├── Contributor: diana@acme-corp.com (admin)
            └── Release: druid-v1-production
```

### Access Patterns

**Platform Team Access:**
```json
{
  "permissions": [
    {
      "service": "all",
      "actions": ["*"],
      "resources": ["arn:aws:*:*:*:*acme-corp-platform*"]
    }
  ]
}
```
- Full access to resources with `acme-corp-platform` in name
- Can deploy any infrastructure type
- Can manage other teams (if admin)

**Product Team Access:**
```json
{
  "permissions": [
    {
      "service": "lambda",
      "actions": ["lambda:*"],
      "resources": ["arn:aws:lambda:*:*:function:acme-corp-product-*"]
    },
    {
      "service": "apigateway",
      "actions": ["apigateway:*"],
      "resources": ["arn:aws:apigateway:*::/restapis/acme-corp-product-*"]
    }
  ]
}
```
- Limited to Lambda and API Gateway
- Only for resources with `acme-corp-product` prefix
- Cannot access platform or data team resources

**Data Team Access:**
```json
{
  "permissions": [
    {
      "service": "dynamodb",
      "actions": ["dynamodb:*"],
      "resources": ["arn:aws:dynamodb:*:*:table/acme-corp-data-*"]
    },
    {
      "service": "glue",
      "actions": ["glue:*"],
      "resources": ["*"]
    },
    {
      "service": "athena",
      "actions": ["athena:*"],
      "resources": ["*"]
    }
  ]
}
```
- Full DynamoDB access for data tables
- Full Glue and Athena access
- Cannot deploy Lambda or API Gateway

## Common Team Patterns

### Pattern 1: Functional Teams

**Platform Team:**
```json
{
  "name": "platform-team",
  "description": "Infrastructure and platform services",
  "permissions": [
    {"service": "ec2", "actions": ["*"]},
    {"service": "vpc", "actions": ["*"]},
    {"service": "iam", "actions": ["*"]},
    {"service": "kms", "actions": ["*"]}
  ],
  "quotas": {
    "maxCostPerMonth": 10000
  }
}
```

**Application Team:**
```json
{
  "name": "app-team",
  "description": "Application development team",
  "permissions": [
    {"service": "lambda", "actions": ["*"]},
    {"service": "apigateway", "actions": ["*"]},
    {"service": "dynamodb", "actions": ["*"]},
    {"service": "s3", "actions": ["s3:GetObject", "s3:PutObject"]}
  ],
  "quotas": {
    "maxLambdaFunctions": 100,
    "maxDynamoDBTables": 50,
    "maxCostPerMonth": 5000
  }
}
```

**Data Team:**
```json
{
  "name": "data-team",
  "description": "Data engineering and analytics",
  "permissions": [
    {"service": "glue", "actions": ["*"]},
    {"service": "athena", "actions": ["*"]},
    {"service": "emr", "actions": ["*"]},
    {"service": "s3", "actions": ["*"]}
  ],
  "quotas": {
    "maxS3Buckets": 20,
    "maxCostPerMonth": 8000
  }
}
```

### Pattern 2: Environment-Based Teams

**Development Team:**
```json
{
  "name": "dev-team",
  "organization": "acme-corp-dev",
  "permissions": [
    {"service": "*", "actions": ["*"]}  // Full access in dev
  ],
  "quotas": {
    "maxCostPerMonth": 1000
  }
}
```

**Production Team:**
```json
{
  "name": "prod-team",
  "organization": "acme-corp-prod",
  "permissions": [
    {"service": "lambda", "actions": ["lambda:GetFunction", "lambda:InvokeFunction"]},
    {"service": "cloudwatch", "actions": ["logs:*", "cloudwatch:*"]},
    {"service": "dynamodb", "actions": ["dynamodb:Query", "dynamodb:Scan"]}
  ],
  "quotas": {
    "maxCostPerMonth": 20000
  }
}
```

### Pattern 3: Customer/Project Teams

**Customer Alpha Team:**
```json
{
  "name": "customer-alpha-team",
  "organization": "saas-platform",
  "tags": [
    {"key": "Customer", "value": "alpha-corp"},
    {"key": "Tier", "value": "enterprise"}
  ],
  "quotas": {
    "maxLambdaFunctions": 200,
    "maxDynamoDBTables": 100,
    "maxCostPerMonth": 15000
  }
}
```

## Configuration Examples

### Example 1: Basic Team

```json
{
  "id": "team_abc123",
  "name": "backend-team",
  "organization": "org_xyz789",
  "synthesizer": "synth_production",
  "description": "Backend services development team",
  "tags": [
    {"key": "Team", "value": "backend-team"},
    {"key": "Department", "value": "Engineering"}
  ]
}
```

### Example 2: Team with Permissions

```json
{
  "id": "team_def456",
  "name": "sre-team",
  "organization": "org_xyz789",
  "synthesizer": "synth_production",
  "permissions": [
    {
      "service": "cloudwatch",
      "actions": ["cloudwatch:*", "logs:*"],
      "resources": ["*"]
    },
    {
      "service": "lambda",
      "actions": ["lambda:GetFunction", "lambda:ListFunctions", "lambda:UpdateFunctionConfiguration"],
      "resources": ["arn:aws:lambda:*:*:function:acme-corp-*"]
    },
    {
      "service": "ec2",
      "actions": ["ec2:DescribeInstances", "ec2:DescribeSecurityGroups"],
      "resources": ["*"]
    }
  ]
}
```

### Example 3: Team with Quotas

```json
{
  "id": "team_ghi789",
  "name": "startup-team",
  "organization": "org_xyz789",
  "synthesizer": "synth_shared",
  "quotas": {
    "maxLambdaFunctions": 25,
    "maxDynamoDBTables": 10,
    "maxS3Buckets": 5,
    "maxCostPerMonth": 500
  },
  "tags": [
    {"key": "Team", "value": "startup-team"},
    {"key": "Budget", "value": "limited"}
  ]
}
```

## Best Practices

1. **Team Naming**
   - Use descriptive names: `platform-team` not `team1`
   - Include function: `backend-api-team`, `frontend-web-team`
   - Keep names under 30 characters

2. **Permission Design**
   - Start with least privilege
   - Grant permissions by service, not wildcard
   - Use resource ARN patterns to scope access
   - Review permissions quarterly

3. **Resource Quotas**
   - Set reasonable limits based on team needs
   - Monitor quota usage proactively
   - Alert at 80% of quota
   - Review quotas quarterly

4. **Cost Management**
   - Set cost quotas per team
   - Alert at 80% and 100% of budget
   - Review monthly cost reports
   - Chargeback costs to team budgets

5. **Tagging**
   - Always tag with Team name
   - Include CostCenter for billing
   - Add Manager for accountability
   - Use consistent tag keys

## Next Steps

- [Contributor Management →](/workflow/contributors.md)
- [Creating Releases →](/workflow/release.md)
- [Organization Configuration →](/workflow/organization.md)
- [Synthesizer Setup →](/workflow/synthesizer.md)
