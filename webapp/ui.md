# User Interface

## Overview

⚠️ **Note**: Frontend/UI deployment is not currently included in the WebApp infrastructure templates. This page provides guidance for deploying a frontend application separately.

## Architecture Options

### Option 1: AWS Amplify + Next.js

Deploy a React/Next.js frontend with automatic CI/CD.

**Setup**:
1. Create Next.js application
2. Connect to GitHub repository
3. Deploy via AWS Amplify Console
4. Amplify handles build, deployment, and hosting

**Integration with WebApp Backend**:
```typescript
// Example API call from Next.js
const response = await fetch('https://api.example.com/v1/users', {
  headers: {
    'Authorization': `Bearer ${cognitoToken}`
  }
});
```

**CDK Reference**: [`App`](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_amplify.App.html)

### Option 2: S3 + CloudFront

Host static website on S3 with CloudFront CDN.

**Example CDK Code**:
```java
import software.amazon.awscdk.services.s3.Bucket;
import software.amazon.awscdk.services.cloudfront.Distribution;
import software.amazon.awscdk.services.cloudfront.origins.S3Origin;

// Create S3 bucket for static website
Bucket websiteBucket = Bucket.Builder.create(this, "WebsiteBucket")
  .websiteIndexDocument("index.html")
  .publicReadAccess(false)
  .blockPublicAccess(BlockPublicAccess.BLOCK_ALL)
  .build();

// Create CloudFront distribution
Distribution distribution = Distribution.Builder.create(this, "Distribution")
  .defaultBehavior(BehaviorOptions.builder()
    .origin(new S3Origin(websiteBucket))
    .build())
  .defaultRootObject("index.html")
  .build();
```

**CDK Reference**: [`Distribution`](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_cloudfront.Distribution.html)

### Option 3: Container-based (ECS/EKS)

Run frontend as containers for SSR (Server-Side Rendering).

**Use cases**:
- Next.js with SSR enabled
- Complex frontend requiring server-side logic
- Need for fine-grained control over infrastructure

## Authentication Integration

### Using Cognito with Frontend

**Install AWS Amplify libraries**:
```bash
npm install aws-amplify @aws-amplify/ui-react
```

**Configure Cognito**:
```typescript
import { Amplify } from 'aws-amplify';

Amplify.configure({
  Auth: {
    Cognito: {
      userPoolId: 'us-west-2_abc123',
      userPoolClientId: 'abc123...',
      region: 'us-west-2'
    }
  }
});
```

**Sign in**:
```typescript
import { signIn } from 'aws-amplify/auth';

async function handleSignIn(username: string, password: string) {
  try {
    const { isSignedIn } = await signIn({ username, password });
    if (isSignedIn) {
      // Get tokens for API calls
      const session = await fetchAuthSession();
      const idToken = session.tokens?.idToken;
    }
  } catch (error) {
    console.error('Sign in failed', error);
  }
}
```

## API Integration

**Making authenticated API requests**:
```typescript
import { fetchAuthSession } from 'aws-amplify/auth';

async function callAPI(endpoint: string) {
  // Get Cognito token
  const session = await fetchAuthSession();
  const token = session.tokens?.idToken?.toString();

  // Call API Gateway
  const response = await fetch(`https://api.example.com/v1/${endpoint}`, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  });

  return response.json();
}
```

## Cost Estimate

**AWS Amplify** (Option 1):
- Build minutes: First 1,000 minutes/month free, then $0.01/min
- Hosting: First 15 GB served/month free, then $0.15/GB
- Typical: ~$5-20/month

**S3 + CloudFront** (Option 2):
- S3: ~$0.023/GB storage + $0.09/GB transfer
- CloudFront: First 1 TB/month: $0.085/GB
- Typical: ~$5-15/month

**ECS/EKS** (Option 3):
- More expensive: $30-100+/month depending on instance types

## Example Repositories

**Next.js + Amplify**:
```bash
npx create-next-app@latest my-webapp
cd my-webapp
npm install aws-amplify @aws-amplify/ui-react
```

**React + Vite + Amplify**:
```bash
npm create vite@latest my-webapp -- --template react-ts
cd my-webapp
npm install aws-amplify @aws-amplify/ui-react
```

## Related Documentation

- [WebApp Overview →](overview.md)
- [Authentication →](authentication.md) - Cognito setup
- [API Gateway →](api-gateway.md) - Backend API
- [AWS Amplify Documentation](https://docs.amplify.aws/)
