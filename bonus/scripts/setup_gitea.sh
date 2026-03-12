#!/usr/bin/env bash
set -euo pipefail

NS="gitea"
GT_USER="gitadmin"
GT_PASS="Gitea_Passw0rd1337"
IMAGE="gitea/gitea:latest"

log() { echo -e "\033[0;32m[OK]\033[0m $1"; }
err() { echo -e "\n\033[0;31m[ERROR]\033[0m $1"; exit 1; }

kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic gitea-pass -n "$NS" \
  --from-literal=password="$GT_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: gitea-data, namespace: $NS }
spec:
  accessModes: [ReadWriteOnce]
  resources: { requests: { storage: 1Gi } }
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: gitea, namespace: $NS }
spec:
  replicas: 1
  strategy: { type: Recreate }
  selector: { matchLabels: { app: gitea } }
  template:
    metadata: { labels: { app: gitea } }
    spec:
      containers:
      - name: gitea
        image: $IMAGE
        env:
        - name: GITEA__security__INSTALL_LOCK
          value: "true"
        - name: GITEA__database__DB_TYPE
          value: sqlite3
        - name: GITEA__database__PATH
          value: /data/gitea/gitea.db
        - name: GITEA__server__HTTP_PORT
          value: "3000"
        # localhost ROOT_URL = no redirects when curl hits the port-forward
        # ArgoCD uses the Service DNS directly, so this doesn't affect it
        - name: GITEA__server__ROOT_URL
          value: "http://localhost:3000"
        - name: GITEA_ADMIN_USER
          value: "$GT_USER"
        - name: GITEA_ADMIN_PASSWORD
          valueFrom: { secretKeyRef: { name: gitea-pass, key: password } }
        - name: GITEA_ADMIN_EMAIL
          value: "admin@gitea.local"
        ports: [{ containerPort: 3000, name: http }]
        readinessProbe:
          httpGet: { path: /api/v1/version, port: 3000 }
          initialDelaySeconds: 15
          periodSeconds: 5
          failureThreshold: 30
        livenessProbe:
          httpGet: { path: /api/v1/version, port: 3000 }
          initialDelaySeconds: 60
          periodSeconds: 10
        resources:
          requests: { memory: "128Mi", cpu: "100m" }
          limits: { memory: "512Mi", cpu: "500m" }
        volumeMounts: [{ name: data, mountPath: /data }]
      volumes: [{ name: data, persistentVolumeClaim: { claimName: gitea-data } }]
---
apiVersion: v1
kind: Service
metadata: { name: gitea, namespace: $NS }
spec:
  selector: { app: gitea }
  ports: [{ port: 3000, targetPort: 3000, name: http }]
EOF

log "Waiting for Pod to be Ready..."
kubectl wait --for=condition=Ready pod -l app=gitea -n "$NS" --timeout=300s

pkill -f "port-forward.*3000" 2>/dev/null || true
(while true; do kubectl port-forward svc/gitea 3000:3000 -n "$NS" --address 0.0.0.0 2>/dev/null; sleep 1; done) &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 3

log "Waiting for Gitea API to be ready..."
MAX=60; COUNT=0
while true; do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:3000/api/v1/version" || echo "000")
  [ "$CODE" = "200" ] && break
  [ "$COUNT" -ge "$MAX" ] && err "Timeout waiting for Gitea API."
  echo -ne "\033[0;33m[WAIT]\033[0m HTTP $CODE | Elapsed: $((COUNT * 5))s\r"
  COUNT=$((COUNT + 1)); sleep 5
done
echo ""

AUTH_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
  "http://localhost:3000/api/v1/user" \
  -u "${GT_USER}:${GT_PASS}" || echo "000")

if [ "$AUTH_CODE" = "200" ]; then
  log "Admin user '$GT_USER' already exists (bootstrapped by GITEA_ADMIN_*)."
else
  log "Bootstrapping admin user via CLI (GITEA_ADMIN_* did not fire)..."
  GITEA_POD=$(kubectl get pod -n "$NS" -l app=gitea -o jsonpath='{.items[0].metadata.name}')
  set +e
  RESULT=$(kubectl exec -i -n "$NS" "$GITEA_POD" -- \
    su git -s /bin/sh 2>&1 << ADMINCMD
gitea admin user create \
  --admin \
  --username "${GT_USER}" \
  --password "${GT_PASS}" \
  --email "admin@gitea.local" \
  --must-change-password=false
ADMINCMD
  )
  set -e
  echo "$RESULT"
  if echo "$RESULT" | grep -qiE 'created|already exists'; then
    log "Admin user '$GT_USER' is ready."
  else
    err "CLI admin setup failed. Output: $RESULT"
  fi
fi

log "Gitea is up."
