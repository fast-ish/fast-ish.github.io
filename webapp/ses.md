# Amazon SES (Email)

## Overview

Amazon SES (Simple Email Service) handles all email sending and receiving for the WebApp. This includes transactional emails (password resets, welcome messages) and incoming email processing.

## Configuration

**Input (cdk.context.json)**:
```json
{
  "deployment:id": "app",
  "deployment:domain": "stxkxs.io",
  "deployment:ses:hosted:zone": "Z1234567890ABC",
  "deployment:ses:email": "admin@stxkxs.io"
}
```

**Template (production/v1/conf.mustache)**:
```yaml
ses:
  identity:
    hostedZone: {{deployment:ses:hosted:zone}}      # Route53 Hosted Zone ID
    email: {{deployment:ses:email}}                  # Admin email
    domain: {{deployment:domain}}                    # stxkxs.io
    mxFailure: use_default_value
    mailFromDomain: feedback.{{deployment:domain}}   # feedback.stxkxs.io
    feedbackForwarding: true
```

**CDK Construct**: [`IdentityConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/ses/IdentityConstruct.java)

## Email Sending

### Domain Identity

**Domain**: `{hosted:domain}` (e.g., `stxkxs.io`)

**MAIL FROM Domain**: `feedback.{hosted:domain}` (e.g., `feedback.stxkxs.io`)

**Purpose**: Allows sending emails from `@stxkxs.io` addresses

### Configuration Set

**Name**: `{id}-webapp-configuration-set`

```yaml
configurationSet:
  name: {{deployment:id}}-webapp-configuration-set
  customTrackingRedirectDomain: {{deployment:domain}}
  reputationMetrics: true
  sendingEnabled: true
  tlsPolicyConfiguration: optional
  suppressionReasons: bounces_and_complaints
```

**Features**:
- Reputation metrics tracking
- Bounce and complaint suppression
- TLS for email transmission
- Custom tracking domain

## Email Receiving

### Receipt Rules

**Rule Set Name**: `{id}-webapp-receipt-rules`

**Configuration**:
```yaml
receiving:
  name: {{deployment:id}}-webapp-receipt-rules
  rules:
    - name: email-receipt
      enabled: true
      scanEnabled: true       # Spam/virus scanning
      recipients:
        - hi@{{deployment:domain}}  # Receives at hi@stxkxs.io
      s3Actions:
        - prefix: emails/
          topic: {{deployment:id}}-webapp-received-emails
```

**How it works**:
1. Email arrives at `hi@stxkxs.io`
2. SES scans for spam/viruses
3. SES stores email in S3 bucket: `{id}-webapp-ses-received-emails`
4. SNS topic notified: `{id}-webapp-received-emails`

### S3 Storage

**Bucket**: `{id}-webapp-ses-received-emails`

```yaml
bucket:
  name: {{deployment:id}}-webapp-ses-received-emails
  accessControl: bucket_owner_full_control
  objectOwnership: bucket_owner_enforced
  removalPolicy: destroy
  autoDeleteObjects: true
  lifecycleRules:
    - id: {{deployment:id}}-webapp-ses-received-emails
      expiration: 1           # Delete after 1 day
      enabled: true
```

**Lifecycle**: Emails automatically deleted after 1 day

**Policy**: SES service has PutObject permission (via `policy/ses/put-emails.mustache`)

## Bounce & Complaint Handling

### SNS Topics

**Bounce Topic**: `{id}-webapp-bounce`

**Complaint Topic**: `{id}-webapp-complaint`

**Reject Topic**: `{id}-webapp-reject`

```yaml
destination:
  bounce:
    enabled: true
    topic: "{{deployment:id}}-webapp-bounce"
    configurationSet: "{{deployment:id}}-webapp-configuration-set"
  complaint:
    enabled: true
    topic: "{{deployment:id}}-webapp-complaint"
    configurationSet: "{{deployment:id}}-webapp-configuration-set"
  reject:
    enabled: true
    topic: "{{deployment:id}}-webapp-reject"
    configurationSet: "{{deployment:id}}-webapp-configuration-set"
```

**Purpose**: Notifications when emails bounce or users mark as spam

## DNS Configuration

After deployment, you must add DNS records to your Route 53 hosted zone:

### Required Records

**1. MX Record** (for receiving emails):
```
Type: MX
Name: stxkxs.io
Value: 10 inbound-smtp.us-west-2.amazonaws.com
```

**2. MAIL FROM Domain** (for sending):
```
Type: MX
Name: feedback.stxkxs.io
Value: 10 feedback-smtp.us-west-2.amazonses.com

Type: TXT
Name: feedback.stxkxs.io
Value: v=spf1 include:amazonses.com ~all
```

**3. DKIM Records** (auto-created if using CDK with Route53):

CDK automatically creates DKIM records if hosted zone ID is provided.

## Integration with Cognito

Cognito uses SES to send authentication emails:

**Email types**:
- Welcome emails (new user sign-up)
- Verification codes
- Password reset links
- MFA codes (if email-based MFA enabled)

See [Authentication →](authentication.md) for Cognito configuration.

## Cost Estimate

**SES Sending**:
- First 62,000 emails/month: **Free** (if sending from EC2/Lambda)
- Additional emails: $0.10/1000 emails

**SES Receiving**:
- First 1,000 emails/month: **Free**
- Additional emails: $0.10/1000 emails

**S3 Storage**: ~$0.01/month (with 1-day expiration)

**SNS**: ~$0.50/month (for bounce/complaint notifications)

**Total**: ~$1-5/month for typical usage

## Related Documentation

- [WebApp Overview →](overview.md)
- [Authentication →](authentication.md) - Cognito email integration
- [API Gateway →](api-gateway.md)
