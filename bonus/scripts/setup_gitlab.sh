#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[0;32m"; NC="\033[0m"
log(){ echo -e "${GREEN}✅ $1${NC}"; }

GL_NS="gitlab"
GL_PASS="G!tL@b_P@ssw0rd1337"

kubectl create namespace "$GL_NS" --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitlab
  namespace: gitlab
spec:
  replicas: 1
  progressDeadlineSeconds: 3600
  selector:
    matchLabels: 
      app: gitlab
  template:
    metadata: 
      labels: 
        app: gitlab
    spec:
      containers:
      - name: gitlab
        image: gitlab/gitlab-ce:latest
        env:
        - name: GITLAB_OMNIBUS_CONFIG
          value: |
            external_url 'http://gitlab.gitlab.svc.cluster.local'
            nginx['listen_port'] = 80
            nginx['listen_https'] = false
            gitlab_rails['initial_root_password'] = 'G!tL@b_P@ssw0rd1337'
            prometheus_monitoring['enable'] = false
            puma['worker_processes'] = 0
            sidekiq['max_concurrency'] = 10
        ports:
        - containerPort: 80
        - containerPort: 22
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "3Gi"
            cpu: "2"
        readinessProbe:
          httpGet:
            path: /-/health
            port: 80
          initialDelaySeconds: 120
          periodSeconds: 20
          timeoutSeconds: 5
          failureThreshold: 120
---
apiVersion: v1
kind: Service
metadata:
  name: gitlab
  namespace: gitlab
spec:
  ports:
  - port: 80
    targetPort: 80
    name: http
  - port: 22
    targetPort: 22
    name: ssh
  selector:
    app: gitlab
EOF

log "Waiting for GitLab readiness (may take 10-15m on first boot)"
kubectl -n "$GL_NS" rollout status deploy/gitlab --timeout=1500s

pkill -f 'kubectl.*port-forward.*8080' 2>/dev/null || true
kubectl port-forward svc/gitlab 8080:80 -n "$GL_NS" >/dev/null 2>&1 &
sleep 5

log "GitLab is UP at http://localhost:8080"
