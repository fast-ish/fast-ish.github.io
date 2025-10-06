# EKS Pod Failures

## Pod Status Guide

### ImagePullBackOff

**Symptoms**:
```bash
kubectl get pods
# NAME                     READY   STATUS             RESTARTS
# druid-coordinator-0      0/1     ImagePullBackOff   0
```

**Diagnosis**:
```bash
kubectl describe pod <pod-name> -n <namespace>

# Look for:
# Failed to pull image "xxxx": 403 Forbidden
# Failed to pull image "xxxx": manifest unknown
```

**Solutions**:

**1. Image doesn't exist**:
```bash
# Verify image in ECR
aws ecr list-images \
  --repository-name <repo-name>
```

**2. No ECR permissions**:
```bash
# Check node IAM role has AmazonEC2ContainerRegistryReadOnly
aws iam list-attached-role-policies --role-name <node-role>
```

**3. Add VPC endpoints** (see [Networking Issues](/troubleshooting/networking-issues.md#pods-cannot-pull-images-from-ecr))

### CrashLoopBackOff

**Symptoms**: Pod repeatedly starting and crashing

```bash
kubectl get pods
# NAME                READY   STATUS             RESTARTS
# druid-broker-0      0/1     CrashLoopBackOff   5
```

**Diagnosis**:
```bash
# View pod logs
kubectl logs <pod-name> -n <namespace>

# View previous pod logs (if restarted)
kubectl logs <pod-name> -n <namespace> --previous

# Describe pod for events
kubectl describe pod <pod-name> -n <namespace>
```

**Common causes**:

**Application error**:
- Check logs for stack traces
- Verify configuration (ConfigMaps, Secrets)

**Missing dependencies**:
- Database unreachable (RDS, PostgreSQL)
- Message queue unavailable (MSK, Kafka)

**Resource limits**:
```yaml
# Pod killed by OOMKiller
Status:       Failed
Reason:       OOMKilled
```

**Solution**: Increase memory limits or optimize application

### Pending

**Symptoms**: Pod stuck in Pending state

```bash
kubectl get pods
# NAME                READY   STATUS    RESTARTS
# druid-historical-0  0/1     Pending   0
```

**Diagnosis**:
```bash
kubectl describe pod <pod-name> -n <namespace>

# Common messages:
# - "Insufficient cpu"
# - "Insufficient memory"
# - "No nodes available"
# - "PersistentVolumeClaim not bound"
```

**Solutions**:

**1. Insufficient resources**:
```bash
# Check node capacity
kubectl describe nodes

# Karpenter should auto-scale (check Karpenter logs)
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter
```

**2. PVC not bound**:
```bash
# Check PVC status
kubectl get pvc -n <namespace>

# If Pending, check StorageClass
kubectl describe sc ebs-sc

# Verify EBS CSI driver running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
```

**3. Node selector mismatch**:
```bash
# Check pod nodeSelector
kubectl get pod <pod-name> -o yaml | grep -A5 nodeSelector

# Verify matching nodes exist
kubectl get nodes --show-labels
```

### CreateContainerConfigError

**Symptoms**:
```bash
kubectl get pods
# NAME                READY   STATUS                       RESTARTS
# druid-coordinator-0 0/1     CreateContainerConfigError   0
```

**Diagnosis**:
```bash
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - Secret not found
# - ConfigMap not found
# - Volume mount path invalid
```

**Solutions**:

**Missing Secret**:
```bash
# List secrets in namespace
kubectl get secrets -n <namespace>

# Check if referenced secret exists
kubectl get secret <secret-name> -n <namespace>

# For Druid, verify AWS Secrets Manager secrets created
aws secretsmanager list-secrets \
  --query 'SecretList[?contains(Name, `druid`)]'
```

**Missing ConfigMap**:
```bash
kubectl get configmap -n <namespace>
```

### OOMKilled

**Symptoms**: Pod killed due to out-of-memory

```bash
kubectl describe pod <pod-name> -n <namespace>
# Last State:     Terminated
#   Reason:       OOMKilled
#   Exit Code:    137
```

**Diagnosis**:
```bash
# Check memory usage before pod was killed
kubectl top pod <pod-name> -n <namespace>

# View resource limits
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A10 resources
```

**Solutions**:

**1. Increase memory limits** (in Helm values or pod spec)

**2. Check for memory leaks**:
```bash
# For Java applications, enable heap dump on OOM
# Add to JVM args: -XX:+HeapDumpOnOutOfMemoryError
```

**3. Optimize application memory usage**

### Evicted

**Symptoms**: Pod evicted by kubelet

```bash
kubectl get pods --field-selector=status.phase=Failed
# NAME                READY   STATUS     RESTARTS
# druid-broker-0      0/1     Evicted    0
```

**Diagnosis**:
```bash
kubectl describe pod <pod-name> -n <namespace>

# Common reasons:
# - "The node was low on resource: memory"
# - "The node was low on resource: ephemeral-storage"
```

**Solutions**:

**Low memory**:
```bash
# Check node allocatable resources
kubectl describe node <node-name> | grep -A5 Allocatable

# Karpenter should provision new nodes
# If not, check Karpenter configuration
```

**Low disk space**:
```bash
# Check node disk usage
kubectl exec -it <pod-on-node> -- df -h

# Clean up unused images
kubectl exec -it <pod-on-node> -- crictl rmi --prune
```

## Druid-Specific Issues

### Coordinator Won't Start

**Symptoms**: Coordinator pod CrashLoopBackOff

**Check logs**:
```bash
kubectl logs -n druid <coordinator-pod> | grep -i error
```

**Common issues**:

**1. Cannot connect to metadata database**:
```
Error: Could not connect to PostgreSQL
```

**Solution**: Verify RDS connectivity (see [Networking Issues](/troubleshooting/networking-issues.md#rds-connectivity))

**2. Invalid metadata database credentials**:
```bash
# Check secret
kubectl get secret -n druid <druid-metadata-secret> -o yaml

# Verify password matches RDS
aws secretsmanager get-secret-value --secret-id <secret-id>
```

### Historical Pods Out of Disk Space

**Symptoms**: Historical pods evicted or failing

**Diagnosis**:
```bash
# Check PVC usage
kubectl exec -n druid <historical-pod> -- df -h /druid/data
```

**Solutions**:

**1. Increase PVC size**:
```bash
# Edit PVC (requires StorageClass with allowVolumeExpansion: true)
kubectl edit pvc -n druid <pvc-name>

# Increase storage request
spec:
  resources:
    requests:
      storage: 200Gi  # Increase from 100Gi
```

**2. Configure data retention**:
- Adjust Druid retention rules
- Enable automatic segment compaction

### MiddleManager Task Failures

**Symptoms**: Druid ingestion tasks fail

**Check task logs**:
```bash
# Get task ID from Druid UI or API
curl -s http://localhost:8888/druid/indexer/v1/tasks | jq .

# View task logs
kubectl logs -n druid <middlemanager-pod> | grep <task-id>
```

**Common issues**:

**1. Cannot connect to Kafka**:
```
Error: Failed to connect to Kafka bootstrap servers
```

**Solution**: Verify MSK connectivity and IAM permissions

**2. Out of memory during task**:
```
java.lang.OutOfMemoryError: Java heap space
```

**Solution**: Increase MiddleManager task JVM heap size in Druid configuration

## Karpenter Provisioning Issues

### Nodes Not Provisioning

**Symptoms**: Pods pending, but no new nodes created

**Check Karpenter**:
```bash
# View Karpenter logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter

# Check Karpenter Provisioner
kubectl get provisioner

# Check NodeClaims
kubectl get nodeclaims
```

**Common issues**:

**1. Service quota exceeded**:
```
Error: VcpuLimitExceeded: You have requested more vCPU capacity than allowed
```

**Solution**: Request EC2 quota increase

**2. No matching instance types**:
```
no instance types satisfy requirements
```

**Solution**: Review Provisioner requirements (too restrictive)

**3. IAM permissions**:
```bash
# Verify Karpenter role permissions
aws iam get-role --role-name <karpenter-role>
```

## General Debugging Commands

### Pod Status and Events

```bash
# Get pod details
kubectl get pod <pod-name> -n <namespace> -o wide

# Describe pod (shows events)
kubectl describe pod <pod-name> -n <namespace>

# View pod logs
kubectl logs <pod-name> -n <namespace>

# View logs from all containers in pod
kubectl logs <pod-name> -n <namespace> --all-containers

# Follow logs
kubectl logs -f <pod-name> -n <namespace>

# View previous container logs (if restarted)
kubectl logs <pod-name> -n <namespace> --previous
```

### Execute Commands in Pod

```bash
# Shell into running pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Run single command
kubectl exec <pod-name> -n <namespace> -- ls -la /app

# Check environment variables
kubectl exec <pod-name> -n <namespace> -- env
```

### Resource Usage

```bash
# Pod resource usage
kubectl top pod <pod-name> -n <namespace>

# Node resource usage
kubectl top node

# All pods in namespace
kubectl top pod -n <namespace>
```

### Debug with Ephemeral Container

```bash
# Attach debug container to running pod (K8s 1.23+)
kubectl debug <pod-name> -n <namespace> -it --image=nicolaka/netshoot
```

## Related Documentation

- [Common Errors →](common-errors.md)
- [Networking Issues →](networking-issues.md)
- [Druid EKS →](/druid/eks.md)
- [Druid Overview →](/druid/overview.md)
