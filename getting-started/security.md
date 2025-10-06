# Security Architecture

## Overview

The Fastish platform implements a multi-layered security model centered around three key mechanisms:

1. **Subscriber API Key** - Cross-account access control and authentication
2. **Synthesizer Verification** - Validates AWS environment before allowing deployments
3. **Release Verification** - Pre-deployment validation of infrastructure configuration

This document explains how each security layer works and how they combine to protect your AWS infrastructure.

## Subscriber API Key

### What is the API Key?

The **Subscriber API Key** is a unique, cryptographically-secure identifier generated when a user signs up. It serves as the **External ID** in AWS IAM cross-account role assumption, preventing the "confused deputy" problem.

**Key characteristics:**
- Generated once during signup
- Stored in Cognito user attribute: `custom:apikey`
- Used as External ID for all cross-account operations
- Never exposed in URLs or logs
- Can be rotated for security

### API Key Generation

**During user signup:**
```typescript
// Portal backend - User registration
import { randomUUID } from 'crypto';

async function createSubscriber(email: string) {
  // Generate cryptographically secure API key
  const apiKey = `sk_${randomUUID().replace(/-/g, '')}`;
  // Result: sk_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

  // Store in Cognito custom attribute
  await cognito.adminCreateUser({
    UserPoolId: PORTAL_USER_POOL_ID,
    Username: email,
    UserAttributes: [
      { Name: 'email', Value: email },
      { Name: 'custom:apikey', Value: apiKey },
      { Name: 'custom:role', Value: '' },  // Set later during synthesizer creation
      { Name: 'custom:subscription', Value: 'free' }
    ]
  });

  return { email, apiKey };
}
```

### API Key Flow Through the System

#### 1. Portal Authentication

**User logs in:**
```typescript
// Portal UI - Login
import { signIn } from 'aws-amplify/auth';

const { isSignedIn } = await signIn({
  username: 'alice@acme-corp.com',
  password: 'SecurePassword123!'
});

// Cognito returns JWT with custom attributes
const session = await fetchAuthSession();
const attributes = await fetchUserAttributes();

// API key available in attributes
const apiKey = attributes['custom:apikey'];
// "sk_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
```

#### 2. API Request Authentication

**Every API request includes API key:**
```typescript
// Portal backend API route
// app/v1/api/subscriber/summary/route.ts

export const GET = async () => {
  // 1. Validate JWT token
  const { session, attributes, valid } = await getToken();

  // 2. Check API key exists
  if (!session || !valid || !attributes["custom:apikey"]) {
    return new Response('Unauthorized', { status: 401 });
  }

  // 3. Call backend API with API key header
  return runWithAmplifyServerContext({
    nextServerContext: { cookies },
    operation: async (contextSpec) => {
      const response = await get(contextSpec, {
        apiName: API_NAME,
        path: `/subscriber/${session.userSub}/summary`,
        options: {
          headers: {
            "Content-Type": "application/json",
            "X-Api-Key": attributes["custom:apikey"],  // API key in header
          }
        }
      }).response;

      return new Response(JSON.stringify(await response.body.json()));
    }
  });
};
```

#### 3. Backend API Validation

**Backend validates API key:**
```typescript
// Backend API Gateway Lambda authorizer
export async function authorize(event: APIGatewayAuthorizerEvent) {
  const apiKey = event.headers['X-Api-Key'];

  if (!apiKey) {
    throw new Error('Unauthorized');
  }

  // Validate API key exists and is active
  const subscriber = await dynamodb.get({
    TableName: 'Subscribers',
    Key: { apiKey }
  }).promise();

  if (!subscriber.Item || subscriber.Item.status !== 'active') {
    throw new Error('Unauthorized');
  }

  // Return IAM policy allowing access
  return {
    principalId: subscriber.Item.id,
    policyDocument: {
      Version: '2012-10-17',
      Statement: [{
        Action: 'execute-api:Invoke',
        Effect: 'Allow',
        Resource: event.methodArn
      }]
    },
    context: {
      subscriberId: subscriber.Item.id,
      apiKey: apiKey,
      subscription: subscriber.Item.subscription
    }
  };
}
```

#### 4. Cross-Account Role Assumption (External ID)

**API key used as External ID:**
```typescript
// Backend - Synthesizer verification
import { STSClient, AssumeRoleCommand } from '@aws-sdk/client-sts';

async function validateSynthesizer(synthesizer: Synthesizer, apiKey: string) {
  const stsClient = new STSClient({ region: synthesizer.region });

  // Assume handshake role with API key as External ID
  const command = new AssumeRoleCommand({
    RoleArn: synthesizer.cdk.role.handshake,
    RoleSessionName: 'fastish-verification',
    ExternalId: apiKey,  // API KEY USED AS EXTERNAL ID
    DurationSeconds: 900  // 15 minutes
  });

  try {
    const credentials = await stsClient.send(command);
    return { success: true, credentials };
  } catch (error) {
    // Access denied - invalid API key or role configuration
    return { success: false, error: 'Access denied' };
  }
}
```

**Subscriber's IAM role trust policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::351619759866:root"
    },
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {
        "sts:ExternalId": "sk_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
      }
    }
  }]
}
```

**Security benefits:**
- **Prevents Confused Deputy**: Only requests with correct External ID can assume role
- **Unique Per Subscriber**: Each subscriber has unique API key
- **Audit Trail**: All role assumptions logged in CloudTrail with External ID
- **Revocable**: Changing API key immediately revokes all access

#### 5. CodePipeline Deployment

**API key passed to deployment pipeline:**
```bash
# spaz-infra CodePipeline environment variables
subscriber_id="sub_abc123"
release_id="rel_xyz789"
external_id="sk_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"  # API key

# Used in deploy stage
aws sts assume-role \
  --role-arn "arn:aws:iam::123456789012:role/fastish-deployment-role" \
  --role-session-name "fastish-deploy-rel_xyz789" \
  --external-id "$external_id"  # Must match subscriber's API key
```

### API Key Security Best Practices

**Protection:**
1. **Never log API keys** - Redact from logs and error messages
2. **HTTPS only** - All API communication over TLS
3. **Short-lived tokens** - STS credentials expire in 15-60 minutes
4. **Rotate on compromise** - If exposed, immediately rotate

**Storage:**
- Stored in Cognito (encrypted at rest)
- Never stored client-side in localStorage
- Transmitted only in secure HTTP headers
- Never in URL parameters or query strings

**Rotation:**
```typescript
// Rotate API key (emergency use)
async function rotateApiKey(subscriberId: string) {
  const newApiKey = `sk_${randomUUID().replace(/-/g, '')}`;

  // 1. Update Cognito attribute
  await cognito.adminUpdateUserAttributes({
    UserPoolId: PORTAL_USER_POOL_ID,
    Username: subscriberId,
    UserAttributes: [
      { Name: 'custom:apikey', Value: newApiKey }
    ]
  });

  // 2. Update all synthesizers with new External ID
  const synthesizers = await getSynthesizers(subscriberId);
  for (const synth of synthesizers) {
    await updateSynthesizerExternalId(synth.id, newApiKey);
  }

  // 3. Old API key immediately invalid
  return newApiKey;
}
```

## Synthesizer Verification

### What is Synthesizer Verification?

Before allowing any deployments, the system verifies that:
1. The synthesizer configuration is correct
2. All required AWS resources exist
3. IAM roles have correct permissions
4. The subscriber can access their AWS account

This prevents failed deployments and validates the setup.

### Verification Trigger

**User initiates verification:**
```typescript
// Portal UI - Synthesizer page
<Button onClick={() => verifySynthesizer(synthesizer.id)}>
  Verify Configuration
</Button>

// API call
POST /api/subscriber/synthesizer/{synthesizerId}/verify
```

### Verification Process

**Backend verification flow:**
```typescript
// API route: app/v1/api/subscriber/synthesizer/[synthesizer]/verify/route.ts

export const POST = async (req: Request, { params }) => {
  // 1. Authenticate user and get API key
  const { session, attributes, valid } = await getToken();

  if (!session || !valid || !attributes["custom:apikey"]) {
    return new Response('Unauthorized', { status: 401 });
  }

  const apiKey = attributes["custom:apikey"];
  const synthesizerId = params.synthesizer;

  // 2. Get synthesizer configuration
  const synthesizer = await getSynthesizer(synthesizerId);

  // 3. Run verification checks
  const results = await verifySynthesizer(synthesizer, apiKey);

  return new Response(JSON.stringify(results), { status: 200 });
};
```

### Verification Checks

**Check 1: Handshake Role Access**

```typescript
import { STSClient, AssumeRoleCommand } from '@aws-sdk/client-sts';

async function checkHandshakeRole(synthesizer: Synthesizer, apiKey: string) {
  const stsClient = new STSClient({ region: synthesizer.region });

  try {
    // Attempt to assume handshake role
    const command = new AssumeRoleCommand({
      RoleArn: synthesizer.cdk.role.handshake,
      RoleSessionName: 'fastish-verify-handshake',
      ExternalId: apiKey,  // Must match subscriber's API key
      DurationSeconds: 900
    });

    const result = await stsClient.send(command);

    return {
      check: 'Handshake Role',
      status: 'passed',
      message: 'Successfully assumed handshake role',
      credentials: result.Credentials
    };
  } catch (error) {
    return {
      check: 'Handshake Role',
      status: 'failed',
      message: error.message,
      details: 'Verify External ID matches API key and trust policy is correct'
    };
  }
}
```

**Check 2: S3 Assets Bucket**

```typescript
import { S3Client, HeadBucketCommand, GetBucketLocationCommand } from '@aws-sdk/client-s3';

async function checkAssetsBucket(synthesizer: Synthesizer, credentials: any) {
  const s3Client = new S3Client({
    region: synthesizer.region,
    credentials: {
      accessKeyId: credentials.AccessKeyId,
      secretAccessKey: credentials.SecretAccessKey,
      sessionToken: credentials.SessionToken
    }
  });

  try {
    // Check bucket exists
    await s3Client.send(new HeadBucketCommand({
      Bucket: synthesizer.cdk.storage.assetsBucket
    }));

    // Verify bucket in correct region
    const location = await s3Client.send(new GetBucketLocationCommand({
      Bucket: synthesizer.cdk.storage.assetsBucket
    }));

    const bucketRegion = location.LocationConstraint || 'us-east-1';

    if (bucketRegion !== synthesizer.region) {
      return {
        check: 'S3 Assets Bucket',
        status: 'failed',
        message: `Bucket is in ${bucketRegion}, expected ${synthesizer.region}`
      };
    }

    return {
      check: 'S3 Assets Bucket',
      status: 'passed',
      message: `Bucket exists and accessible in ${synthesizer.region}`
    };
  } catch (error) {
    return {
      check: 'S3 Assets Bucket',
      status: 'failed',
      message: error.message,
      details: 'Verify bucket name and handshake role has s3:ListBucket permission'
    };
  }
}
```

**Check 3: ECR Repository**

```typescript
import { ECRClient, DescribeRepositoriesCommand } from '@aws-sdk/client-ecr';

async function checkECRRepository(synthesizer: Synthesizer, credentials: any) {
  const ecrClient = new ECRClient({
    region: synthesizer.region,
    credentials: {
      accessKeyId: credentials.AccessKeyId,
      secretAccessKey: credentials.SecretAccessKey,
      sessionToken: credentials.SessionToken
    }
  });

  try {
    const result = await ecrClient.send(new DescribeRepositoriesCommand({
      repositoryNames: [synthesizer.cdk.storage.imagesRepo]
    }));

    return {
      check: 'ECR Repository',
      status: 'passed',
      message: `Repository ${synthesizer.cdk.storage.imagesRepo} exists`,
      details: {
        repositoryArn: result.repositories[0].repositoryArn,
        createdAt: result.repositories[0].createdAt
      }
    };
  } catch (error) {
    return {
      check: 'ECR Repository',
      status: 'failed',
      message: error.message,
      details: 'Verify repository name and handshake role has ecr:DescribeRepositories permission'
    };
  }
}
```

**Check 4: KMS Key**

```typescript
import { KMSClient, DescribeKeyCommand } from '@aws-sdk/client-kms';

async function checkKMSKey(synthesizer: Synthesizer, credentials: any) {
  const kmsClient = new KMSClient({
    region: synthesizer.region,
    credentials: {
      accessKeyId: credentials.AccessKeyId,
      secretAccessKey: credentials.SecretAccessKey,
      sessionToken: credentials.SessionToken
    }
  });

  try {
    const result = await kmsClient.send(new DescribeKeyCommand({
      KeyId: synthesizer.cdk.kms.alias  // e.g., "alias/fastish-assets"
    }));

    if (!result.KeyMetadata.Enabled) {
      return {
        check: 'KMS Key',
        status: 'failed',
        message: 'KMS key exists but is disabled'
      };
    }

    return {
      check: 'KMS Key',
      status: 'passed',
      message: 'KMS key exists and enabled',
      details: {
        keyId: result.KeyMetadata.KeyId,
        keyState: result.KeyMetadata.KeyState
      }
    };
  } catch (error) {
    return {
      check: 'KMS Key',
      status: 'failed',
      message: error.message
    };
  }
}
```

**Check 5: Deployment Role**

```typescript
import { IAMClient, GetRoleCommand } from '@aws-sdk/client-iam';

async function checkDeploymentRole(synthesizer: Synthesizer, credentials: any) {
  const iamClient = new IAMClient({
    region: synthesizer.region,
    credentials: {
      accessKeyId: credentials.AccessKeyId,
      secretAccessKey: credentials.SecretAccessKey,
      sessionToken: credentials.SessionToken
    }
  });

  try {
    const roleName = synthesizer.cdk.role.deploy.split('/').pop();
    const result = await iamClient.send(new GetRoleCommand({
      RoleName: roleName
    }));

    // Verify trust policy includes External ID
    const trustPolicy = JSON.parse(decodeURIComponent(result.Role.AssumeRolePolicyDocument));
    const hasExternalId = trustPolicy.Statement.some(stmt =>
      stmt.Condition?.StringEquals?.['sts:ExternalId']
    );

    if (!hasExternalId) {
      return {
        check: 'Deployment Role',
        status: 'warning',
        message: 'Role exists but External ID condition not found in trust policy'
      };
    }

    return {
      check: 'Deployment Role',
      status: 'passed',
      message: 'Deployment role exists with correct trust policy'
    };
  } catch (error) {
    return {
      check: 'Deployment Role',
      status: 'failed',
      message: error.message
    };
  }
}
```

**Check 6: SSM Parameter**

```typescript
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';

async function checkSSMParameter(synthesizer: Synthesizer, credentials: any) {
  const ssmClient = new SSMClient({
    region: synthesizer.region,
    credentials: {
      accessKeyId: credentials.AccessKeyId,
      secretAccessKey: credentials.SecretAccessKey,
      sessionToken: credentials.SessionToken
    }
  });

  try {
    const result = await ssmClient.send(new GetParameterCommand({
      Name: synthesizer.cdk.ssm.parameter  // e.g., "/cdk-bootstrap/hnb659fds/version"
    }));

    const version = parseInt(result.Parameter.Value);

    if (version < 21) {
      return {
        check: 'CDK Bootstrap Version',
        status: 'warning',
        message: `Bootstrap version ${version} is outdated. Recommended: 21+`
      };
    }

    return {
      check: 'CDK Bootstrap Version',
      status: 'passed',
      message: `Bootstrap version ${version} is current`
    };
  } catch (error) {
    return {
      check: 'CDK Bootstrap Version',
      status: 'failed',
      message: 'CDK bootstrap parameter not found. Run cdk bootstrap first.'
    };
  }
}
```

### Verification Response

**Successful verification:**
```json
{
  "synthesizerId": "synth_prod_001",
  "valid": true,
  "checks": [
    {
      "check": "Handshake Role",
      "status": "passed",
      "message": "Successfully assumed handshake role"
    },
    {
      "check": "S3 Assets Bucket",
      "status": "passed",
      "message": "Bucket exists and accessible in us-west-2"
    },
    {
      "check": "ECR Repository",
      "status": "passed",
      "message": "Repository fastish-container-assets exists"
    },
    {
      "check": "KMS Key",
      "status": "passed",
      "message": "KMS key exists and enabled"
    },
    {
      "check": "Deployment Role",
      "status": "passed",
      "message": "Deployment role exists with correct trust policy"
    },
    {
      "check": "CDK Bootstrap Version",
      "status": "passed",
      "message": "Bootstrap version 21 is current"
    }
  ],
  "verifiedAt": "2024-01-15T10:30:00Z"
}
```

**Failed verification:**
```json
{
  "synthesizerId": "synth_prod_001",
  "valid": false,
  "checks": [
    {
      "check": "Handshake Role",
      "status": "failed",
      "message": "AccessDenied: User is not authorized to perform: sts:AssumeRole",
      "details": "Verify External ID matches API key and trust policy is correct"
    },
    {
      "check": "S3 Assets Bucket",
      "status": "skipped",
      "message": "Skipped due to handshake role failure"
    }
    // ... other checks skipped
  ],
  "verifiedAt": "2024-01-15T10:30:00Z"
}
```

## Release Verification

### What is Release Verification?

Before deploying infrastructure, the system validates:
1. Release configuration is complete and valid
2. Required resources (domains, DNS zones) exist
3. Synthesizer is verified and accessible
4. Team has sufficient quotas
5. No conflicting deployments

This prevents deployment failures and validates prerequisites.

### Verification Trigger

**User initiates verification:**
```typescript
// Portal UI - Release page
<Button onClick={() => verifyRelease(release.id)}>
  Verify Before Launch
</Button>

// API call
POST /api/subscriber/release/webapp/{releaseId}/verify
```

### Release Verification Process

**Backend verification:**
```typescript
// API route: app/v1/api/subscriber/release/webapp/[release]/verify/route.ts

export const POST = async (req: Request, { params }) => {
  // 1. Authenticate and get API key
  const { session, attributes, valid } = await getToken();

  if (!session || !valid || !attributes["custom:apikey"]) {
    return new Response('Unauthorized', { status: 401 });
  }

  const apiKey = attributes["custom:apikey"];
  const releaseId = params.release;

  // 2. Get release configuration
  const release = await getRelease(releaseId);

  // 3. Run verification checks
  const results = await verifyRelease(release, apiKey);

  return new Response(JSON.stringify(results), { status: 200 });
};
```

### Release Verification Checks

**Check 1: Synthesizer Status**

```typescript
async function checkSynthesizerStatus(release: Release) {
  const synthesizer = await getSynthesizer(release.synthesizer);

  if (!synthesizer.verified) {
    return {
      check: 'Synthesizer Verification',
      status: 'failed',
      message: 'Synthesizer has not been verified',
      action: 'Verify synthesizer before deploying release'
    };
  }

  const verifiedAge = Date.now() - new Date(synthesizer.verifiedAt).getTime();
  const maxAge = 7 * 24 * 60 * 60 * 1000; // 7 days

  if (verifiedAge > maxAge) {
    return {
      check: 'Synthesizer Verification',
      status: 'warning',
      message: 'Synthesizer verification is older than 7 days',
      action: 'Re-verify synthesizer to ensure configuration is current'
    };
  }

  return {
    check: 'Synthesizer Verification',
    status: 'passed',
    message: `Synthesizer verified ${Math.floor(verifiedAge / (24*60*60*1000))} days ago`
  };
}
```

**Check 2: Domain Configuration (WebApp only)**

```typescript
import { Route53Client, GetHostedZoneCommand, ListResourceRecordSetsCommand } from '@aws-sdk/client-route-53';

async function checkDomainConfiguration(release: WebAppRelease, credentials: any) {
  const route53 = new Route53Client({
    region: 'us-east-1',  // Route53 is global
    credentials
  });

  try {
    // Verify hosted zone exists
    const zone = await route53.send(new GetHostedZoneCommand({
      Id: release.webapp.ses.hostedZoneId
    }));

    // Verify domain matches
    const zoneDomain = zone.HostedZone.Name.replace(/\.$/, '');
    if (zoneDomain !== release.webapp.domain) {
      return {
        check: 'Domain Configuration',
        status: 'failed',
        message: `Hosted zone is for ${zoneDomain}, but release domain is ${release.webapp.domain}`
      };
    }

    return {
      check: 'Domain Configuration',
      status: 'passed',
      message: `Hosted zone ${release.webapp.ses.hostedZoneId} configured for ${release.webapp.domain}`
    };
  } catch (error) {
    return {
      check: 'Domain Configuration',
      status: 'failed',
      message: `Hosted zone ${release.webapp.ses.hostedZoneId} not found or inaccessible`,
      action: 'Verify hosted zone ID and ensure it exists in the target account'
    };
  }
}
```

**Check 3: SES Email Verification**

```typescript
import { SESClient, GetIdentityVerificationAttributesCommand } from '@aws-sdk/client-ses';

async function checkSESEmail(release: WebAppRelease, credentials: any) {
  const sesClient = new SESClient({
    region: release.synthesizer.region,
    credentials
  });

  try {
    const result = await sesClient.send(new GetIdentityVerificationAttributesCommand({
      Identities: [release.webapp.ses.email]
    }));

    const status = result.VerificationAttributes[release.webapp.ses.email]?.VerificationStatus;

    if (status === 'Success') {
      return {
        check: 'SES Email Verification',
        status: 'passed',
        message: `Email ${release.webapp.ses.email} is verified`
      };
    }

    if (status === 'Pending') {
      return {
        check: 'SES Email Verification',
        status: 'warning',
        message: `Email ${release.webapp.ses.email} verification pending`,
        action: 'Check inbox and click verification link'
      };
    }

    return {
      check: 'SES Email Verification',
      status: 'failed',
      message: `Email ${release.webapp.ses.email} is not verified`,
      action: 'Add and verify email in SES console'
    };
  } catch (error) {
    return {
      check: 'SES Email Verification',
      status: 'failed',
      message: error.message
    };
  }
}
```

**Check 4: Team Resource Quotas**

```typescript
async function checkTeamQuotas(release: Release) {
  const team = await getTeam(release.team);

  if (!team.quotas) {
    return {
      check: 'Team Resource Quotas',
      status: 'passed',
      message: 'No quotas configured'
    };
  }

  // Get current resource counts
  const currentResources = await getTeamResources(team.id);

  const violations = [];

  if (team.quotas.maxLambdaFunctions) {
    const futureCount = currentResources.lambdaFunctions + 5; // Estimate for new deployment
    if (futureCount > team.quotas.maxLambdaFunctions) {
      violations.push(`Lambda functions: ${futureCount}/${team.quotas.maxLambdaFunctions}`);
    }
  }

  if (team.quotas.maxDynamoDBTables) {
    const futureCount = currentResources.dynamodbTables + 1;
    if (futureCount > team.quotas.maxDynamoDBTables) {
      violations.push(`DynamoDB tables: ${futureCount}/${team.quotas.maxDynamoDBTables}`);
    }
  }

  if (violations.length > 0) {
    return {
      check: 'Team Resource Quotas',
      status: 'failed',
      message: 'Deployment would exceed team quotas',
      details: violations,
      action: 'Request quota increase or clean up unused resources'
    };
  }

  return {
    check: 'Team Resource Quotas',
    status: 'passed',
    message: 'Deployment within team quotas'
  };
}
```

**Check 5: Stack Name Conflicts**

```typescript
import { CloudFormationClient, DescribeStacksCommand } from '@aws-sdk/client-cloudformation';

async function checkStackConflicts(release: Release, credentials: any) {
  const cfnClient = new CloudFormationClient({
    region: release.synthesizer.region,
    credentials
  });

  const stackName = `${release.organization}-${release.name}-webapp`;

  try {
    const result = await cfnClient.send(new DescribeStacksCommand({
      StackName: stackName
    }));

    const stack = result.Stacks[0];

    if (stack.StackStatus.includes('DELETE')) {
      return {
        check: 'Stack Name Conflict',
        status: 'warning',
        message: `Stack ${stackName} is being deleted`,
        action: 'Wait for deletion to complete before deploying'
      };
    }

    if (stack.StackStatus.includes('FAILED')) {
      return {
        check: 'Stack Name Conflict',
        status: 'warning',
        message: `Stack ${stackName} exists in FAILED state`,
        action: 'Delete failed stack or choose different release name'
      };
    }

    return {
      check: 'Stack Name Conflict',
      status: 'warning',
      message: `Stack ${stackName} already exists`,
      action: 'This deployment will update the existing stack'
    };
  } catch (error) {
    if (error.name === 'ValidationError') {
      // Stack doesn't exist - good!
      return {
        check: 'Stack Name Conflict',
        status: 'passed',
        message: `Stack name ${stackName} available`
      };
    }

    return {
      check: 'Stack Name Conflict',
      status: 'failed',
      message: error.message
    };
  }
}
```

**Check 6: Service Quotas**

```typescript
import { ServiceQuotasClient, GetServiceQuotaCommand } from '@aws-sdk/client-service-quotas';

async function checkServiceQuotas(release: Release, credentials: any) {
  const quotasClient = new ServiceQuotasClient({
    region: release.synthesizer.region,
    credentials
  });

  const checks = [];

  // Check Lambda concurrent executions
  try {
    const lambdaQuota = await quotasClient.send(new GetServiceQuotaCommand({
      ServiceCode: 'lambda',
      QuotaCode: 'L-B99A9384'  // Concurrent executions
    }));

    if (lambdaQuota.Quota.Value < 1000) {
      checks.push({
        service: 'Lambda',
        quota: 'Concurrent executions',
        current: lambdaQuota.Quota.Value,
        status: 'warning',
        message: 'Lambda concurrent execution limit is default (1000). Consider requesting increase.'
      });
    }
  } catch (error) {
    // Quota check failed, skip
  }

  // Check VPC limits
  try {
    const vpcQuota = await quotasClient.send(new GetServiceQuotaCommand({
      ServiceCode: 'vpc',
      QuotaCode: 'L-F678F1CE'  // VPCs per region
    }));

    const currentVPCs = await countVPCs(credentials, release.synthesizer.region);

    if (currentVPCs >= vpcQuota.Quota.Value - 1) {
      checks.push({
        service: 'VPC',
        quota: 'VPCs per region',
        current: `${currentVPCs}/${vpcQuota.Quota.Value}`,
        status: 'failed',
        message: 'At VPC limit. Delete unused VPCs or request quota increase.'
      });
    }
  } catch (error) {
    // Quota check failed, skip
  }

  const hasFailures = checks.some(c => c.status === 'failed');
  const hasWarnings = checks.some(c => c.status === 'warning');

  return {
    check: 'AWS Service Quotas',
    status: hasFailures ? 'failed' : hasWarnings ? 'warning' : 'passed',
    message: hasFailures ? 'Service quota limits exceeded' : hasWarnings ? 'Some quotas near limit' : 'Service quotas OK',
    details: checks
  };
}
```

### Release Verification Response

**Successful verification:**
```json
{
  "releaseId": "rel_webapp_prod_001",
  "valid": true,
  "checks": [
    {
      "check": "Synthesizer Verification",
      "status": "passed",
      "message": "Synthesizer verified 2 days ago"
    },
    {
      "check": "Domain Configuration",
      "status": "passed",
      "message": "Hosted zone Z1234567890ABC configured for acme.com"
    },
    {
      "check": "SES Email Verification",
      "status": "passed",
      "message": "Email noreply@acme.com is verified"
    },
    {
      "check": "Team Resource Quotas",
      "status": "passed",
      "message": "Deployment within team quotas"
    },
    {
      "check": "Stack Name Conflict",
      "status": "passed",
      "message": "Stack name acme-corp-production-webapp available"
    },
    {
      "check": "AWS Service Quotas",
      "status": "passed",
      "message": "Service quotas OK"
    }
  ],
  "verifiedAt": "2024-01-15T10:30:00Z",
  "readyToDeploy": true
}
```

## Security Summary

### Layered Security Model

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Portal Authentication (Cognito JWT)            │
│ - User logs in with email/password                      │
│ - MFA required for admin actions                        │
│ - Session expires after 1 hour                          │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 2: API Key Validation (X-Api-Key header)          │
│ - Every API request requires valid API key              │
│ - API key stored in Cognito custom attribute            │
│ - Backend validates API key exists and is active        │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Cross-Account Access (External ID)             │
│ - API key used as External ID for role assumption       │
│ - Prevents confused deputy problem                      │
│ - Must match exactly or access denied                   │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 4: Synthesizer Verification                       │
│ - Validates AWS resources exist and are accessible      │
│ - Checks IAM roles, S3 buckets, ECR, KMS keys           │
│ - Must pass before any deployments allowed               │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 5: Release Verification                            │
│ - Validates release configuration                        │
│ - Checks domain, DNS, SES, quotas                       │
│ - Prevents failed deployments                            │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 6: CloudFormation Deployment                      │
│ - Service-scoped IAM permissions                         │
│ - Resource tagging for audit                             │
│ - All actions logged in CloudTrail                       │
└─────────────────────────────────────────────────────────┘
```

### Security Checklist

**Before first deployment:**
- ✅ User authenticated with Cognito (JWT validated)
- ✅ API key generated and stored securely
- ✅ Synthesizer created with correct configuration
- ✅ IAM roles deployed with External ID = API key
- ✅ Synthesizer verified (all checks passed)
- ✅ Release created with valid configuration
- ✅ Release verified (all checks passed)
- ✅ Team quotas checked
- ✅ Service quotas verified

**During deployment:**
- ✅ API key sent in X-Api-Key header
- ✅ External ID used for role assumption
- ✅ CloudFormation execution with scoped permissions
- ✅ All actions logged to CloudTrail
- ✅ Resources tagged with deployment metadata

**After deployment:**
- ✅ Stack outputs captured
- ✅ Deployment success notification sent
- ✅ Audit trail maintained
- ✅ Resources tracked for cost allocation

## Next Steps

- [Synthesizer Configuration →](/workflow/synthesizer.md)
- [Release Management →](/workflow/release.md)
- [CDK Bootstrap →](/getting-started/bootstrap/cdk.md)
- [Custom Bootstrap →](/getting-started/bootstrap/custom.md)
