# Data Sovereignty

## Overview

Data sovereignty refers to the concept that data is subject to the laws and governance structures of the country or region where it is stored. Fastish infrastructure allows you to maintain full control over data location and compliance.

## Regional Data Control

### Deployment Region Selection

All Fastish infrastructure is deployed to a **single AWS region** that you specify in `cdk.context.json`:

```json
{
  "hosted:region": "us-west-2"
}
```

**Data residency**: All data remains in the selected region unless explicitly configured otherwise.

**Available regions**: Any AWS region supporting required services (EKS, MSK, RDS, DynamoDB, Cognito)

### Multi-Region Deployment

To deploy infrastructure in multiple regions for data sovereignty compliance:

**Option 1**: Deploy separate stacks per region
```bash
# EU deployment
cd aws-webapp-infra/infra
# Edit cdk.context.json: "hosted:region": "eu-west-1"
cdk deploy

# US deployment
# Edit cdk.context.json: "hosted:region": "us-west-2"
cdk deploy
```

**Option 2**: Use AWS Organizations for regional account separation
- Separate AWS account per region/jurisdiction
- Deploy Fastish to each account independently

## Data Storage Locations

### Druid Architecture

**Amazon EKS**: Control plane and worker nodes in selected region

**Amazon RDS (PostgreSQL)**: Metadata storage in selected region
- Multi-AZ deployment within region for HA
- No cross-region replication by default

**Amazon S3 (Deep Storage)**: Data stored in selected region
- S3 buckets region-locked at creation
- Replication only if explicitly configured

**Amazon MSK**: Kafka data in selected region
- Data replicated across AZs within region
- No cross-region data transfer

### WebApp Architecture

**Amazon Cognito**: User data stored in selected region

**Amazon DynamoDB**: Table data in selected region
- Global tables available if cross-region replication needed
- Must be explicitly enabled

**Amazon SES**: Email metadata in selected region

**AWS Lambda**: Execution logs in selected region (CloudWatch Logs)

## Cross-Region Data Transfer

By default, **no cross-region data transfer** occurs in Fastish infrastructure.

### When Cross-Region Transfer Happens

**Only if you explicitly configure**:
- S3 Cross-Region Replication (CRR)
- DynamoDB Global Tables
- CloudWatch Logs cross-region streaming
- Custom application logic

**Control mechanism**: All configured in your infrastructure code

## Compliance Frameworks

### GDPR (EU)

**Data residency**: Deploy to EU regions (e.g., `eu-west-1`, `eu-central-1`)

**User rights**:
- **Right to erasure**: Delete DynamoDB/Cognito user records
- **Data portability**: Export user data from DynamoDB
- **Access logs**: CloudWatch Logs track all data access

**DPAs**: AWS provides Data Processing Addendum covering GDPR

**Fastish support**:
- All data stays in EU when deployed to EU region
- No automatic cross-border transfers
- Encryption at rest and in transit

### HIPAA

**AWS BAA**: Available for HIPAA-eligible services

**Fastish HIPAA-eligible services**:
- Amazon EKS ✓
- Amazon RDS ✓
- Amazon S3 ✓
- Amazon DynamoDB ✓
- Amazon Cognito ✓
- AWS Lambda ✓
- Amazon API Gateway ✓

**Your responsibilities**:
- Sign AWS Business Associate Agreement
- Enable encryption (already default in Fastish)
- Implement access controls
- Maintain audit logs

**Fastish support**:
- All data encrypted at rest (KMS)
- All data encrypted in transit (TLS)
- CloudWatch Logs for audit trails

### SOC 2

**AWS SOC 2 compliance**: All services used by Fastish are SOC 2 compliant

**Evidence collection**:
- CloudWatch Logs for access logs
- CloudTrail for API activity
- VPC Flow Logs (optional) for network monitoring

### Data Localization Laws

**China**: Deploy to `cn-north-1` or `cn-northwest-1` (requires separate AWS China account)

**Russia**: AWS does not have regions in Russia. Consider:
- Deploying to nearest region (e.g., `eu-central-1`)
- Using AWS Outposts for on-premises deployment

**India**: Deploy to `ap-south-1` (Mumbai)

## Encryption & Security

### At Rest

**All data encrypted by default**:
- **S3**: AES-256 (SSE-S3) or KMS
- **RDS**: AES-256 encryption
- **DynamoDB**: AWS-managed or KMS encryption
- **EBS volumes**: KMS encryption

**Key management**:
- AWS-managed keys (default)
- Customer-managed KMS keys (recommended for compliance)

### In Transit

**All data encrypted**:
- TLS 1.2+ for all API calls
- HTTPS enforced for API Gateway
- Encrypted connections between services

## Audit & Logging

### CloudTrail

**All API calls logged**:
- Who accessed data
- When access occurred
- Source IP address
- API parameters

**Retention**: Configurable (default: 90 days)

### CloudWatch Logs

**Application logs**:
- Lambda function executions
- API Gateway requests
- EKS pod logs

**Retention**: Configurable (default: 1-7 days)

### VPC Flow Logs (Optional)

**Network traffic monitoring**:
- Source/destination IPs
- Ports and protocols
- Accept/reject decisions

**Enable**: See [VPC documentation](../druid/vpc.md#post-deployment-customizations-optional)

## Data Deletion

### User Data

**Cognito users**:
```bash
aws cognito-idp admin-delete-user \
  --user-pool-id <pool-id> \
  --username <username>
```

**DynamoDB records**:
```bash
aws dynamodb delete-item \
  --table-name <table-name> \
  --key '{"id": {"S": "<user-id>"}}'
```

### Complete Infrastructure

**Delete all data**:
```bash
# Destroys all resources and data
cdk destroy
```

**Warning**: Irreversible. Ensure backups if needed.

## Best Practices

1. **Deploy to appropriate region** based on user location and legal requirements
2. **Enable KMS encryption** with customer-managed keys for sensitive data
3. **Configure DynamoDB Point-in-Time Recovery** for data protection
4. **Enable CloudTrail** for comprehensive audit logs
5. **Document data flows** for compliance audits
6. **Implement data retention policies** aligned with legal requirements
7. **Regular compliance reviews** of infrastructure configuration

## Related Documentation

- [Security →](security.md)
- [Compliance →](compliance.md)
- [Druid Overview →](../druid/overview.md)
- [WebApp Overview →](../webapp/overview.md)
- [AWS Compliance Programs](https://aws.amazon.com/compliance/programs/)
