#!/bin/sh

echo "Writing system variables to file for future reference(temporary action)"
$(cat credentials.txt)
rm credentials.txt

echo "connect with kubernetes cluster"
aws eks update-kubeconfig --name ${cluster_name}

echo "Install kubernetes V1.23.6"

curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.23.6/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

echo "install aws cli"

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && sudo ./aws/install

echo "Configure the RBAC for cluster to join nodes"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${eks_node_role_arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${eks_fargate_role_arn}
      username: system:node:{{SessionName}}
      groups:
        - system:bootstrappers
        - system:nodes
        - system:node-proxier
    - rolearn: ${eks_k8s_masters_role_arn}
      username: user-admin::{{SessionName}}
      groups:
        - system:masters
    - rolearn: ${eks_k8s_readonly_role_arn}
      username: user-readonly::{{SessionName}}
      groups:
        - readonly
  mapUsers: |
%{ for user_arn in eks_arn_user_list_with_masters_user ~}
    - groups:
        - system:masters
      userarn: ${user_arn}
      username: user-admin::{{SessionName}}
%{ endfor ~}
EOF

echo "Set up roles for read-only access"
cat <<EOF | kubectl apply -f -
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: readonly
  namespace: default
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: readonly-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: readonly
subjects:
- kind: Group
  name: readonly
EOF

echo "Configure the POD's to have internet access via AWS_VPC_K8S_CNI_EXTERNALSNAT"
kubectl -n kube-system set env daemonset aws-node AWS_VPC_K8S_CNI_EXTERNALSNAT=true

echo "Configure CoreDNS for Fargate"
kubectl patch deployment coredns -n kube-system --type json -p='[{"op": "add", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type", "value":"fargate"}]' || true

echo "Restart deployed CoreDNS"
kubectl rollout restart -n kube-system deploy coredns

echo "Configuring ALB Controller"
set +e
set -e

curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.2.0/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicyServians --policy-document file://iam_policy.json
kubectl apply -f service_account.yml
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.1.1/cert-manager.yaml
kubectl apply -f v2_2_0_full.yaml

echo "Restart deployed ALB controller"
kubectl rollout restart -n kube-system deploy aws-load-balancer-controller

echo "Deploying External DNS controller"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${eks_external_dns_role_arn}
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: external-dns
  namespace: kube-system
rules:
- apiGroups: [""]
  resources: ["services","endpoints","pods"]
  verbs: ["get","watch","list"]
- apiGroups: ["extensions","networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
- kind: ServiceAccount
  name: external-dns
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: kube-system
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: k8s.gcr.io/external-dns/external-dns:v0.7.3
        args:
        - --source=service
        - --source=ingress
        - --domain-filter=${domain_name}
        - --provider=aws
        - --policy=upsert-only # would prevent ExternalDNS from deleting any records, omit to enable full synchronization
        - --aws-zone-type=public # only look at public hosted zones (valid values are public, private or no value for both)
        - --registry=txt
        - --txt-owner-id=axa-gulf
      securityContext:
        fsGroup: 65534 # For ExternalDNS to be able to read Kubernetes and AWS token files
EOF


echo "Restart deploy external dns"
kubectl rollout restart -n kube-system deploy external-dns

echo "Deploying Servians app"

cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: servian-config-map
data:
  DbName: "postgres"
  DbPort: "${app_backend_db_port}"
  DbHost: "${app_backend_db_host}"
  ListenHost: "0.0.0.0"
  ListenPort: "3000"
---
apiVersion: v1
kind: Secret
metadata:
  name: servians-secret
data:
  # You can include additional key value pairs as you do with Opaque Secrets
  dbuser: ${app_backend_db_user}
  dbpassword: ${app_backend_db_password}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: servian-test-app
  namespace: default
spec:
  replicas: 2
  strategy:
    type: Recreate
  selector:
    matchLabels:
      deployment: servian-test-app
  template:
    metadata:
      labels:
        deployment: servian-test-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9201"
        prometheus.io/path: /metric-service/metrics
    spec:
      securityContext:
          runAsUser: 0
          runAsGroup: 0
          fsGroup: 0
      containers:
        - image: servian/techchallengeapp:latest
          name: servian
          args: ['serve']
          imagePullPolicy: Always
          livenessProbe:
            exec:
              command: ["/bin/sh", "-c", "nc -z localhost 3000"]
            initialDelaySeconds: 20
            failureThreshold: 15
            periodSeconds: 10
          readinessProbe:
            exec:
              command: ["/bin/sh", "-c", "nc -z localhost 3000"]
            initialDelaySeconds: 20
            failureThreshold: 15
            periodSeconds: 10
          lifecycle:
            postStart:
              exec:
                command: ["/bin/sh", "-c", "./TechChallengeApp updatedb -s"]
          resources:
            requests:
              memory: 64Mi
              cpu: 100m
            limits:
              memory: 200Mi
              cpu: 150m
          ports:
            - containerPort: 3000
              protocol: "TCP"
          env:
            - name: WATCH_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: NODE_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: VTT_DBUSER
              valueFrom:
                secretKeyRef:
                  name: servians-secret
                  key: dbuser
            - name: VTT_DBPASSWORD
              valueFrom:
                secretKeyRef:
                  name: serviantc-secret
                  key: dbpassword

            - name: VTT_DBNAME
              valueFrom:
                configMapKeyRef:
                  name: servian-config-map
                  key: DbName
            - name: VTT_DBPORT
              valueFrom:
                configMapKeyRef:
                  name: servian-config-map
                  key: DbPort
            - name: VTT_DBHOST
              valueFrom:
                configMapKeyRef:
                  name: servian-config-map
                  key: DbHost
            - name: VTT_LISTENHOST
              valueFrom:
                configMapKeyRef:
                  name: servian-config-map
                  key: ListenHost
            - name: VTT_LISTENPORT
              valueFrom:
                configMapKeyRef:
                  name: servian-config-map
                  key: ListenPort
---
apiVersion: v1
kind: Service
metadata:
  name: servian-svc
  namespace: default
spec:
  selector:
    deployment: servian-test-app
  type: NodePort
  ports:
    - name: http
      protocol: TCP
      port: 3000
      targetPort: 3000

EOF


echo "Metrics server Deployment"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Disable exit on non 0
set +e
echo "HPA configurations"
kubectl autoscale deployment serviantc --cpu-percent=60 --min=1 --max=5
# Enable exit on non 0
set -e
sleep 5
kubectl describe hpa

echo "Configure Servian test app ingress"
cat << 'EOF' |tee k8s-ingress-ext-servian-app.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: serviantc-ext-gws
  namespace: default
  annotations:
    # ACM Cretificate ARN
    alb.ingress.kubernetes.io/certificate-arn: >-
      ${eks_alb_ing_ssl_cert_arn}
    # Health Check Settings
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-port: "3000"
    alb.ingress.kubernetes.io/healthcheck-path: /healthcheck/
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    # Direct traffic true 443
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/tags: >-
      Type=NoManual,Client=Servian,Project=Servian-Test,Environment=preprod,App=serviantc-ext-gws
    alb.ingress.kubernetes.io/target-type: ip
    kubernetes.io/ingress.class: alb

spec:
  rules:
    - http:
        paths:
          - path: /*
            backend:
              serviceName: servian-svc
              servicePort: 3000
EOF

kubectl apply -f k8s-ingress-ext-servian-app.yaml
rm k8s-ingress-ext-servian-app.yaml

echo "ELB hostname printing"
sleep 3
kubectl get ing serviantc-ext-gws -o='custom-columns=Address:.status.loadBalancer.ingress[0].hostname' --no-headers
echo "Servian Tech Challenge App can be accessed via: https://LB_HOST_NAME"
# rm /home/ec2-user/.kube/config
