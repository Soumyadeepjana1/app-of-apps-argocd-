
#!/bin/bash

set -e

echo "Creating Argo CD App of Apps project..."

# GitHub repository URL
read -rp "Enter your GitHub repository URL: " REPO_URL

if [[ -z "$REPO_URL" ]]; then
    echo "Repository URL is required!"
    exit 1
fi

# Directory structure
mkdir -p apps/children
mkdir -p apps/workloads/apache
mkdir -p apps/workloads/nginx
mkdir -p apps/workloads/django

# =====================================
# ROOT APPLICATION
# =====================================

cat > root-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: app-of-apps
  namespace: argocd

spec:
  project: default

  source:
    repoURL: ${REPO_URL}
    targetRevision: master
    path: apps/children

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# =====================================
# APACHE CHILD APPLICATION
# =====================================

cat > apps/children/apache.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: apache
  namespace: argocd

spec:
  project: default

  source:
    repoURL: ${REPO_URL}
    targetRevision: master
    path: apps/workloads/apache

  destination:
    server: https://kubernetes.default.svc
    namespace: apache

  syncPolicy:
    automated:
      prune: true
      selfHeal: true

    syncOptions:
      - CreateNamespace=true
EOF

# Apache Deployment
cat > apps/workloads/apache/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment

metadata:
  name: apache
  namespace: apache

spec:
  replicas: 2

  selector:
    matchLabels:
      app: apache

  template:
    metadata:
      labels:
        app: apache

    spec:
      containers:
        - name: apache
          image: httpd:2.4
          ports:
            - containerPort: 80
EOF

# Apache Service
cat > apps/workloads/apache/service.yaml <<'EOF'
apiVersion: v1
kind: Service

metadata:
  name: apache-service
  namespace: apache

spec:
  type: ClusterIP

  selector:
    app: apache

  ports:
    - port: 80
      targetPort: 80
EOF

# =====================================
# NGINX CHILD APPLICATION
# =====================================

cat > apps/children/nginx.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: nginx
  namespace: argocd

spec:
  project: default

  source:
    repoURL: ${REPO_URL}
    targetRevision: master
    path: apps/workloads/nginx

  destination:
    server: https://kubernetes.default.svc
    namespace: nginx

  syncPolicy:
    automated:
      prune: true
      selfHeal: true

    syncOptions:
      - CreateNamespace=true
EOF

# Nginx Deployment
cat > apps/workloads/nginx/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment

metadata:
  name: nginx
  namespace: nginx

spec:
  replicas: 2

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx

    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
EOF

# Nginx Service
cat > apps/workloads/nginx/service.yaml <<'EOF'
apiVersion: v1
kind: Service

metadata:
  name: nginx-service
  namespace: nginx

spec:
  type: ClusterIP

  selector:
    app: nginx

  ports:
    - port: 80
      targetPort: 80
EOF

# =====================================
# DJANGO CHILD APPLICATION
# =====================================

cat > apps/children/django.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: django
  namespace: argocd

spec:
  project: default

  source:
    repoURL: ${REPO_URL}
    targetRevision: master
    path: apps/workloads/django

  destination:
    server: https://kubernetes.default.svc
    namespace: django

  syncPolicy:
    automated:
      prune: true
      selfHeal: true

    syncOptions:
      - CreateNamespace=true
EOF

# Django Deployment
cat > apps/workloads/django/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment

metadata:
  name: django
  namespace: django

spec:
  replicas: 2

  selector:
    matchLabels:
      app: django

  template:
    metadata:
      labels:
        app: django

    spec:
      containers:
        - name: django
          image: python:3.12-slim

          command:
            - /bin/sh
            - -c

          args:
            - |
              pip install --no-cache-dir django &&
              mkdir -p /app &&
              django-admin startproject mysite /app &&
              sed -i "s/ALLOWED_HOSTS = \\[\\]/ALLOWED_HOSTS = ['*']/" /app/mysite/settings.py &&
              cd /app &&
              python manage.py runserver 0.0.0.0:8000

          ports:
            - containerPort: 8000
EOF

# Django Service
cat > apps/workloads/django/service.yaml <<'EOF'
apiVersion: v1
kind: Service

metadata:
  name: django-service
  namespace: django

spec:
  type: ClusterIP

  selector:
    app: django

  ports:
    - port: 8000
      targetPort: 8000
EOF

echo ""
echo "=================================="
echo "App of Apps project created!"
echo "=================================="

tree .
