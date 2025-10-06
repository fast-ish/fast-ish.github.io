# Common Errors

## Overview

This guide covers the most frequently encountered errors when deploying Fastish infrastructure and their solutions.

## CloudFormation Errors

### Error: "Resource creation cancelled"

**Full message**:
```
Resource creation cancelled
```

**Cause**: CloudFormation stack rollback triggered by another resource failure

**Solution**:
```bash
# View full error details
aws cloudformation describe-stack-events \
  --stack-name <stack-name> \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]' \
  --output table

# Look for the root cause error
```

### Error: "No export named X found"

**Full message**:
```
No export named fastish-prod-VpcId found. Rollback requested by user.
```

**Cause**: Dependent stack trying to import from non-existent export

**Solution**:
1. Verify bootstrap stack deployed: `aws cloudformation list-stacks`
2. Check export exists: `aws cloudformation list-exports`
3. Ensure stack names match in configuration

### Error: "Rate exceeded"

**Full message**:
```
Rate exceeded (Service: AmazonCloudFormation; Status Code: 400; Error Code: Throttling)
```

**Cause**: Too many CloudFormation API calls

**Solution**: Wait 1-2 minutes and retry deployment

## CDK Errors

### Error: "This stack uses assets, so the toolkit stack must be deployed"

**Full message**:
```
This stack uses assets, so the toolkit stack must be deployed to the environment
```

**Cause**: AWS CDK not bootstrapped in account/region

**Solution**:
```bash
# Bootstrap CDK (one-time per account/region)
cdk bootstrap aws://123456789012/us-west-2
```

### Error: "Need to perform AWS calls for account X, but no credentials configured"

**Cause**: AWS credentials not configured or expired

**Solution**:
```bash
# Verify credentials
aws sts get-caller-identity

# If expired, reconfigure
aws configure
```

### Error: "Cannot find context provider X"

**Full message**:
```
Cannot find context provider vpc-provider
```

**Cause**: Missing context value in `cdk.context.json`

**Solution**: Add required context to `cdk.context.json`:
```json
{
  "availability-zones:account=123456789012:region=us-west-2": [
    "us-west-2a",
    "us-west-2b",
    "us-west-2c"
  ]
}
```

## EKS Errors

### Error: "Error: Unauthorized"

**Full message**:
```
error: You must be logged in to the server (Unauthorized)
```

**Cause**: kubeconfig not configured or expired

**Solution**:
```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name fff-eks \
  --region us-west-2

# Verify access
kubectl get nodes
```

### Error: "No resources found"

**When running**: `kubectl get nodes`

**Cause**: Wrong cluster context or cluster not ready

**Solution**:
```bash
# Check current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch to correct cluster
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

### Error: "nodes have insufficient memory/cpu"

**Full message**:
```
0/2 nodes are available: 2 Insufficient cpu, 2 Insufficient memory
```

**Cause**: Pods requesting more resources than available on nodes

**Solution**:
```bash
# Check node capacity
kubectl describe nodes

# Scale up node group (if using Karpenter, it auto-scales)
# Or reduce pod resource requests
```

## Lambda Errors

### Error: "Task timed out after X seconds"

**Cause**: Lambda function timeout exceeded

**Solution**:
1. Increase timeout in Lambda configuration (max 15 minutes)
2. Optimize function code
3. Check for blocking operations (database queries, external API calls)

### Error: "Unable to import module"

**Full message**:
```
Unable to import module 'index': No module named 'requests'
```

**Cause**: Missing Python/Node dependencies

**Solution**: Include dependencies in Lambda deployment package or layer

### Error: "The provided execution role does not have permissions"

**Cause**: Lambda IAM role missing required permissions

**Solution**:
```bash
# Check Lambda role
aws lambda get-function --function-name <function-name> \
  --query 'Configuration.Role'

# Verify role has required policies
aws iam list-attached-role-policies --role-name <role-name>
```

## DynamoDB Errors

### Error: "ResourceNotFoundException: Requested resource not found"

**Cause**: Table doesn't exist or wrong table name

**Solution**:
```bash
# List tables
aws dynamodb list-tables

# Verify table name matches code
# Check cdk.context.json for correct hosted:id
```

### Error: "ProvisionedThroughputExceededException"

**Cause**: Read/write capacity exceeded (only for provisioned mode)

**Solution**: WebApp uses on-demand billing by default (no capacity limits). If you changed to provisioned, increase capacity or switch back to on-demand.

### Error: "ValidationException: One or more parameter values were invalid"

**Cause**: Invalid attribute type or missing required key

**Solution**: Verify partition key format matches table schema (e.g., `id` must be String)

## Cognito Errors

### Error: "User pool X not found"

**Cause**: User pool doesn't exist or wrong region

**Solution**:
```bash
# List user pools in region
aws cognito-idp list-user-pools \
  --max-results 10 \
  --region us-west-2

# Verify region matches deployment
```

### Error: "Invalid password: Password did not conform to policy"

**Cause**: Password doesn't meet Cognito password policy

**Solution**: Check User Pool password policy requirements (min length, special characters, etc.)

### Error: "User is not confirmed"

**Cause**: User hasn't verified email/phone

**Solution**:
```bash
# Manually confirm user (admin)
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id <pool-id> \
  --username <username>
```

## API Gateway Errors

### Error: "{"message":"Unauthorized"}"

**Cause**: Missing or invalid Cognito JWT token

**Solution**:
1. Verify Authorization header format: `Authorization: Bearer <token>`
2. Check token hasn't expired
3. Verify token is from correct User Pool

### Error: "{"message":"Missing Authentication Token"}"

**Cause**: Invalid API endpoint or missing Authorization header

**Solution**:
1. Verify API endpoint URL is correct
2. Ensure Authorization header is included
3. Check API Gateway stage name matches (e.g., `/v1/users`)

### Error: "Execution failed due to configuration error: Invalid permissions on Lambda function"

**Cause**: API Gateway doesn't have permission to invoke Lambda

**Solution**: CDK creates this automatically. If error occurs, redeploy stack.

## SES Errors

### Error: "Email address is not verified"

**Full message**:
```
MessageRejected: Email address is not verified. The following identities failed the check in region US-WEST-2: noreply@example.com
```

**Cause**: SES in sandbox mode or email not verified

**Solution**:
```bash
# Verify email address
aws ses verify-email-identity \
  --email-address noreply@example.com

# Check verification status
aws ses get-identity-verification-attributes \
  --identities noreply@example.com

# Request production access (removes sandbox limits)
# Go to SES Console → Account dashboard → Request production access
```

### Error: "Daily message quota exceeded"

**Cause**: Exceeded 200 emails/day (sandbox limit)

**Solution**: Request SES production access (see above)

### Error: "Maximum sending rate exceeded"

**Cause**: Sending too fast (sandbox: 1 email/second)

**Solution**: Implement rate limiting in application or request production access

## VPC/Networking Errors

### Error: "Cannot reach endpoint X"

**Cause**: Security group blocking traffic or wrong subnet

**Solution**:
```bash
# Check security groups
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=<vpc-id>"

# Verify route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=<vpc-id>"

# Check NAT Gateways are running
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available"
```

### Error: "UnauthorizedOperation: You are not authorized to perform this operation"

**Cause**: IAM permissions insufficient

**Solution**: Verify your IAM user/role has administrator access or specific permissions for the service

## Maven/Build Errors

### Error: "Failed to execute goal on project"

**Full message**:
```
Failed to execute goal on project aws-druid-infra: Could not resolve dependencies
```

**Cause**: Maven dependencies not downloaded

**Solution**:
```bash
# Clean and rebuild
mvn clean install -U

# If still failing, check internet connectivity
# Verify Maven settings.xml if using custom repository
```

### Error: "Java version X not supported"

**Cause**: Wrong Java version

**Solution**:
```bash
# Check Java version
java -version

# Fastish requires Java 21
# Install Java 21 if needed
```

## General Debugging Commands

### Check CloudFormation Stack Status
```bash
aws cloudformation describe-stacks \
  --stack-name <stack-name> \
  --query 'Stacks[0].StackStatus'
```

### View Last 20 CloudFormation Events
```bash
aws cloudformation describe-stack-events \
  --stack-name <stack-name> \
  --max-items 20 \
  --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' \
  --output table
```

### Check EKS Cluster Status
```bash
aws eks describe-cluster \
  --name <cluster-name> \
  --query 'cluster.status'
```

### View Pod Logs
```bash
kubectl logs -n <namespace> <pod-name> --tail=100 --follow
```

### Check Lambda Logs
```bash
aws logs tail /aws/lambda/<function-name> --follow
```

## Getting More Help

If your error isn't listed here:

1. **Search AWS documentation** for the specific error code
2. **Check CloudFormation events** for root cause
3. **Review [Support page](/support.md)** for help resources
4. **Create GitHub issue** with error details

## Related Documentation

- [Deployment Failures →](deployment-failures.md)
- [Networking Issues →](networking-issues.md)
- [EKS Pod Failures →](eks-pod-failures.md)
- [Support →](/support.md)
