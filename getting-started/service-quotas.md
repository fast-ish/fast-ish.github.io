# AWS Service Quotas

## Overview

AWS imposes service quotas (formerly called limits) on various resources. Before deploying Fastish infrastructure, verify your account has sufficient quotas for the architecture you're deploying.

## Critical Quotas by Architecture

### Druid Architecture (EKS-based)

**Amazon EKS**:
- **Clusters per region**: 100 (default) - Usually sufficient
- **Managed node groups per cluster**: 30 (default) - Typically uses 1-2
- **Nodes per managed node group**: 450 (default) - Sufficient for most deployments

**Amazon EC2**:
- **Running On-Demand instances**: Varies by instance type
  - `m5a.large`: Default ~20 vCPUs per region
  - **Required for Druid**: 2-6 instances = 4-12 vCPUs
- **Elastic IPs**: 5 (default) - Druid uses 2-3 for NAT Gateways

**Amazon VPC**:
- **VPCs per region**: 5 (default) - Druid uses 1
- **NAT Gateways per AZ**: 5 (default) - Druid uses 2
- **Subnets per VPC**: 200 (default) - Druid uses 6

**Amazon RDS**:
- **DB instances**: 40 (default) - Druid uses 1 (PostgreSQL for metadata)
- **Storage per DB instance**: 64 TB (default) - Sufficient

**Amazon MSK**:
- **Serverless clusters per account**: 50 (default) - Druid uses 1
- **Provisioned clusters per account**: 30 (default if using provisioned MSK)

### WebApp Architecture (Serverless)

**AWS Lambda**:
- **Concurrent executions**: 1,000 (default) - Shared across all functions
  - **Monitor**: Use CloudWatch metric `ConcurrentExecutions`
  - **Request increase**: If exceeding 80% utilization

**Amazon DynamoDB**:
- **Tables per region**: 2,500 (default) - WebApp uses 1
- **On-Demand throughput**: Essentially unlimited (auto-scales)

**Amazon Cognito**:
- **User pools per account**: 1,000 (default) - WebApp uses 1
- **Users per user pool**: Unlimited

**Amazon SES**:
- **Sending quota**: 200 emails/day (sandbox) → Request production access
- **Sending rate**: 1 email/second (sandbox) → Increases after production access

**Amazon API Gateway**:
- **REST APIs per region**: 600 (default) - WebApp uses 1
- **Throttle rate limit**: 10,000 requests/second (account-level)
- **Throttle burst limit**: 5,000 requests (account-level)

## Checking Current Quotas

### Using AWS Console

1. Navigate to **Service Quotas** console
2. Select service (e.g., "Amazon Elastic Kubernetes Service")
3. View "Applied quota value" for each limit

### Using AWS CLI

**Check EKS quotas**:
```bash
aws service-quotas list-service-quotas \
  --service-code eks \
  --query 'Quotas[?QuotaName==`Clusters`]'
```

**Check EC2 vCPU quotas**:
```bash
aws service-quotas list-service-quotas \
  --service-code ec2 \
  --query 'Quotas[?contains(QuotaName, `Running On-Demand`)]'
```

**Check Lambda concurrency**:
```bash
aws service-quotas get-service-quota \
  --service-code lambda \
  --quota-code L-B99A9384
```

## Requesting Quota Increases

### When to Request

**Before deployment** if:
- Deploying to a new AWS account
- Deploying large-scale Druid cluster (>10 nodes)
- Expecting high traffic (>1,000 concurrent Lambda executions)
- Sending high-volume emails (>200/day)

### How to Request

**Method 1: AWS Console**:
1. Open **Service Quotas** console
2. Navigate to desired service
3. Select quota to increase
4. Click "Request quota increase"
5. Enter desired value with justification
6. Submit request

**Typical approval time**: 24-48 hours (varies by service)

**Method 2: AWS CLI**:
```bash
aws service-quotas request-service-quota-increase \
  --service-code eks \
  --quota-code L-1194D53C \
  --desired-value 200
```

## Critical Pre-Deployment Checks

### For Druid Deployment

```bash
# Check EKS cluster limit
aws service-quotas get-service-quota \
  --service-code eks \
  --quota-code L-1194D53C

# Check EC2 On-Demand vCPU limit (Standard instances)
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A

# Check NAT Gateway limit
aws service-quotas get-service-quota \
  --service-code vpc \
  --quota-code L-FE5A380F
```

### For WebApp Deployment

```bash
# Check Lambda concurrent executions
aws lambda get-account-settings \
  --query 'AccountLimit.ConcurrentExecutions'

# Check API Gateway REST APIs
aws service-quotas get-service-quota \
  --service-code apigateway \
  --quota-code L-A93C1BC7

# Check SES sending quota (requires SES console)
aws ses get-send-quota
```

## Common Quota Issues

### Issue: "Cannot create EKS cluster" Error

**Cause**: EKS cluster quota reached

**Check**:
```bash
aws eks list-clusters --query 'length(clusters)'
```

**Fix**: Request increase for EKS clusters quota or delete unused clusters

### Issue: Lambda throttling (429 errors)

**Cause**: Concurrent execution limit reached

**Check**:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name ConcurrentExecutions \
  --start-time $(date -u -d '1 hour ago' --iso-8601=seconds) \
  --end-time $(date -u --iso-8601=seconds) \
  --period 300 \
  --statistics Maximum
```

**Fix**: Request increase for concurrent executions or implement SQS queuing

### Issue: SES emails not sending

**Cause**: Account in SES sandbox (limited to 200 emails/day)

**Fix**: Request production access:
1. Open SES console
2. Navigate to "Account dashboard"
3. Click "Request production access"
4. Complete request form

## Related Documentation

- [Requirements →](requirements.md)
- [Setup Guide →](setup.md)
- [Quick Start →](quickstart.md)
- [AWS Service Quotas Documentation](https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html)
