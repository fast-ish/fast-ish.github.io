# Support & Resources

## Getting Help

### Documentation

**Start here** for most questions:
- [Quick Start →](/getting-started/quickstart.md) - Get running in 10 minutes
- [Core Concepts →](/getting-started/concepts.md) - Understand the architecture
- [Druid Overview →](/druid/overview.md) - Apache Druid on EKS
- [WebApp Overview →](/webapp/overview.md) - Multi-tenant SaaS platform

### GitHub Issues

**Report bugs or request features**:
[https://github.com/fast-ish/fast-ish.github.io/issues](https://github.com/fast-ish/fast-ish.github.io/issues)

**Before creating an issue**:
1. Search existing issues
2. Provide reproduction steps
3. Include relevant logs
4. Specify infrastructure version

**Issue template**:
```markdown
**Environment**:
- Architecture: Druid / WebApp / Both
- AWS Region: us-west-2
- CDK Version: 2.176.0
- Component: VPC / EKS / Cognito / etc.

**Problem**:
[Describe the issue]

**Expected Behavior**:
[What should happen]

**Actual Behavior**:
[What actually happens]

**Logs**:
[Paste relevant CloudFormation/kubectl/AWS CLI output]

**Steps to Reproduce**:
1. Deploy with configuration X
2. Run command Y
3. See error Z
```

## Community

### Discussions

**General questions and discussions**:
[GitHub Discussions](https://github.com/fast-ish/fast-ish.github.io/discussions) (if enabled)

**Topics**:
- Architecture decisions
- Best practices
- Use case sharing
- Feature requests

### Contributing

**We welcome contributions!**

**Ways to contribute**:
- Documentation improvements
- Bug reports
- Feature suggestions
- Code contributions (CDK constructs, templates)

**Contribution process**:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

**See**: [Contributing Guide](/workflow/contributors.md)

## AWS Support

### AWS Support Plans

**Free (Basic)**:
- AWS documentation
- Community forums
- Service health dashboard

**Developer ($29/month)**:
- Business hours email support
- Unlimited cases
- < 12 hour response time

**Business ($100+/month)**:
- 24/7 phone/email/chat support
- < 1 hour response for critical issues
- AWS Trusted Advisor

**Enterprise ($15,000+/month)**:
- Dedicated Technical Account Manager
- < 15 minute response for critical issues
- Infrastructure Event Management

**Recommendation**: Developer or Business plan for production deployments

### Creating AWS Support Cases

**For infrastructure issues**:
1. Sign in to AWS Console
2. Navigate to Support → Create case
3. Select service (e.g., "Amazon EKS", "AWS CloudFormation")
4. Provide details and logs

**Common case types**:
- Service quota increase requests
- Deployment failures
- Performance issues
- Security inquiries

## Troubleshooting

### Common Issues

#### Deployment Failures

**CloudFormation stack creation failed**:
```bash
# View stack events
aws cloudformation describe-stack-events \
  --stack-name <stack-name> \
  --max-items 20

# Look for CREATE_FAILED status
```

**Common causes**:
- Service quota exceeded → [Request increase](/getting-started/service-quotas.md)
- Invalid configuration → Review `cdk.context.json`
- Insufficient IAM permissions → Verify administrator access
- Resource name conflicts → Change `hosted:id` value

#### EKS Issues

**Pods not starting**:
```bash
# Check pod status
kubectl get pods -A

# View pod logs
kubectl logs -n <namespace> <pod-name>

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>
```

**Node issues**:
```bash
# Check node status
kubectl get nodes

# Describe node
kubectl describe node <node-name>
```

#### WebApp Issues

**Cognito authentication failing**:
- Verify User Pool and User Pool Client exist
- Check API Gateway authorizer configuration
- Validate JWT token format

**API Gateway errors**:
```bash
# Check CloudWatch Logs
aws logs tail /aws/apigateway/<api-id> --follow
```

**DynamoDB access errors**:
- Verify Lambda IAM role has DynamoDB permissions
- Check table name matches configuration
- Verify VPC endpoints (if using)

### Diagnostic Commands

**Check AWS credentials**:
```bash
aws sts get-caller-identity
```

**List CloudFormation stacks**:
```bash
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE
```

**Check CDK context**:
```bash
cat cdk.context.json | jq .
```

**Validate IAM permissions**:
```bash
aws iam simulate-principal-policy \
  --policy-source-arn <role-arn> \
  --action-names eks:DescribeCluster \
  --resource-arns '*'
```

## Learning Resources

### AWS Documentation

- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/)
- [Amazon Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [Amazon DynamoDB Guide](https://docs.aws.amazon.com/dynamodb/)
- [Apache Druid Documentation](https://druid.apache.org/docs/latest/design/)

### Recommended Learning Paths

**For CDK**:
1. [AWS CDK Workshop](https://cdkworkshop.com/)
2. [CDK Patterns](https://cdkpatterns.com/)

**For Kubernetes/EKS**:
1. [EKS Workshop](https://www.eksworkshop.com/)
2. [Kubernetes Documentation](https://kubernetes.io/docs/home/)

**For Druid**:
1. [Druid Quickstart](https://druid.apache.org/docs/latest/tutorials/)
2. [Druid Design](https://druid.apache.org/docs/latest/design/)

## Version Information

### Current Versions

**Infrastructure**:
- AWS CDK: 2.176.0
- EKS: 1.33
- Druid: Latest (via Helm chart)

**Dependencies**:
- Node.js: 18+
- Maven: 3.8+
- Java: 21

### Release Notes

Check [GitHub Releases](https://github.com/fast-ish) for:
- New features
- Bug fixes
- Breaking changes
- Migration guides

## Contact

### General Inquiries

For general questions about Fastish:
- GitHub Issues: Technical questions and bug reports
- GitHub Discussions: Community discussions
- Email: (if available)

### Security Issues

**Do not** create public GitHub issues for security vulnerabilities.

**Instead**:
- Email security contact (if available)
- Follow responsible disclosure practices
- Allow time for patches before public disclosure

## Feedback

We value your feedback to improve Fastish!

**Ways to provide feedback**:
- GitHub Issues for feature requests
- GitHub Discussions for architecture feedback
- Pull requests for documentation improvements
- Star the repository if you find it useful

## License

Fastish is released under the [MIT License](https://opensource.org/licenses/MIT).

**You are free to**:
- Use commercially
- Modify
- Distribute
- Use privately

**Conditions**:
- Include license and copyright notice
- Provide attribution

**See**: Repository LICENSE file for full details

---

**Thank you for using Fastish!** We're committed to providing a robust, well-documented infrastructure platform for your AWS deployments.
