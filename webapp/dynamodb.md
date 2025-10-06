# DynamoDB

## Overview

Amazon DynamoDB provides NoSQL database storage for the WebApp, with a primary table for user data.

## Configuration

**Template (production/v1/conf.mustache)**:
```yaml
db:
  vpcName: {{hosted:id}}-webapp-vpc
  user:
    name: {{hosted:id}}-webapp-db-user
    partitionKey:
      name: id
      type: string
    tableClass: standard
    removalPolicy: destroy
    contributorInsights: true
    deletionProtection: false
```

**CDK Construct**: [`DynamoDbConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/dynamodb/DynamoDbConstruct.java)

## User Table

**Table Name**: `{id}-webapp-db-user`

**Partition Key**: `id` (String)

**Table Class**: Standard

### Schema

**Primary Key**:
- `id` (String) - User ID (partition key)

**Attributes** (example - defined by application):
- `email` (String)
- `name` (String)
- `createdAt` (Number) - Unix timestamp
- `updatedAt` (Number) - Unix timestamp

**Note**: DynamoDB is schemaless. Only partition/sort keys are defined at table creation. Other attributes are added dynamically by the application.

## Features

### Contributor Insights

**Enabled**: `contributorInsights: true`

**Purpose**: Identifies most accessed items and throttled requests

**View insights**:
```bash
aws dynamodb describe-contributor-insights \
  --table-name app-webapp-db-user
```

### Encryption

```yaml
encryption:
  enabled: true
  owner: aws
  kms: {}
```

**Encryption at rest**: Enabled (AWS-managed keys)

**Encryption in transit**: HTTPS enforced

### Billing Mode

```yaml
billing:
  onDemand: true
```

**On-demand capacity**: Pay per request (no capacity planning required)

**Alternative**: Provisioned capacity (requires capacity planning but can be cheaper for predictable workloads)

### Deletion Protection

```yaml
deletionProtection: false
removalPolicy: destroy
```

**Development setting**: Table can be deleted with stack

**Production recommendation**: Set `deletionProtection: true` to prevent accidental deletion

## Streams (Disabled by Default)

### Kinesis Streams

```yaml
streams:
  kinesis:
    enabled: false
    name: {{hosted:id}}-webapp-db-user-change
```

**Purpose** (if enabled): Capture table changes for analytics or replication

### DynamoDB Streams

```yaml
streams:
  dynamoDb:
    enabled: false
    type: new_image
```

**Purpose** (if enabled): Trigger Lambda functions on table changes

## Access Patterns

### IAM Policy

Lambda functions access DynamoDB via IAM roles.

**Policy Template**: `production/v1/policy/db/dynamodb-access.mustache`

**Permissions**:
- `dynamodb:GetItem`
- `dynamodb:PutItem`
- `dynamodb:UpdateItem`
- `dynamodb:DeleteItem`
- `dynamodb:Query`
- `dynamodb:Scan`

### VPC Integration

DynamoDB is accessed via:
- **Internet**: Lambda in VPC → NAT Gateway → DynamoDB endpoint
- **VPC Endpoint** (recommended): Lambda → VPC Gateway Endpoint → DynamoDB

**Add VPC Endpoint** to reduce costs:
```java
GatewayVpcEndpoint.Builder.create(this, "DynamoDBEndpoint")
  .vpc(vpc)
  .service(GatewayVpcEndpointAwsService.DYNAMODB)
  .build();
```

See [VPC Customizations →](vpc.md#post-deployment-customizations)

## Cost Estimate

**On-demand pricing**:
- Write requests: $1.25 per million requests
- Read requests: $0.25 per million requests
- Storage: $0.25/GB/month

**Example** (100,000 users, 1M requests/month):
- Writes (20%): 200,000 × $1.25/million = $0.25/month
- Reads (80%): 800,000 × $0.25/million = $0.20/month
- Storage (1 GB): 1 × $0.25 = $0.25/month
- **Total**: ~$0.70/month

**First year Free Tier** (if eligible):
- 25 GB storage
- 25 WCUs, 25 RCUs

## Monitoring

### CloudWatch Metrics

**Key metrics**:
- `ConsumedReadCapacityUnits`
- `ConsumedWriteCapacityUnits`
- `UserErrors` (4xx errors)
- `SystemErrors` (5xx errors)

**View metrics**:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value=app-webapp-db-user \
  --start-time $(date -u -d '1 hour ago' --iso-8601=seconds) \
  --end-time $(date -u --iso-8601=seconds) \
  --period 300 \
  --statistics Average
```

## Backup & Recovery

### Point-in-Time Recovery

**Not configured by default** (can be enabled):
```bash
aws dynamodb update-continuous-backups \
  --table-name app-webapp-db-user \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
```

**Cost**: ~$0.20/GB/month

### On-Demand Backups

```bash
aws dynamodb create-backup \
  --table-name app-webapp-db-user \
  --backup-name app-webapp-db-user-$(date +%Y%m%d)
```

**Cost**: $0.10/GB/month

## Best Practices

**For multi-tenant SaaS**:
1. **Partition key**: Use composite key with tenant ID: `{tenantId}#{userId}`
2. **Add GSI** for queries by tenant: `tenantId-createdAt-index`
3. **Enable deletion protection** in production
4. **Enable point-in-time recovery** for production
5. **Use VPC Gateway Endpoint** to reduce NAT Gateway costs

## Related Documentation

- [WebApp Overview →](overview.md)
- [API Gateway →](api-gateway.md) - Accesses DynamoDB
- [VPC →](vpc.md) - Network configuration
