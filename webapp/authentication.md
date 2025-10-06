# Authentication (Cognito)

## Overview

The WebApp architecture uses **Amazon Cognito User Pools** for user authentication and authorization. Cognito provides secure user sign-up, sign-in, and access control for the multi-tenant SaaS application.

## Configuration

Follows the [yaml → model → construct pattern](/getting-started/concepts.md).

**Input (cdk.context.json)**:
```json
{
  "deployment:id": "app",
  "deployment:domain": "stxkxs.io"
}
```

**Template (production/v1/conf.mustache)**:
```yaml
auth:
  vpcName: {{deployment:id}}-webapp-vpc
  userPool: auth/userpool.mustache
  userPoolClient: auth/userpoolclient.mustache
```

**CDK Construct**: [`UserPoolConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/cognito/UserPoolConstruct.java)

## Components

### User Pool

Central user directory for authentication.

**Name**: `{id}-webapp-userpool`

**Templates**:
- `production/v1/auth/userpool.mustache` - User pool configuration
- `production/v1/auth/triggers.mustache` - Lambda triggers
- `production/v1/auth/ses.mustache` - Email configuration
- `production/v1/auth/sns.mustache` - SMS configuration

**Features**:
- Email and password authentication
- Multi-factor authentication (MFA) support
- Account recovery
- Email verification
- Custom attributes
- Lambda triggers for custom workflows

### User Pool Client

Application client for API access.

**Template**: `production/v1/auth/userpoolclient.mustache`

**Purpose**: Allows API Gateway to authenticate users against the User Pool

## Integration

### API Gateway Authorization

API Gateway uses Cognito as the authorizer:

```yaml
api:
  apigw:
    authorizationType: cognito
```

**How it works**:
1. User signs in to Cognito
2. Cognito returns JWT tokens (ID token, access token, refresh token)
3. Client includes ID token in API requests: `Authorization: Bearer <token>`
4. API Gateway validates token against Cognito User Pool
5. If valid, request proceeds to Lambda function

### IAM Permissions

Lambda functions access User Pool via IAM roles.

**Policy Template**: `production/v1/policy/auth/userpool-access.mustache`

## Email Integration (SES)

Cognito uses Amazon SES for sending authentication emails:
- Welcome emails
- Verification codes
- Password reset links
- MFA codes (if email-based)

See [SES Configuration →](ses.md) for email setup details.

## Security Best Practices

**Implemented by default**:
- Password requirements (minimum length, complexity)
- Account lockout after failed attempts
- Token expiration
- Secure token transmission (HTTPS only)

**Recommended additions**:
- Enable MFA for all users
- Configure advanced security features (risk-based authentication)
- Set up CloudWatch alarms for suspicious activity

## Cost Estimate

**Cognito User Pool**:
- First 50,000 MAUs (Monthly Active Users): **Free**
- 50,001 - 100,000 MAUs: $0.0055/MAU
- Above 100,000 MAUs: Volume discounts apply

**MAU** = User who performs an authentication action in a calendar month

## Related Documentation

- [WebApp Overview →](overview.md)
- [API Gateway →](api-gateway.md) - Uses Cognito for authorization
- [SES →](ses.md) - Email delivery for Cognito
