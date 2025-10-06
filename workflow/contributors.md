# Contributors

## Overview

A **Contributor** represents an individual person (developer, operator, admin) who has access to deploy and manage infrastructure within a Team. Contributors are the actual users who trigger deployments, manage releases, and interact with the deployed resources.

## What is a Contributor?

### Conceptual Definition

A Contributor establishes:

- **Individual Identity**: Unique user identity with email/authentication
- **Role-Based Access**: Specific permissions based on role (admin, developer, viewer)
- **Audit Trail**: All actions tracked to individual contributor
- **Notification Recipient**: Receives deployment and alert notifications

### Configuration Structure

```typescript
interface Contributor {
  // Identification
  id: string;                    // Unique contributor ID
  name: string;                  // Display name
  email: string;                 // Email address (used for notifications)

  // Parent relationships
  team: string;                  // Parent team ID
  organization: string;          // Parent organization ID
  synthesizer: string;           // Parent synthesizer ID

  // Access control
  role: ContributorRole;         // Access level

  // Authentication
  cognitoUserId?: string;        // Cognito user ID (if using Cognito)
  iamUserArn?: string;           // IAM user ARN (if using IAM users)

  // Status
  status: 'active' | 'inactive' | 'suspended';
  lastLogin?: string;

  // Settings
  createdAt: string;
  updatedAt: string;
}

type ContributorRole = 'admin' | 'developer' | 'viewer';

interface RolePermissions {
  admin: string[];               // Full access to team resources
  developer: string[];           // Deploy and manage releases
  viewer: string[];              // Read-only access
}
```

## How Contributor Inputs Are Used

### 1. Email → Notifications & Authentication

**Input:**
```json
{
  "email": "alice@acme-corp.com"
}
```

**Used for SNS notifications:**
```yaml
DeploymentTopic:
  Type: AWS::SNS::Topic
  Properties:
    TopicName: acme-corp-platform-team-deployments
    Subscription:
      - Protocol: email
        Endpoint: alice@acme-corp.com  # Contributor email
```

**Used in CloudWatch alarms:**
```yaml
HighErrorRateAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmActions:
      - !Ref DeploymentTopic  # Sends to alice@acme-corp.com
    AlarmDescription: High error rate detected in Lambda functions
```

**Used in Cognito (if applicable):**
```yaml
CognitoUser:
  Type: AWS::Cognito::UserPoolUser
  Properties:
    UserPoolId: !Ref UserPool
    Username: alice@acme-corp.com
    UserAttributes:
      - Name: email
        Value: alice@acme-corp.com
      - Name: email_verified
        Value: 'true'
```

### 2. Role → IAM Permissions

**Input:**
```json
{
  "role": "developer"
}
```

**Permission mapping:**

**Admin Role:**
```json
{
  "permissions": [
    "cloudformation:*",
    "codepipeline:*",
    "codebuild:*",
    "iam:PassRole",
    "s3:*",
    "lambda:*",
    "apigateway:*",
    "dynamodb:*",
    "cognito-idp:*",
    "ses:*",
    "route53:*",
    "logs:*",
    "cloudwatch:*"
  ]
}
```

**Developer Role:**
```json
{
  "permissions": [
    "cloudformation:DescribeStacks",
    "cloudformation:ListStacks",
    "codepipeline:StartPipelineExecution",
    "codepipeline:GetPipelineState",
    "codebuild:StartBuild",
    "codebuild:BatchGetBuilds",
    "s3:GetObject",
    "s3:ListBucket",
    "lambda:GetFunction",
    "lambda:InvokeFunction",
    "apigateway:GET",
    "dynamodb:Query",
    "dynamodb:Scan",
    "dynamodb:GetItem",
    "logs:FilterLogEvents",
    "logs:GetLogEvents",
    "cloudwatch:GetMetricData"
  ]
}
```

**Viewer Role:**
```json
{
  "permissions": [
    "cloudformation:DescribeStacks",
    "cloudformation:ListStacks",
    "cloudformation:GetTemplate",
    "codepipeline:GetPipelineState",
    "codebuild:BatchGetBuilds",
    "s3:GetObject",
    "lambda:GetFunction",
    "apigateway:GET",
    "dynamodb:DescribeTable",
    "logs:FilterLogEvents",
    "logs:GetLogEvents",
    "cloudwatch:GetMetricData",
    "cloudwatch:ListDashboards"
  ]
}
```

**IAM policy generation:**
```yaml
AliceAdminRole:
  Type: AWS::IAM::Role
  Properties:
    RoleName: acme-corp-platform-team-alice-admin
    AssumeRolePolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Principal:
            AWS: !Sub arn:aws:iam::${AWS::AccountId}:user/alice@acme-corp.com
          Action: sts:AssumeRole
    Policies:
      - PolicyName: AdminAccess
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Action:
                - cloudformation:*
                - codepipeline:*
                # ... all admin permissions
              Resource: '*'
              Condition:
                StringEquals:
                  aws:ResourceTag/Team: platform-team
    Tags:
      - Key: Contributor
        Value: alice@acme-corp.com
      - Key: Role
        Value: admin
```

### 3. Name → Audit Logging

**Input:**
```json
{
  "name": "Alice Johnson",
  "email": "alice@acme-corp.com"
}
```

**Used in CloudTrail events:**
```json
{
  "eventName": "StartPipelineExecution",
  "eventTime": "2024-01-15T10:30:00Z",
  "userIdentity": {
    "type": "IAMUser",
    "principalId": "AIDAI...",
    "arn": "arn:aws:iam::123456789012:user/alice@acme-corp.com",
    "accountId": "123456789012",
    "userName": "alice@acme-corp.com"
  },
  "requestParameters": {
    "pipelineName": "acme-corp-platform-webapp-pipeline"
  },
  "resources": [{
    "ARN": "arn:aws:codepipeline:us-west-2:123456789012:acme-corp-platform-webapp-pipeline",
    "type": "AWS::CodePipeline::Pipeline"
  }]
}
```

**Stored in deployment metadata:**
```json
{
  "deploymentId": "deploy_abc123",
  "timestamp": "2024-01-15T10:30:00Z",
  "contributor": {
    "id": "contrib_xyz789",
    "name": "Alice Johnson",
    "email": "alice@acme-corp.com",
    "role": "admin"
  },
  "action": "StartPipelineExecution",
  "resource": "acme-corp-platform-webapp-pipeline",
  "status": "SUCCESS"
}
```

### 4. Cognito User ID → Portal Authentication

**Input:**
```json
{
  "cognitoUserId": "sub_abc123def456"
}
```

**Used in portal authentication:**
```typescript
// Portal backend validates contributor
const token = await getAuthToken(request);
const decoded = verifyJWT(token);

// Check contributor exists and is active
const contributor = await getContributor({
  cognitoUserId: decoded.sub  // "sub_abc123def456"
});

if (contributor.status !== 'active') {
  throw new UnauthorizedError('Contributor is not active');
}

// Check contributor has permission for action
if (action === 'deploy' && contributor.role === 'viewer') {
  throw new ForbiddenError('Viewers cannot trigger deployments');
}
```

**Custom Cognito attributes:**
```json
{
  "sub": "sub_abc123def456",
  "email": "alice@acme-corp.com",
  "custom:contributor_id": "contrib_xyz789",
  "custom:team_id": "team_platform",
  "custom:role": "admin",
  "custom:organization": "acme-corp"
}
```

## Contributor Workflow

### 1. Contributor Triggers Deployment

```
Alice (Contributor)
    ↓
Portal UI: Click "Launch Release"
    ↓
API validates Alice's role (developer)
    ↓
EventBridge event triggered
    {
      "contributor_id": "contrib_xyz789",
      "contributor_email": "alice@acme-corp.com",
      "release_id": "rel_webapp_v1",
      "action": "deploy"
    }
    ↓
CodePipeline starts
    Environment Variables:
    - CONTRIBUTOR_EMAIL=alice@acme-corp.com
    - CONTRIBUTOR_NAME=Alice Johnson
    ↓
CloudFormation deployment
    Tags added:
    - DeployedBy: alice@acme-corp.com
    - DeploymentTime: 2024-01-15T10:30:00Z
    ↓
SNS notification sent to alice@acme-corp.com
    "Deployment started for webapp-v1"
```

### 2. Deployment Tracking

**Pipeline variables include contributor info:**
```bash
# spaz-infra CodePipeline
subscriber_id="sub_abc123"
release_id="rel_xyz789"
contributor_id="contrib_alice123"         # Added
contributor_email="alice@acme-corp.com"   # Added
```

**CloudFormation stack tags:**
```yaml
DeploymentStack:
  Type: AWS::CloudFormation::Stack
  Properties:
    Tags:
      - Key: DeployedBy
        Value: alice@acme-corp.com
      - Key: DeployedAt
        Value: '2024-01-15T10:30:00Z'
      - Key: DeploymentSource
        Value: Fastish Portal
```

**DynamoDB deployment record:**
```json
{
  "deploymentId": "deploy_20240115_103000",
  "releaseId": "rel_webapp_v1",
  "contributor": {
    "id": "contrib_xyz789",
    "name": "Alice Johnson",
    "email": "alice@acme-corp.com",
    "role": "admin"
  },
  "status": "IN_PROGRESS",
  "startTime": "2024-01-15T10:30:00Z",
  "stackName": "acme-corp-production-webapp"
}
```

## Role-Based Access Examples

### Admin Contributor

**Permissions:**
- Deploy any release
- Modify team settings
- Add/remove contributors
- Delete deployments
- Access all CloudWatch logs
- Modify IAM roles

**Example:**
```json
{
  "name": "Alice Johnson",
  "email": "alice@acme-corp.com",
  "role": "admin",
  "team": "platform-team"
}
```

**Can do:**
```bash
# Deploy production release
POST /api/release/webapp-prod/launch

# Add new contributor
POST /api/team/platform-team/contributors

# Delete failed deployment
DELETE /api/deployment/deploy_failed_001

# Update team quotas
PUT /api/team/platform-team/quotas
```

### Developer Contributor

**Permissions:**
- Deploy releases
- View deployment status
- Access CloudWatch logs for their deployments
- Cannot modify team settings
- Cannot manage other contributors

**Example:**
```json
{
  "name": "Bob Smith",
  "email": "bob@acme-corp.com",
  "role": "developer",
  "team": "platform-team"
}
```

**Can do:**
```bash
# Deploy releases
POST /api/release/webapp-dev/launch

# View deployment status
GET /api/deployment/deploy_abc123/status

# View logs
GET /api/logs/webapp-dev?contributor=bob@acme-corp.com
```

**Cannot do:**
```bash
# ❌ Add contributors (admin only)
POST /api/team/platform-team/contributors
# Response: 403 Forbidden

# ❌ Modify team settings (admin only)
PUT /api/team/platform-team
# Response: 403 Forbidden
```

### Viewer Contributor

**Permissions:**
- View deployment status
- View CloudWatch dashboards
- View stack outputs
- Cannot deploy
- Cannot modify anything

**Example:**
```json
{
  "name": "Charlie Davis",
  "email": "charlie@acme-corp.com",
  "role": "viewer",
  "team": "platform-team"
}
```

**Can do:**
```bash
# View deployment status
GET /api/deployment/deploy_abc123/status

# View stack outputs
GET /api/stack/acme-corp-prod-webapp/outputs

# View dashboards
GET /api/dashboards/platform-team
```

**Cannot do:**
```bash
# ❌ Deploy releases (developer/admin only)
POST /api/release/webapp-dev/launch
# Response: 403 Forbidden

# ❌ View logs (developer/admin only)
GET /api/logs/webapp-dev
# Response: 403 Forbidden
```

## Configuration Examples

### Example 1: Admin Contributor

```json
{
  "id": "contrib_admin_001",
  "name": "Alice Johnson",
  "email": "alice@acme-corp.com",
  "role": "admin",
  "team": "team_platform",
  "organization": "org_acme",
  "synthesizer": "synth_prod",
  "status": "active",
  "cognitoUserId": "sub_abc123",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### Example 2: Developer Contributor

```json
{
  "id": "contrib_dev_001",
  "name": "Bob Smith",
  "email": "bob@acme-corp.com",
  "role": "developer",
  "team": "team_platform",
  "organization": "org_acme",
  "synthesizer": "synth_prod",
  "status": "active",
  "cognitoUserId": "sub_def456",
  "lastLogin": "2024-01-15T10:00:00Z",
  "createdAt": "2024-01-05T00:00:00Z"
}
```

### Example 3: Viewer Contributor

```json
{
  "id": "contrib_viewer_001",
  "name": "Charlie Davis",
  "email": "charlie@acme-corp.com",
  "role": "viewer",
  "team": "team_product",
  "organization": "org_acme",
  "synthesizer": "synth_prod",
  "status": "active",
  "cognitoUserId": "sub_ghi789",
  "createdAt": "2024-01-10T00:00:00Z"
}
```

## Best Practices

1. **Role Assignment**
   - Start with viewer role, upgrade as needed
   - Limit admin role to 2-3 people per team
   - Regular developers should have developer role
   - External stakeholders get viewer role only

2. **Email Addresses**
   - Use corporate email addresses
   - Enable email notifications for deployments
   - Keep email addresses up to date
   - Use distribution lists for critical alerts

3. **Access Reviews**
   - Review contributor access quarterly
   - Remove inactive contributors
   - Audit admin role assignments
   - Update roles based on job changes

4. **Security**
   - Require MFA for admin role
   - Rotate credentials regularly
   - Monitor for suspicious activity
   - Use temporary credentials when possible

5. **Audit Trail**
   - Enable CloudTrail logging
   - Track all deployment actions
   - Maintain audit logs for compliance
   - Review logs for security incidents

## Troubleshooting

### Permission Denied

**Error:** `User is not authorized to perform action`

**Checklist:**
1. Verify contributor status is `active`
2. Check role has required permissions
3. Ensure contributor is in correct team
4. Verify team has access to resource

### Email Notifications Not Received

**Error:** Deployment notifications not arriving

**Solutions:**
1. Verify email address is correct
2. Check spam folder
3. Verify SNS subscription is confirmed
4. Test with CloudWatch alarm

### Contributor Not Found

**Error:** `Contributor does not exist`

**Solutions:**
1. Verify contributor ID is correct
2. Check contributor hasn't been deleted
3. Ensure contributor is in correct organization/team
4. Verify Cognito user is linked

## Next Steps

- [Creating Releases →](/workflow/release.md)
- [Team Management →](/workflow/teams.md)
- [Organization Configuration →](/workflow/organization.md)
- [Deployment Monitoring →](/webapp/overview.md#monitoring--observability)
