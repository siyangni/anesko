#!/bin/bash
# Kubernetes Deployment Script for American Authorship Database
# This script deploys the application to a Kubernetes cluster

set -e  # Exit on error

# =============================================================================
# CONFIGURATION
# =============================================================================

APP_NAME="american-authorship"
NAMESPACE="${NAMESPACE:-default}"
IMAGE_NAME="${IMAGE_NAME:-american-authorship-app}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-docker.io}"  # Default to Docker Hub

# =============================================================================
# COLOR OUTPUT
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# =============================================================================
# PRE-DEPLOYMENT CHECKS
# =============================================================================

echo "🚀 American Authorship Database - Kubernetes Deployment"
echo ""

# Check kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check docker is installed
if ! command -v docker &> /dev/null; then
    print_error "docker not found. Please install docker first."
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    echo "Please configure kubectl to connect to your cluster"
    exit 1
fi

print_success "Pre-deployment checks passed"
echo ""

# =============================================================================
# BUILD DOCKER IMAGE
# =============================================================================

echo "🐳 Building Docker image..."
echo "   Image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

docker build -t "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" .

if [ $? -eq 0 ]; then
    print_success "Docker image built successfully"
else
    print_error "Docker build failed"
    exit 1
fi

# =============================================================================
# PUSH TO REGISTRY
# =============================================================================

echo ""
echo "📤 Pushing image to registry..."

docker push "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

if [ $? -eq 0 ]; then
    print_success "Image pushed successfully"
else
    print_error "Docker push failed"
    exit 1
fi

# =============================================================================
# CREATE NAMESPACE
# =============================================================================

echo ""
echo "📁 Creating namespace (if not exists)..."

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
print_success "Namespace ready: ${NAMESPACE}"

# =============================================================================
# CREATE SECRETS
# =============================================================================

echo ""
echo "🔐 Creating secrets..."

# Check if secret file exists
if [ ! -f "secrets/db_password.txt" ]; then
    print_warning "secrets/db_password.txt not found"
    echo "Creating from template..."
    openssl rand -base64 32 > secrets/db_password.txt
fi

# Create database secret
kubectl create secret generic db-credentials \
    --from-file=password=secrets/db_password.txt \
    --namespace="${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

print_success "Secrets created"

# =============================================================================
# DEPLOY APPLICATION
# =============================================================================

echo ""
echo "🚀 Deploying application..."

# Create deployment manifest
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${APP_NAME}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      containers:
      - name: shiny-app
        image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
        ports:
        - containerPort: 3838
          name: http
        env:
        - name: DB_HOST
          value: "postgres-service"  # Update with your database service
        - name: DB_NAME
          value: "american_authorship"
        - name: DB_USER
          value: "authorship_admin"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /alive
            port: 3838
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3838
          initialDelaySeconds: 20
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-service
  namespace: ${NAMESPACE}
spec:
  selector:
    app: ${APP_NAME}
  ports:
  - port: 80
    targetPort: 3838
    protocol: TCP
  type: LoadBalancer
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}-ingress
  namespace: ${NAMESPACE}
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - ${APP_NAME}.example.com  # UPDATE WITH YOUR DOMAIN
    secretName: ${APP_NAME}-tls
  rules:
  - host: ${APP_NAME}.example.com  # UPDATE WITH YOUR DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${APP_NAME}-service
            port:
              number: 80
EOF

print_success "Application deployed"

# =============================================================================
# WAIT FOR DEPLOYMENT
# =============================================================================

echo ""
echo "⏳ Waiting for deployment to be ready..."

kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=5m

if [ $? -eq 0 ]; then
    print_success "Deployment is ready"
else
    print_error "Deployment timed out or failed"
    echo ""
    echo "Check pod status:"
    kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME}
    echo ""
    echo "Check pod logs:"
    kubectl logs -n ${NAMESPACE} -l app=${APP_NAME} --tail=50
    exit 1
fi

# =============================================================================
# DISPLAY STATUS
# =============================================================================

echo ""
echo "📊 Deployment Status:"
echo ""

kubectl get deployment ${APP_NAME} -n ${NAMESPACE}
echo ""
kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME}
echo ""
kubectl get service ${APP_NAME}-service -n ${NAMESPACE}

# Get external IP
echo ""
echo "🌐 Accessing the application:"
EXTERNAL_IP=$(kubectl get service ${APP_NAME}-service -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$EXTERNAL_IP" ]; then
    print_warning "External IP not yet assigned. Wait a few minutes and run:"
    echo "kubectl get service ${APP_NAME}-service -n ${NAMESPACE}"
else
    echo "Application available at: http://${EXTERNAL_IP}"
fi

echo ""
print_success "Deployment complete! 🎉"

# =============================================================================
# POST-DEPLOYMENT CHECKLIST
# =============================================================================

echo ""
echo "📝 Post-deployment checklist:"
echo ""
echo "1. Configure DNS:"
echo "   - Point ${APP_NAME}.example.com to ${EXTERNAL_IP}"
echo ""
echo "2. Set up SSL/TLS:"
echo "   - Ensure cert-manager is installed"
echo "   - Check certificate: kubectl get certificate -n ${NAMESPACE}"
echo ""
echo "3. Configure monitoring:"
echo "   - Install Prometheus operator if not present"
echo "   - Create ServiceMonitor for metrics"
echo ""
echo "4. Test the application:"
echo "   - Visit: http://${EXTERNAL_IP}"
echo "   - Check all modules work correctly"
echo ""
echo "5. Set up horizontal pod autoscaling:"
echo "   kubectl autoscale deployment ${APP_NAME} --cpu-percent=70 --min=2 --max=10 -n ${NAMESPACE}"
echo ""
