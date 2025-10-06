# Compliance

## Overview

Fastish infrastructure is built on AWS services that support major compliance frameworks. While Fastish provides the technical foundation, achieving compliance requires proper configuration, processes, and documentation.

## Shared Responsibility Model

**AWS Responsibilities** (Security OF the Cloud):
- Physical infrastructure security
- Hypervisor and host OS
- Network infrastructure
- Service compliance certifications

**Your Responsibilities** (Security IN the Cloud):
- Data encryption configuration
- Access control (IAM policies)
- Application security
- Compliance documentation
- Audit log retention

## Supported Compliance Frameworks

### SOC 2

**AWS Status**: All Fastish services are SOC 2 Type II compliant

**What you need to do**:
1. **Access Controls**: Implement least-privilege IAM policies
2. **Audit Logging**: Enable CloudTrail and CloudWatch Logs
3. **Data Encryption**: Enable encryption at rest and in transit (default in Fastish)
4. **Monitoring**: Set up CloudWatch alarms for security events
5. **Documentation**: Document your security controls

**Evidence collection**:
```bash
# CloudTrail logs (who did what, when)
aws cloudtrail lookup-events \
  --start-time $(date -u -d '30 days ago' --iso-8601=seconds) \
  --max-items 100

# CloudWatch Logs (application access logs)
aws logs filter-log-events \
  --log-group-name /aws/lambda/app-webapp-api-user \
  --start-time $(date -d '7 days ago' +%s)000
```

### HIPAA

**AWS Status**: AWS provides Business Associate Addendum (BAA) for HIPAA-eligible services

**Fastish HIPAA-Eligible Services**:
- ✅ Amazon EKS
- ✅ Amazon RDS
- ✅ Amazon S3
- ✅ Amazon DynamoDB
- ✅ Amazon Cognito
- ✅ AWS Lambda
- ✅ Amazon API Gateway
- ✅ Amazon MSK
- ✅ Amazon SES
- ✅ AWS Secrets Manager

**Steps to achieve HIPAA compliance**:

1. **Sign AWS BAA**:
   - Contact AWS Support
   - Request HIPAA BAA for your account
   - Sign and return agreement

2. **Enable Encryption** (already default):
   - At rest: KMS encryption enabled
   - In transit: TLS 1.2+ enforced

3. **Access Controls**:
   - Implement MFA for all users
   - Use IAM roles with least privilege
   - Enable CloudTrail logging

4. **Audit Logs**:
   - CloudTrail enabled (90-day retention minimum)
   - CloudWatch Logs enabled
   - VPC Flow Logs enabled (optional but recommended)

5. **Data Backups**:
   ```bash
   # Enable DynamoDB Point-in-Time Recovery
   aws dynamodb update-continuous-backups \
     --table-name app-webapp-db-user \
     --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

   # Enable RDS automated backups (already enabled by default)
   aws rds describe-db-instances \
     --db-instance-identifier <instance-id> \
     --query 'DBInstances[0].BackupRetentionPeriod'
   ```

6. **Physical Safeguards**: Handled by AWS

7. **Technical Safeguards**: Encryption + access controls (covered above)

8. **Administrative Safeguards**: Your policies and procedures

### GDPR

**AWS Status**: AWS complies with GDPR. AWS provides Data Processing Addendum (DPA)

**Data Residency**:
- Deploy to EU regions: `eu-west-1`, `eu-west-2`, `eu-central-1`
- All data stays in EU region

**GDPR Rights Implementation**:

**Right to Access**:
```bash
# Export user data from DynamoDB
aws dynamodb get-item \
  --table-name app-webapp-db-user \
  --key '{"id": {"S": "user-123"}}'
```

**Right to Erasure**:
```bash
# Delete user from Cognito
aws cognito-idp admin-delete-user \
  --user-pool-id <pool-id> \
  --username user@example.com

# Delete user from DynamoDB
aws dynamodb delete-item \
  --table-name app-webapp-db-user \
  --key '{"id": {"S": "user-123"}}'

# Delete S3 data (if applicable)
aws s3 rm s3://bucket-name/user-123/ --recursive
```

**Right to Data Portability**:
```bash
# Export user data in machine-readable format (JSON)
aws dynamodb get-item \
  --table-name app-webapp-db-user \
  --key '{"id": {"S": "user-123"}}' \
  --output json > user-data.json
```

**Right to Rectification**: Update via DynamoDB `UpdateItem` API

**Data Breach Notification**:
- Enable CloudWatch alarms for unauthorized access
- Configure SNS notifications for security events
- Document incident response procedures (72-hour notification requirement)

**Consent Management**: Implement in application logic (not infrastructure)

### PCI DSS

**Scope**: Required if handling credit card data

**AWS Status**: AWS provides PCI DSS Level 1 compliant infrastructure

**Recommendation**: Use third-party payment processors (Stripe, PayPal) to minimize PCI scope

**If storing card data**:
- Requires extensive additional controls
- Annual PCI audit required
- Consider AWS PCI DSS Workloads whitepaper

### ISO 27001

**AWS Status**: All AWS services used by Fastish are ISO 27001 certified

**What you need**:
1. Information Security Management System (ISMS)
2. Risk assessment process
3. Security controls documentation
4. Internal audits
5. Management review

**Evidence from Fastish**:
- CloudTrail logs
- CloudWatch metrics
- Encryption configurations
- IAM policies
- VPC security groups

## Encryption Implementation

### At Rest (Already Enabled)

**S3 Buckets**:
```yaml
# Enabled by default in BucketConstruct
encryption: AES256 or aws:kms
```

**RDS**:
```yaml
# Enabled by default in RdsConstruct
encryption: true
```

**DynamoDB**:
```yaml
# Enabled by default in DynamoDbConstruct
encryption:
  enabled: true
  owner: aws
```

**EBS Volumes** (EKS nodes):
```yaml
# Enabled by default in NodeGroupsConstruct
encrypted: true
kmsKey: alias/{id}-eks-ebs-encryption
```

### In Transit (Already Enforced)

- All API Gateway endpoints: HTTPS only
- All database connections: TLS
- All inter-service communication: TLS
- Cognito: HTTPS enforced

## Audit & Logging

### CloudTrail (Management Events)

**Enable**:
```bash
aws cloudtrail create-trail \
  --name compliance-trail \
  --s3-bucket-name compliance-logs \
  --is-multi-region-trail

aws cloudtrail start-logging \
  --name compliance-trail
```

**What's logged**:
- All API calls
- User identity
- Timestamp
- Source IP
- Request parameters

### CloudWatch Logs (Application Events)

**Already enabled** for:
- Lambda functions
- API Gateway requests
- EKS pods

**Retention**: Configure per compliance requirements
```bash
aws logs put-retention-policy \
  --log-group-name /aws/lambda/app-webapp-api-user \
  --retention-in-days 90
```

### VPC Flow Logs (Network Traffic)

**Enable** (see [VPC Documentation](/druid/vpc.md#post-deployment-customizations-optional)):
```java
FlowLog.Builder.create(this, "VpcFlowLog")
  .resourceType(FlowLogResourceType.fromVpc(vpc))
  .destination(FlowLogDestination.toCloudWatchLogs(logGroup))
  .trafficType(FlowLogTrafficType.ALL)
  .build();
```

## Compliance Checklist

### Pre-Deployment

- [ ] Reviewed compliance framework requirements
- [ ] Signed AWS BAA (for HIPAA)
- [ ] Configured data residency (selected region)
- [ ] Enabled encryption (verify defaults)
- [ ] Documented security controls

### Post-Deployment

- [ ] CloudTrail enabled with 90+ day retention
- [ ] CloudWatch Logs retention configured
- [ ] VPC Flow Logs enabled (recommended)
- [ ] MFA enabled for all admin users
- [ ] Security group rules reviewed and documented
- [ ] IAM policies follow least privilege
- [ ] Backup and recovery procedures documented
- [ ] Incident response plan created

### Ongoing

- [ ] Regular security audits
- [ ] Quarterly access reviews
- [ ] Annual penetration testing (if required)
- [ ] Compliance documentation updated
- [ ] Audit log reviews
- [ ] Security patches applied

## Compliance Resources

### AWS Resources

- [AWS Compliance Programs](https://aws.amazon.com/compliance/programs/)
- [AWS HIPAA Whitepaper](https://d1.awsstatic.com/whitepapers/compliance/AWS_HIPAA_Compliance_Whitepaper.pdf)
- [AWS GDPR Center](https://aws.amazon.com/compliance/gdpr-center/)
- [AWS PCI DSS Guide](https://aws.amazon.com/compliance/pci-dss-level-1-faqs/)

### Fastish Documentation

- [Security →](security.md)
- [Data Sovereignty →](data-sovereignty.md)
- [Druid Architecture →](../druid/overview.md)
- [WebApp Architecture →](../webapp/overview.md)

## Getting Help

For compliance questions specific to your use case:
- Consult with compliance professionals
- Review AWS compliance documentation
- Consider AWS Professional Services for compliance guidance

**Note**: This documentation provides technical implementation guidance. It does not constitute legal advice. Consult legal and compliance professionals for your specific requirements.
