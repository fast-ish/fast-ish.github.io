# API Gateway

## Overview

Amazon API Gateway provides a managed REST API for the WebApp, integrating with Lambda functions for business logic and Cognito for authentication.

## Configuration

**Template (production/v1/conf.mustache)**:
```yaml
api:
  apigw:
    vpcName: {{hosted:id}}-webapp-vpc
    name: {{hosted:id}}-webapp-api
    description: "{{hosted:id}} api gateway for webapp resources"
    cloudwatchEnabled: true
    disableExecuteApi: false
    authorizationType: cognito
```

**CDK Construct**: [`RestApiConstruct`](https://github.com/fast-ish/cdk-common/blob/main/src/main/java/fasti/sh/execute/aws/apigw/RestApiConstruct.java)

## API Configuration

**API Name**: `{id}-webapp-api`

**API Type**: REST API

**Authorization**: Cognito User Pool

**Stage Name**: `v1`

### Stage Options

```yaml
stageOptions:
  stageName: v1
  description: "{{hosted:id}} api"
  loggingLevel: info
  tracingEnabled: true
  cachingEnabled: true
  dataTraceEnabled: true
  metricsEnabled: true
  throttlingBurstLimit: 20.0
  throttlingRateLimit: 50
```

**Throttling**:
- **Rate limit**: 50 requests/second (steady state)
- **Burst limit**: 20 requests (short spikes)

**Caching**: Enabled by default

**Tracing**: AWS X-Ray enabled

## Lambda Integration

### Base Layer

**Layer Name**: `base-api`

**Runtime**: Java 21

**Asset**: `../fn/layer/api/target/api.fn.shared-1.0.0.zip`

```yaml
baseLayer:
  name: base-api
  asset: "../fn/layer/api/target/api.fn.shared-1.0.0.zip"
  removalPolicy: destroy
  runtimes: [ "java21" ]
```

**Purpose**: Shared code across Lambda functions (utilities, models, clients)

### API Resources

**Template**: `production/v1/api/user.mustache`

**Example endpoints** (defined in resource template):
- `POST /users` - Create user
- `GET /users/{id}` - Get user details
- `PUT /users/{id}` - Update user
- `DELETE /users/{id}` - Delete user

Each endpoint integrates with a Lambda function.

## CloudWatch Logging

### Log Group

**Name**: `{id}-webapp-apigw-logs`

**Retention**: 1 day

```yaml
logGroup:
  name: {{hosted:id}}-webapp-apigw-logs
  type: standard
  retention: one_day
  removalPolicy: destroy
```

**Log Level**: `INFO`

**Data Trace**: Enabled (logs full request/response)

## Security

### Authentication Flow

1. **Client** requests access token from Cognito
2. **Cognito** returns JWT tokens
3. **Client** includes token in API request:
   ```
   Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
   ```
4. **API Gateway** validates JWT against Cognito User Pool
5. If valid, **Lambda** function executes
6. **Response** returned to client

### Authorization

```yaml
authorizationType: cognito
```

All API endpoints require valid Cognito JWT token.

**Unauthorized access** returns:
```json
{
  "message": "Unauthorized"
}
```

## Cost Estimate

**API Gateway REST API**:
- First 333 million requests/month: $3.50/million requests
- Additional requests: Volume discounts apply

**CloudWatch Logs**:
- First 5 GB: Free
- Additional: $0.50/GB

**Example** (1 million requests/month with moderate logging):
- API Gateway: ~$3.50/month
- CloudWatch Logs: ~$1/month
- **Total**: ~$5/month

## Monitoring

### CloudWatch Metrics

**Available metrics**:
- `Count` - Total API requests
- `4XXError` - Client errors
- `5XXError` - Server errors
- `Latency` - Request latency
- `IntegrationLatency` - Lambda execution time
- `CacheHitCount` / `CacheMissCount` - Cache performance

### X-Ray Tracing

**Enabled**: `tracingEnabled: true`

**View traces**:
```bash
aws xray get-trace-summaries \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s)
```

**What you see**:
- Request flow through API Gateway → Lambda → DynamoDB
- Latency breakdown by service
- Error identification

## Testing

### Get API Endpoint

```bash
# Get REST API ID
aws apigateway get-rest-apis \
  --query 'items[?name==`app-webapp-api`].id' \
  --output text

# API Endpoint format
https://{api-id}.execute-api.us-west-2.amazonaws.com/v1
```

### Test Request

```bash
# Get Cognito token first (see Authentication documentation)
TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."

# Call API
curl -X GET \
  https://abc123.execute-api.us-west-2.amazonaws.com/v1/users/123 \
  -H "Authorization: Bearer ${TOKEN}"
```

## Related Documentation

- [WebApp Overview →](overview.md)
- [Authentication →](authentication.md) - Cognito integration
- [DynamoDB →](dynamodb.md) - Data storage for API
- [VPC →](vpc.md) - Network configuration
