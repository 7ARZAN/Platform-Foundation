#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="gitlab"
APP_NAME="platform-foundation"

GREEN="\033[0;32m"; BLUE="\033[0;34m"; RED="\033[0;31m"; NC="\033[0m"
log(){ echo -e "${GREEN}✅ $1${NC}"; }
info(){ echo -e "${BLUE}ℹ️ $1${NC}"; }
warn(){ echo -e "${RED}⚠️ $1${NC}"; }

info "Ensuring GitLab credentials secret exists..."
if ! kubectl get secret gitlab-credentials -n $NAMESPACE >/dev/null 2>&1; then
    info "Generating secure random password..."
    RANDOM_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)
    kubectl create secret generic gitlab-credentials -n $NAMESPACE \
	--from-literal=root-password="$RANDOM_PASS"
    log "Secret 'gitlab-credentials' created."
fi

ROOT_PASSWD=$(kubectl get secret gitlab-credentials -n $NAMESPACE -o jsonpath='{.data.root-password}' | base64 -d)

log "GitLab Pod is Ready!"
info "Waiting for GitLab Internal Health Check..."
until [ "$(kubectl exec -n $NAMESPACE deployment/gitlab -- curl -s -o /dev/null -w "%{http_code}" http://localhost/-/health)" == "200" ]; do
    info "GitLab application service is starting..."
    sleep 10
done

log "GitLab Application is operational!"

info "Configuring GitLab Project '$APP_NAME'..."
kubectl exec -n $NAMESPACE deployment/gitlab -- gitlab-rails runner "
user = User.find_by_username('root')
project = Project.find_by(name: '$APP_NAME')
if project.nil?
  project = Projects::CreateService.new(user, {
    name: '$APP_NAME',
    path: '$APP_NAME',
    visibility_level: Gitlab::VisibilityLevel::PUBLIC,
    initialize_with_readme: 'false'
  }).execute
  puts 'Project created'
else
  puts 'Project already exists'
end
"

info "Generating/Retrieving Access Token..."
TOKEN=$(kubectl exec -n $NAMESPACE deployment/gitlab -- gitlab-rails runner "
user = User.find_by_username('root')
token_name = 'argocd-access-token'
existing_token = user.personal_access_tokens.find_by(name: token_name)
if existing_token
  existing_token.revoke!
end
token = user.personal_access_tokens.create(scopes: [:api, :read_repository, :write_repository], name: token_name)
puts token.token
")

kubectl create secret generic argocd-gitlab-token \
    -n $NAMESPACE --from-literal=token="$TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

log "Access Token secured in secret 'argocd-gitlab-token'."

GITLAB_Domain="gitlab.iot.com"
GITLAB_URL="http://root:$TOKEN@$GITLAB_Domain:8080/root/$APP_NAME.git"

if ! ping -c 1 $GITLAB_Domain &> /dev/null; then
    warn "Cannot resolve $GITLAB_Domain. The script might fail to push."
    warn "Please ensure you added '127.0.0.1 $GITLAB_Domain argocd.iot.com' to /etc/hosts"
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/../../" && pwd)"

info "Pushing local repository to GitLab..."
TEMP_DIR=$(mktemp -d)
cp -r "$PROJECT_ROOT/." "$TEMP_DIR/"
cd "$TEMP_DIR"
rm -rf .git
git init
git config user.email "root@iot.com"
git config user.name "root"
git add .
git commit -am "Bonus Part Release"

if git remote add origin "$GITLAB_URL"; then
    log "Remote added: $GITLAB_URL"
fi

if git push -u origin master --force; then
    log "Code pushed successfully!"
else
    warn "Failed to push code. Check if $GITLAB_Domain resolves to 127.0.0.1 and port 8080 is accessible."
    exit 1
fi

info "Applying ArgoCD Configuration..."
kubectl apply -f "$PROJECT_ROOT/bonus/manifests/argocd/project.yml"
kubectl apply -f "$PROJECT_ROOT/bonus/manifests/argocd/app-bonus.yml"
kubectl apply -f "$PROJECT_ROOT/bonus/manifests/argocd/ingress.yml"

log "ArgoCD Application deployed!"
info "GitLab URL: http://gitlab.iot.com:8080"
info "ArgoCD URL: http://argocd.iot.com:8080"
info "Root Password: $ROOT_PASSWD"
