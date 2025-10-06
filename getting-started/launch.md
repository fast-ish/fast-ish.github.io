# Pre-Deployment Checklist

## Overview

Before deploying Fastish infrastructure to production, complete this checklist to ensure a smooth deployment and avoid common issues.

## Prerequisites Verification

### ✅ AWS Account Setup

- [ ] AWS account with administrator access
- [ ] AWS CLI installed and configured: `aws --version`
- [ ] AWS credentials validated: `aws sts get-caller-identity`
- [ ] Target region selected (e.g., `us-west-2`)
- [ ] AWS CDK CLI installed: `cdk --version`

### ✅ Service Quotas

- [ ] EKS cluster quota sufficient (if deploying Druid)
- [ ] EC2 vCPU quota sufficient (if deploying Druid)
- [ ] Lambda concurrent execution quota sufficient (if deploying WebApp)
- [ ] SES production access requested (if deploying WebApp with email)

**See**: [Service Quotas →](service-quotas.md)

### ✅ Domain & DNS

- [ ] Domain registered (if using custom domain)
- [ ] Route 53 hosted zone created
- [ ] Hosted Zone ID captured for `cdk.context.json`

### ✅ Development Tools

- [ ] Node.js 18+ installed: `node --version`
- [ ] Maven 3.8+ installed (for Druid/WebApp): `mvn --version`
- [ ] Git installed and configured

## Bootstrap Stack

### ✅ AWS CDK Bootstrap

- [ ] CDK bootstrapped: `cdk bootstrap aws://ACCOUNT/REGION`
- [ ] CDK toolkit stack exists: `CDKToolkit`

### ✅ Fastish Bootstrap Stack

- [ ] Bootstrap repository cloned
- [ ] Dependencies installed: `npm install`
- [ ] Project built: `npm run build`
- [ ] `cdk.context.json` configured with synthesizer name
- [ ] Bootstrap stack deployed: `cdk deploy`
- [ ] Bootstrap outputs saved

## Architecture-Specific Checks

### For Druid Deployment

#### ✅ Grafana Cloud (Required)

- [ ] Grafana Cloud account created
- [ ] Grafana Cloud stack created (Prometheus, Loki, Tempo, Pyroscope)
- [ ] Access policy created with appropriate permissions
- [ ] Access policy token generated
- [ ] All Grafana endpoints collected:
  - [ ] Prometheus host and username
  - [ ] Loki host and username
  - [ ] Tempo host and username
  - [ ] Pyroscope host (optional)
  - [ ] Instance ID

**See**: [Grafana Setup →](optional-resources/grafana.md)

#### ✅ Druid Configuration

- [ ] Repository cloned: `aws-druid-infra`
- [ ] `cdk.context.template.json` copied to `cdk.context.json`
- [ ] Configuration fields filled:
  - [ ] `host:*` fields (host account details)
  - [ ] `hosted:*` fields (deployment configuration)
  - [ ] `hosted:eks:grafana:*` fields (all Grafana endpoints)
  - [ ] `hosted:eks:administrators` list (EKS admin users)
  - [ ] `hosted:eks:druid:release` name
- [ ] Availability zones verified for region

### For WebApp Deployment

#### ✅ Email Configuration (SES)

- [ ] SES production access requested (if sending >200 emails/day)
- [ ] Admin email verified in SES
- [ ] Route 53 hosted zone ID available
- [ ] Hosted zone ID added to `cdk.context.json`

#### ✅ WebApp Configuration

- [ ] Repository cloned: `aws-webapp-infra`
- [ ] `cdk.context.template.json` copied to `cdk.context.json`
- [ ] Configuration fields filled:
  - [ ] `host:*` fields
  - [ ] `hosted:*` fields
  - [ ] `hosted:ses:hosted:zone` (Route 53 Hosted Zone ID)
  - [ ] `hosted:ses:email` (admin email)

## Pre-Deployment Review

### ✅ Configuration Validation

- [ ] All required fields in `cdk.context.json` filled
- [ ] No placeholder values (e.g., `CHANGE_ME`, `000000000000`)
- [ ] AWS account IDs match your actual account
- [ ] Region matches intended deployment region
- [ ] Domain names are correct and owned by you

### ✅ Cost Awareness

- [ ] Reviewed cost estimates for chosen architecture
- [ ] Budget alerts configured in AWS
- [ ] Understanding of ongoing costs:
  - Druid: ~$300-500/month baseline
  - WebApp: ~$50-100/month baseline

### ✅ Security Review

- [ ] IAM roles reviewed
- [ ] No hardcoded credentials in configuration
- [ ] Encryption enabled for all data stores
- [ ] VPC security groups restrictive
- [ ] MFA enabled on AWS root account

## Deployment

### ✅ Druid Deployment

```bash
cd aws-druid-infra

# Build project
mvn clean install

# Preview changes
cdk diff

# Deploy (takes 30-50 minutes)
cdk deploy --require-approval never

# Verify deployment
kubectl get nodes
kubectl get pods -A
```

### ✅ WebApp Deployment

```bash
cd aws-webapp-infra/infra

# Build project
mvn clean install

# Preview changes
cdk diff

# Deploy (takes 20-30 minutes)
cdk deploy --require-approval never

# Verify deployment
aws cloudformation describe-stacks \
  --stack-name <stack-name>
```

## Post-Deployment

### ✅ DNS Configuration

**For WebApp (SES)**:
- [ ] MX record added to Route 53
- [ ] MAIL FROM domain records added
- [ ] DKIM records verified (auto-created if using CDK)

**For Custom Domains** (optional):
- [ ] API Gateway custom domain configured
- [ ] CloudFront/Amplify domain configured

### ✅ Verification

**Druid**:
- [ ] EKS cluster accessible: `kubectl cluster-info`
- [ ] All pods running: `kubectl get pods -A`
- [ ] Grafana dashboards showing data
- [ ] Druid router accessible

**WebApp**:
- [ ] Cognito User Pool created
- [ ] API Gateway endpoint accessible
- [ ] DynamoDB table created
- [ ] SES domain verified
- [ ] Test email sent successfully

### ✅ Monitoring Setup

- [ ] CloudWatch dashboards reviewed
- [ ] CloudWatch alarms configured
- [ ] Cost monitoring alerts set
- [ ] Grafana Cloud dashboards viewed (Druid)

## Troubleshooting

### Deployment Failed

**Check CloudFormation events**:
```bash
aws cloudformation describe-stack-events \
  --stack-name <stack-name> \
  --max-items 20
```

**Common issues**:
- Service quota exceeded → Request quota increase
- Missing permissions → Verify IAM permissions
- Invalid configuration → Review `cdk.context.json`
- Resource name conflict → Change `hosted:id` value

### Stack Stuck

**If deployment hangs**:
1. Check CloudFormation console for status
2. Review CloudFormation events for errors
3. Cancel deployment if necessary: `cdk destroy`
4. Fix issues and redeploy

## Rollback Plan

### Before Deployment

- [ ] Understand `cdk destroy` removes all resources
- [ ] Data backup strategy defined (if applicable)
- [ ] Rollback procedure documented

### If Deployment Fails

```bash
# Destroy stack
cdk destroy

# Fix configuration issues
# Re-deploy
cdk deploy
```

## Next Steps

After successful deployment:

1. **Druid**: [Configure Druid →](/druid/overview.md#post-deployment)
2. **WebApp**: [Integrate Frontend →](/webapp/ui.md)
3. **Both**: [Set up Monitoring →](/getting-started/monitoring.md) (if page exists)

## Related Documentation

- [Quick Start →](quickstart.md)
- [Configuration Guide →](configuration.md)
- [Service Quotas →](service-quotas.md)
- [Grafana Setup →](optional-resources/grafana.md)
- [Security Best Practices →](/faq/security.md)
