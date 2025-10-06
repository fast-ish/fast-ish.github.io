# Upgrading Guide

## Overview

This guide covers upgrading Fastish infrastructure components, from EKS versions to CDK itself.

## Upgrading EKS Cluster

### Before You Upgrade

**Review the EKS Release Notes:**
```bash
# Check current version
kubectl version --short

# View available versions
aws eks describe-addon-versions \
  --kubernetes-version 1.33 \
  --query 'addons[*].[addonName,addonVersions[0].addonVersion]'
```

**Backup Current State:**
```bash
# Export all resources
kubectl get all --all-namespaces -o yaml > backup-$(date +%Y%m%d).yaml

# Backup RDS
aws rds create-db-snapshot \
  --db-instance-identifier druid-metadata \
  --db-snapshot-identifier pre-upgrade-$(date +%Y%m%d)
```

### Upgrade Process (1.32 → 1.33)

#### 1. Update cdk.context.json
```json
{
  "hosted:eks:version": "1.33"  // Changed from 1.32
}
```

#### 2. Update Mustache Template
```yaml
# aws-druid-infra/src/main/resources/prototype/v1/conf.mustache
eks:
  version: "1.33"
```

#### 3. Deploy Control Plane Upgrade
```bash
# Synthesize changes
cd aws-druid-infra
cdk diff

# Deploy (control plane upgrades first)
cdk deploy --require-approval broadening
```

**Expected Timeline:** 20-30 minutes for control plane

#### 4. Upgrade Managed Addons

```bash
# Check addon versions
kubectl get daemonset -n kube-system

# Addons upgrade automatically after control plane
# Verify versions:
aws eks describe-addon \
  --cluster-name fff-eks \
  --addon-name vpc-cni \
  --query 'addon.addonVersion'
```

#### 5. Upgrade Node Groups

**Option 1: In-Place Update** (Karpenter automatically provisions new nodes)
```bash
# Karpenter detects new EKS version and provisions nodes with new AMI
# Gradually drains and replaces old nodes
kubectl get nodes --watch
```

**Option 2: Manual Node Replacement** (more controlled)
```bash
# Cordon old nodes
kubectl cordon <node-name>

# Drain workloads
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Karpenter provisions new node automatically
# Delete old node when drained
kubectl delete node <node-name>
```

#### 6. Verify Cluster Health

```bash
# Check node versions
kubectl get nodes -o wide

# Check pod status
kubectl get pods --all-namespaces

# Verify Druid functionality
kubectl port-forward -n druid svc/druid-router 8888:8888
curl http://localhost:8888/status/health
```

### Rollback Procedure

If upgrade fails:
```bash
# Rollback is NOT supported for EKS
# Must restore from backup or redeploy

# Option 1: Restore RDS snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier druid-metadata-restored \
  --db-snapshot-identifier pre-upgrade-20240115

# Option 2: Redeploy previous version
git checkout <previous-commit>
cdk deploy
```

**Best Practice:** Test upgrades in non-production first

### Upgrade Compatibility Matrix

| From Version | To Version | Notes |
|--------------|-----------|-------|
| 1.32 | 1.33 | Direct upgrade supported |
| 1.31 | 1.33 | Must upgrade to 1.32 first |
| 1.30 | 1.33 | Must upgrade 1.30→1.31→1.32→1.33 |

**Rule:** Can only upgrade one minor version at a time

## Upgrading Druid

### Druid Version Upgrade

Druid is deployed via Helm chart. To upgrade:

#### 1. Check Current Version
```bash
helm list -n druid

# Output:
# NAME      NAMESPACE  REVISION  UPDATED                    STATUS    CHART           APP VERSION
# streaming druid      1         2024-01-10 15:30:00 UTC    deployed  druid-0.1.0     28.0.0
```

#### 2. Update Helm Chart
```yaml
# aws-druid-infra/src/main/resources/prototype/v1/druid/values.mustache
# Update image tags
image:
  repository: apache/druid
  tag: "29.0.0"  # Update from 28.0.0
```

#### 3. Test in Staging
```bash
# Deploy to staging cluster
cdk deploy DruidStaging
```

#### 4. Rolling Update Production
```bash
# Deploy to production
cdk deploy

# Helm automatically performs rolling update
# Monitors update
kubectl rollout status statefulset druid-historical -n druid
```

#### 5. Verify Upgrade
```bash
# Check pod versions
kubectl get pods -n druid -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Verify Druid API
curl http://localhost:8888/druid/coordinator/v1/metadata/datasources
```

## Upgrading Lambda Functions (WebApp)

### Update Runtime Version

#### 1. Update Configuration
```yaml
# aws-webapp-infra/src/main/resources/production/v1/conf.mustache
lambda:
  runtime: NODEJS_20_X  # Upgrade from NODEJS_18_X
```

#### 2. Update Dependencies
```bash
# Update package.json in Lambda function code
cd fn/api/user
npm update
npm audit fix
```

#### 3. Test Locally
```bash
# Test with SAM Local
sam local invoke UserApiFunction -e events/get-user.json
```

#### 4. Deploy
```bash
cd aws-webapp-infra/infra
mvn clean install
cdk deploy
```

#### 5. Monitor Deployment
```bash
# Watch CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=webapp-user-api \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### Rollback Lambda
```bash
# List versions
aws lambda list-versions-by-function \
  --function-name webapp-user-api

# Rollback to previous version
aws lambda update-alias \
  --function-name webapp-user-api \
  --name production \
  --function-version <previous-version>
```

## Upgrading RDS PostgreSQL

### Minor Version Upgrade (14.10 → 14.11)

**Automatic during maintenance window:**
```bash
# Enable auto minor version upgrade
aws rds modify-db-instance \
  --db-instance-identifier druid-metadata \
  --auto-minor-version-upgrade \
  --preferred-maintenance-window sun:03:00-sun:04:00
```

### Major Version Upgrade (14.x → 15.x)

#### 1. Backup Database
```bash
aws rds create-db-snapshot \
  --db-instance-identifier druid-metadata \
  --db-snapshot-identifier pre-upgrade-postgres-15
```

#### 2. Test in Staging
```bash
# Restore snapshot to staging
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier druid-metadata-staging \
  --db-snapshot-identifier pre-upgrade-postgres-15

# Upgrade staging
aws rds modify-db-instance \
  --db-instance-identifier druid-metadata-staging \
  --engine-version 15.5 \
  --allow-major-version-upgrade \
  --apply-immediately
```

#### 3. Validate Staging
```bash
# Connect and test
psql -h druid-metadata-staging.xxx.rds.amazonaws.com -U druid -d druid

# Run queries
SELECT version();
SELECT * FROM druid_segments LIMIT 10;
```

#### 4. Schedule Production Upgrade
```bash
# Update cdk.context.json
{
  "hosted:rds:engine:version": "15.5"
}

# Deploy during maintenance window
cdk deploy
```

**Downtime:** ~15-30 minutes for major version upgrade

## Upgrading AWS CDK

### CDK Version Upgrade

#### 1. Check Current CDK Version
```bash
cdk --version
# Output: 2.176.0
```

#### 2. Update CDK CLI
```bash
npm install -g aws-cdk@latest
```

#### 3. Update Project Dependencies

**For bootstrap repo (TypeScript):**
```bash
cd bootstrap
npm update aws-cdk-lib constructs
```

**For Java projects:**
```xml
<!-- Update pom.xml -->
<properties>
    <cdk.version>2.180.0</cdk.version>
</properties>
```

```bash
cd cdk-common
mvn clean install

cd aws-druid-infra
mvn clean install

cd aws-webapp-infra
mvn clean install
```

#### 4. Test Synthesis
```bash
cdk synth
```

#### 5. Review Diff
```bash
cdk diff
# Review changes carefully
# CDK may change resource physical IDs (causes replacement)
```

#### 6. Deploy
```bash
# Deploy with approval
cdk deploy --require-approval broadening
```

### Breaking Changes

**CDK 2.150.0 → 2.180.0:**
- EKS API changes
- Lambda runtime deprecations
- New security defaults

**Always review:**
- [CDK Changelog](https://github.com/aws/aws-cdk/releases)
- Migration guides for major versions

## Upgrading Helm Charts

### Karpenter Upgrade

#### 1. Check Current Version
```bash
helm list -n kube-system | grep karpenter
```

#### 2. Update Configuration
```yaml
# aws-druid-infra/src/main/resources/prototype/v1/eks/addons.mustache
karpenter:
  version: v0.34.0  # Update from v0.33.0
```

#### 3. Deploy
```bash
cd aws-druid-infra
cdk deploy

# Helm automatically upgrades
kubectl rollout status deployment karpenter -n kube-system
```

### Grafana Agent Upgrade

```yaml
# Update in addons.mustache
grafana:
  chart:
    version: v1.2.0  # Update from v1.1.0
```

## Upgrade Schedule Recommendations

### Monthly
- [ ] Update Lambda dependencies (npm/pip packages)
- [ ] Apply security patches
- [ ] Review CloudWatch Logs retention

### Quarterly
- [ ] Upgrade Helm charts (Karpenter, cert-manager)
- [ ] Update Druid version (if stable release available)
- [ ] RDS minor version updates (automatic in maintenance window)

### Annually
- [ ] EKS version upgrade (stay within N-2 versions)
- [ ] RDS major version upgrade
- [ ] CDK major version upgrade
- [ ] Review and update dependencies

## Upgrade Checklist Template

### Pre-Upgrade
- [ ] Review release notes and breaking changes
- [ ] Backup all data (RDS snapshots, DynamoDB exports)
- [ ] Test upgrade in staging environment
- [ ] Document current versions
- [ ] Schedule maintenance window
- [ ] Notify users of upcoming downtime

### During Upgrade
- [ ] Deploy to staging first
- [ ] Validate functionality in staging
- [ ] Monitor CloudWatch metrics
- [ ] Deploy to production
- [ ] Run smoke tests

### Post-Upgrade
- [ ] Verify all services healthy
- [ ] Check application logs for errors
- [ ] Monitor performance metrics
- [ ] Update documentation
- [ ] Delete old backups (after 7 days of stable operation)

## Troubleshooting Upgrades

### Issue: EKS upgrade stuck
```bash
# Check cluster status
aws eks describe-cluster --name fff-eks --query 'cluster.status'

# Check update status
aws eks describe-update \
  --name fff-eks \
  --update-id <update-id>
```

### Issue: Pods not starting after upgrade
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check node compatibility
kubectl get nodes -o wide
```

### Issue: RDS upgrade fails
```bash
# Check upgrade status
aws rds describe-db-instances \
  --db-instance-identifier druid-metadata \
  --query 'DBInstances[0].[DBInstanceStatus,EngineVersion]'

# Restore from snapshot if needed
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier druid-metadata-restored \
  --db-snapshot-identifier pre-upgrade-postgres-15
```

## Next Steps

- [Migration Checklist →](migration-checklist.md)
- [Disaster Recovery →](disaster-recovery.md)
- [Troubleshooting →](/troubleshooting/common-errors.md)
