# Contributing to Fastish

## Overview

Thank you for your interest in contributing to Fastish! This guide covers everything you need to know to contribute effectively.

## Quick Links

- [Development Workflow →](development-workflow.md)
- [Pull Request Guidelines →](pr-guidelines.md)
- [Code Style Guide →](code-style.md)
- [Testing Guide →](testing.md)

## Getting Started

### Prerequisites

**Required Tools:**
- Java 21+ ([SDKMAN](https://sdkman.io/) recommended)
- Maven 3.8+
- Node.js 20+ (for bootstrap repo)
- AWS CLI configured
- AWS CDK CLI: `npm install -g aws-cdk`
- kubectl (for EKS development)
- Docker (for local testing)

**Optional Tools:**
- IntelliJ IDEA (recommended for Java)
- VS Code (for TypeScript/documentation)
- k9s (Kubernetes management)
- Lens (Kubernetes IDE)

### Repository Structure

```
fastish/
├── bootstrap/              # TypeScript CDK app for bootstrapping
├── cdk-common/            # Shared Java CDK constructs (47 constructs)
├── aws-druid-infra/       # Druid infrastructure (Java CDK)
├── aws-webapp-infra/      # WebApp infrastructure (Java CDK)
├── spaz-infra/            # CI/CD workflows
└── fast-ish.github.io/    # Documentation (this repo)
```

### Initial Setup

#### 1. Clone Repositories

```bash
# Core infrastructure
git clone https://github.com/fast-ish/bootstrap.git
git clone https://github.com/fast-ish/cdk-common.git
git clone https://github.com/fast-ish/aws-druid-infra.git
git clone https://github.com/fast-ish/aws-webapp-infra.git

# Documentation
git clone https://github.com/fast-ish/fast-ish.github.io.git
```

#### 2. Build Common Library

```bash
cd cdk-common
mvn clean install
```

#### 3. Build Infrastructure Projects

```bash
# Druid
cd ../aws-druid-infra
mvn clean install

# WebApp
cd ../aws-webapp-infra
mvn clean install
```

#### 4. Configure AWS Credentials

```bash
aws configure
# Or use AWS SSO:
aws sso login --profile fastish
```

## Contribution Types

### 1. Bug Fixes
- Fix CloudFormation deployment issues
- Resolve CDK construct errors
- Fix documentation inaccuracies

### 2. New Features
- Add new CDK constructs
- Implement new AWS services
- Enhance existing infrastructure

### 3. Documentation
- Improve existing docs
- Add new guides
- Fix typos and clarity issues

### 4. Testing
- Add unit tests
- Improve integration tests
- Test deployment scenarios

## Development Workflow

### 1. Create a Branch

```bash
git checkout -b feature/add-vpc-endpoints
# or
git checkout -b fix/rds-backup-retention
# or
git checkout -b docs/improve-eks-guide
```

### 2. Make Changes

**For CDK Constructs:**
```bash
cd cdk-common
# Edit construct
vi src/main/java/fasti/sh/execute/aws/vpc/VpcConstruct.java

# Run tests
mvn test

# Install locally
mvn clean install
```

**For Infrastructure:**
```bash
cd aws-druid-infra
# Edit stack
vi src/main/java/fasti/sh/druid/stack/DeploymentStack.java

# Synthesize
cdk synth

# Preview changes
cdk diff
```

**For Documentation:**
```bash
cd fast-ish.github.io
# Edit markdown
vi druid/overview.md

# Preview locally (if using docsify)
npm install -g docsify-cli
docsify serve .
```

### 3. Test Locally

**CDK Synthesis Test:**
```bash
# Ensure CDK synth works
cdk synth > /dev/null
echo $?  # Should be 0
```

**Deploy to Test Account:**
```bash
# Use separate AWS account for testing
export AWS_PROFILE=fastish-dev
cdk deploy --require-approval never
```

### 4. Commit Changes

```bash
git add .
git commit -m "feat: add VPC endpoints for ECR

- Add ECR API endpoint
- Add ECR DKR endpoint
- Add S3 gateway endpoint
- Update documentation

Closes #123"
```

**Commit Message Format:**
```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `refactor`: Code refactoring
- `test`: Add/update tests
- `chore`: Maintenance tasks

### 5. Push and Create PR

```bash
git push origin feature/add-vpc-endpoints

# Create PR via GitHub CLI
gh pr create \
  --title "feat: add VPC endpoints for ECR" \
  --body "Closes #123"
```

## Testing Guidelines

### Unit Tests

**Java (JUnit 5):**
```java
@Test
void testVpcConstructCreatesSubnets() {
    var app = new App();
    var stack = new Stack(app, "TestStack");
    var conf = new NetworkConf(
        "test-vpc",
        "10.0.0.0/16",
        2,
        List.of(/* subnets */)
    );

    var vpc = new VpcConstruct(stack, common, conf);

    var template = Template.fromStack(stack);
    template.hasResourceProperties("AWS::EC2::VPC", Map.of(
        "CidrBlock", "10.0.0.0/16"
    ));
}
```

**Run Tests:**
```bash
mvn test
```

### Integration Tests

**CDK Synthesis:**
```bash
# Test that CDK synth works with various configurations
cd aws-druid-infra

# Test prototype config
cdk synth -c hosted:environment=prototype

# Test production config
cdk synth -c hosted:environment=production
```

**Deployment Test:**
```bash
# Deploy to isolated test account
export AWS_PROFILE=fastish-test
cdk deploy --all --require-approval never

# Run smoke tests
kubectl get pods -A

# Cleanup
cdk destroy --all --force
```

### Documentation Tests

**Link Validation:**
```bash
# Check for broken links
npm install -g markdown-link-check
markdown-link-check README.md
```

**Spelling:**
```bash
# Check spelling
npm install -g cspell
cspell "**/*.md"
```

## Code Review Process

### Submitting for Review

1. **Ensure CI passes:**
   - All tests pass
   - No linting errors
   - CDK synth succeeds

2. **Request reviewers:**
   - Assign relevant maintainers
   - Tag with appropriate labels

3. **Respond to feedback:**
   - Address all comments
   - Push updates to same branch
   - Re-request review when ready

### Review Checklist

**For Reviewers:**
- [ ] Code follows style guidelines
- [ ] Tests are comprehensive
- [ ] Documentation is updated
- [ ] No security issues (secrets, permissions)
- [ ] CDK diff is reviewed
- [ ] Breaking changes are documented

## Release Process

### Versioning

Fastish uses semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR:** Breaking changes (e.g., 1.0.0 → 2.0.0)
- **MINOR:** New features (e.g., 1.0.0 → 1.1.0)
- **PATCH:** Bug fixes (e.g., 1.0.0 → 1.0.1)

### Creating a Release

```bash
# 1. Update version in pom.xml
vi pom.xml
# Change <version>1.1.0</version> to <version>1.2.0</version>

# 2. Commit version bump
git add pom.xml
git commit -m "chore: bump version to 1.2.0"

# 3. Create tag
git tag -a v1.2.0 -m "Release v1.2.0

Features:
- Add VPC endpoints
- Improve Karpenter configuration

Bug Fixes:
- Fix RDS backup retention
"

# 4. Push tag
git push origin v1.2.0

# 5. Create GitHub release
gh release create v1.2.0 \
  --title "v1.2.0" \
  --notes "See CHANGELOG.md for details"
```

### Changelog

Update `CHANGELOG.md`:
```markdown
## [1.2.0] - 2024-01-15

### Added
- VPC endpoints for ECR (#123)
- Karpenter consolidation feature (#124)

### Fixed
- RDS backup retention configuration (#125)

### Changed
- Updated EKS version to 1.33 (#126)
```

## Community

### Communication Channels

- **GitHub Issues:** Bug reports and feature requests
- **GitHub Discussions:** General questions and ideas
- **Pull Requests:** Code contributions

### Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Help others learn and grow
- Follow the [Contributor Covenant](https://www.contributor-covenant.org/)

### Getting Help

**For Contributors:**
1. Read the documentation
2. Search existing issues
3. Ask in GitHub Discussions
4. Create a new issue if needed

**For Maintainers:**
1. Review PRs within 3 business days
2. Provide clear, actionable feedback
3. Merge when CI passes and approved

## Recognition

Contributors are recognized in:
- `CONTRIBUTORS.md` file
- GitHub contributors page
- Release notes

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (Apache 2.0).

## Next Steps

- [Development Workflow →](development-workflow.md)
- [Pull Request Guidelines →](pr-guidelines.md)
- [Code Style Guide →](code-style.md)
- [Testing Guide →](testing.md)
