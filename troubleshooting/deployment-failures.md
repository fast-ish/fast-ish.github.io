# Deployment Failures

## Overview

This guide addresses CloudFormation stack deployment failures and how to recover from them.

## Pre-Deployment Validation

### Validate CDK Context

**Before deploying**, validate your `cdk.context.json`:

```bash
# Check JSON syntax
cat cdk.context.json | jq .

# If error, fix JSON syntax issues
```

**Common issues**:
- Missing commas
- Trailing commas in arrays/objects
- Unquoted strings
- Wrong quotation marks (" vs ')

### Preview Changes

```bash
# Preview CloudFormation template
cdk synth

# Preview changes to existing stack
cdk diff
```

**Review output** for:
- IAM policy changes (security implications)
- Resource deletions (data loss risk)
- Resource replacements (potential downtime)

## During Deployment

### Monitor Deployment Progress

```bash
# Watch CloudFormation events in real-time
watch -n 5 'aws cloudformation describe-stack-events \
  --stack-name <stack-name> \
  --max-items 10 \
  --query "StackEvents[*].[Timestamp,ResourceStatus,LogicalResourceId]" \
  --output table'
```

### Common Failure Patterns

#### 1. Service Quota Exceeded

**Error**:
```
CREATE_FAILED: The maximum number of VPCs has been reached
```

**Solution**:
```bash
# Check current quota
aws service-quotas get-service-quota \
  --service-code vpc \
  --quota-code L-F678F1CE

# Request increase
aws service-quotas request-service-quota-increase \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --desired-value 10
```

**See**: [Service Quotas →](/getting-started/service-quotas.md)

#### 2. Resource Already Exists

**Error**:
```
CREATE_FAILED: Resource with name 'app-webapp-vpc' already exists
```

**Cause**: Previous deployment left resources, or name conflict

**Solution**:
```bash
# Option 1: Change hosted:id in cdk.context.json
{
  "deployment:id": "app2"  # Change from "app" to "app2"
}

# Option 2: Delete existing resources manually
aws ec2 delete-vpc --vpc-id <vpc-id>

# Option 3: Import existing resource (advanced)
cdk import
```

#### 3. IAM Permissions Denied

**Error**:
```
CREATE_FAILED: User is not authorized to perform: iam:CreateRole
```

**Solution**: Verify IAM permissions
```bash
# Check current user
aws sts get-caller-identity

# Verify has AdministratorAccess or equivalent
aws iam list-attached-user-policies --user-name <username>
```

#### 4. Dependency Failure

**Error**:
```
CREATE_FAILED: Resource creation cancelled (dependent resource failed)
```

**Solution**: Find root cause
```bash
# Find first failed resource
aws cloudformation describe-stack-events \
  --stack-name <stack-name> \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`] | [0]'
```

## Stack Rollback

### Understanding Rollback

When deployment fails, CloudFormation automatically:
1. Stops creating new resources
2. Deletes resources created during this deployment
3. Returns stack to previous state (or DELETE_COMPLETE for new stacks)

### Viewing Rollback Reasons

```bash
# Find why rollback occurred
aws cloudformation describe-stack-events \
  --stack-name <stack-name> \
  --query 'StackEvents[?ResourceStatusReason!=`null`]' \
  --output table
```

### Rollback States

**UPDATE_ROLLBACK_COMPLETE**:
- Stack reverted to previous working state
- Safe to redeploy after fixing issues

**ROLLBACK_COMPLETE**:
- New stack creation failed
- Stack exists but has no resources
- Must delete before redeploying

**UPDATE_ROLLBACK_FAILED**:
- Rollback itself failed (rare)
- Stack in inconsistent state
- Requires manual intervention

## Recovery Procedures

### Scenario 1: New Stack Creation Failed

**Stack Status**: `ROLLBACK_COMPLETE`

**Solution**:
```bash
# Delete failed stack
aws cloudformation delete-stack --stack-name <stack-name>

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name <stack-name>

# Fix issues in cdk.context.json

# Redeploy
cdk deploy
```

### Scenario 2: Stack Update Failed

**Stack Status**: `UPDATE_ROLLBACK_COMPLETE`

**Solution**:
```bash
# Fix issues in cdk.context.json or code

# Redeploy
cdk deploy
```

**No need to delete** - stack automatically rolled back to working state

### Scenario 3: Rollback Failed

**Stack Status**: `UPDATE_ROLLBACK_FAILED`

**Solution**:
```bash
# Continue rollback manually
aws cloudformation continue-update-rollback \
  --stack-name <stack-name>

# If specific resources blocking:
aws cloudformation continue-update-rollback \
  --stack-name <stack-name> \
  --resources-to-skip <resource-logical-id>
```

**If still failing**: Contact AWS Support

### Scenario 4: Stack Stuck in IN_PROGRESS

**Stack Status**: `CREATE_IN_PROGRESS` or `UPDATE_IN_PROGRESS` for >1 hour

**Check if actually stuck**:
```bash
# View recent events
aws cloudformation describe-stack-events \
  --stack-name <stack-name> \
  --max-items 5
```

**If truly stuck** (no new events in 30+ minutes):
```bash
# Cancel update (only works for updates, not creates)
aws cloudformation cancel-update-stack \
  --stack-name <stack-name>
```

## Debugging Nested Stacks

Fastish uses nested stacks (e.g., `VpcNestedStack`, `EksNestedStack`).

### Find Failed Nested Stack

```bash
# List all nested stacks
aws cloudformation list-stack-resources \
  --stack-name <main-stack-name> \
  --query 'StackResourceSummaries[?ResourceType==`AWS::CloudFormation::Stack`]'

# Get nested stack events
aws cloudformation describe-stack-events \
  --stack-name <nested-stack-name>
```

### Nested Stack Failure Patterns

**Nested stack failed, parent stack rolling back**:
1. Find nested stack name in parent events
2. Check nested stack events for root cause
3. Fix issue
4. Redeploy parent stack (nested stack recreates automatically)

## Specific Infrastructure Failures

### Bootstrap Stack Failures

**Most common**: S3 bucket name conflict

**Error**:
```
CREATE_FAILED: Bucket name already exists
```

**Solution**: S3 bucket names auto-generated, shouldn't conflict. If it does:
```bash
# Change synthesizer name
{
  "synthesizer": {
    "name": "prod2"  # Change from "prod"
  }
}
```

### Druid Stack Failures

**EKS Creation Timeout**:
- EKS takes 15-20 minutes to create
- Not stuck if still under 25 minutes

**Grafana Configuration Error**:
```
CREATE_FAILED: Invalid Grafana credentials
```

**Solution**: Verify all `hosted:eks:grafana:*` fields are correct

**See**: [Grafana Setup →](/getting-started/optional-resources/grafana.md)

### WebApp Stack Failures

**SES Domain Verification Failed**:
```
CREATE_FAILED: Domain not verified
```

**Solution**:
1. Verify domain in SES console
2. Add DNS records to Route 53
3. Wait for verification
4. Redeploy

**Cognito Creation Failed**:
```
CREATE_FAILED: Invalid SES configuration
```

**Cause**: SES not in production mode or email not verified

**Solution**: Request SES production access

## Prevention Strategies

### 1. Use cdk diff Before Deploying

```bash
# Always review changes
cdk diff

# Look for:
# - Resource replacements (data loss risk)
# - Permission changes (security implications)
# - Dependencies (order matters)
```

### 2. Deploy to Test Environment First

```bash
# Test deployment configuration
{
  "deployment:environment": "prototype"  # Use prototype first
}

# After validation
{
  "deployment:environment": "production"  # Then production
}
```

### 3. Enable Termination Protection

For production stacks:
```bash
aws cloudformation update-termination-protection \
  --stack-name <stack-name> \
  --enable-termination-protection
```

### 4. Tag Stacks Appropriately

```bash
aws cloudformation update-stack \
  --stack-name <stack-name> \
  --tags Key=Environment,Value=Production Key=CriticalData,Value=True
```

## Emergency Rollback

### Manual Rollback to Previous Version

If deployment introduced issues:

```bash
# View stack drift (changes outside CloudFormation)
aws cloudformation detect-stack-drift \
  --stack-name <stack-name>

# Rollback to previous template
cdk deploy --previous-version
```

### Data Preservation

**Before deleting stacks with data**:

```bash
# Backup DynamoDB
aws dynamodb create-backup \
  --table-name <table-name> \
  --backup-name pre-delete-backup

# Backup RDS
aws rds create-db-snapshot \
  --db-instance-identifier <instance-id> \
  --db-snapshot-identifier pre-delete-snapshot

# Backup S3 (enable versioning first)
aws s3api put-bucket-versioning \
  --bucket <bucket-name> \
  --versioning-configuration Status=Enabled
```

## Logging and Monitoring

### Enable CloudTrail

```bash
aws cloudtrail create-trail \
  --name deployment-audit \
  --s3-bucket-name <audit-bucket>
```

### CloudWatch Alarms for Deployments

Create SNS topic for deployment notifications:
```bash
aws sns create-topic --name deployment-alerts

aws sns subscribe \
  --topic-arn <topic-arn> \
  --protocol email \
  --notification-endpoint admin@example.com
```

## Getting Help

### Collect Debug Information

Before creating support ticket, collect:

```bash
# Stack status and events
aws cloudformation describe-stack-events \
  --stack-name <stack-name> > stack-events.json

# CloudFormation template
aws cloudformation get-template \
  --stack-name <stack-name> > template.json

# cdk.context.json (REDACT SECRETS!)
cat cdk.context.json | jq 'del(.["deployment:eks:grafana:key"])' > context-redacted.json
```

### AWS Support

**Developer/Business Plans**: Create support case with collected information

**Free Tier**: Post to [AWS re:Post](https://repost.aws/)

## Related Documentation

- [Common Errors →](common-errors.md)
- [Service Quotas →](/getting-started/service-quotas.md)
- [Support →](/support.md)
- [Launch Checklist →](/getting-started/launch.md)
