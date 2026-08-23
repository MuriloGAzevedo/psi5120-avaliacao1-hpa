# Guia de execução individual — Avaliação Intermediária 1 (HPA em Kubernetes)

**Grupo:** Murilo Gabriel Moraes de Azevedo (13782776), Bruno Valle Martins (13681036), Pedro Remus de Ávila (13682486).

> ⭐ **Execução de referência:** a implantação documentada neste repositório (Minikube + EKS, com evidências
> reais em `evidencias/`) foi realizada por **Murilo** e serve como **referência do grupo**. O artigo e o
> repositório são coletivos. O enunciado, porém, pede **execução prática individual** — então **Bruno e Pedro
> devem reproduzir** as duas implantações nas suas próprias máquinas/contas, seguindo este guia, e guardar
> **suas próprias evidências/screenshots**. Se algum integrante não conseguir reproduzir, ainda submete o
> artigo e o link do repositório (que contêm a execução de referência); mas o ideal é cada um rodar a sua.

Cada um salva suas evidências em pastas próprias:
`evidencias/minikube/<seu-nome>/` e `evidencias/eks/<seu-nome>/`.

---

# PARTE 1 — Implantação A: Minikube (local)

**Pré-requisitos:** uma máquina Linux (ou Windows com **WSL2/Ubuntu**) com **Docker**, **Minikube** e **kubectl**
instalados. (No Ubuntu: instale Docker; depois `kubectl` e `minikube` pelos binários oficiais.)

### A.1 — Criar o cluster e habilitar o Metrics Server
```bash
minikube start -p av1-local --driver=docker
kubectl wait --for=condition=Ready nodes --all --timeout=150s
minikube addons enable metrics-server -p av1-local     # HPA por CPU depende disso
kubectl get nodes -o wide
```
📸 **print:** `kubectl get nodes` (node Ready).

### A.2 — Baixar os manifestos do repositório
```bash
git clone https://github.com/MuriloGAzevedo/psi5120-avaliacao1-hpa.git
cd psi5120-avaliacao1-hpa
```

### A.3 — Construir a imagem e carregar no cluster
```bash
docker build -t av1-webcpu:v1 app/
minikube image load av1-webcpu:v1 -p av1-local
```

### A.4 — Implantar Deployment, Service e HPA
```bash
kubectl apply -f k8s/00-namespace.yaml -f k8s/01-deployment.yaml -f k8s/02-service.yaml
kubectl rollout status deployment/web -n av1 --timeout=180s
kubectl apply -f k8s/03-hpa.yaml
sleep 60      # aguarda o HPA sair de <unknown>
kubectl get deployment,hpa,pods -n av1 -o wide
```
📸 **print:** baseline (HPA `cpu 0%/50%`, 1 réplica).

### A.5 — Teste de estresse: escala SOBE
```bash
kubectl apply -f k8s/04-load-generator.yaml
# acompanhe ~5 min:
kubectl get hpa web -n av1 -w
```
Em outro terminal:
```bash
kubectl get pods -n av1 -l app=web -o wide
kubectl top pods -n av1 -l app=web
kubectl describe hpa web -n av1        # eventos SuccessfulRescale
```
📸 **prints:** HPA com CPU > 50% e réplicas subindo (até 10); `top pods`.

### A.6 — Fim da carga: escala DESCE
```bash
kubectl delete -f k8s/04-load-generator.yaml
kubectl get hpa web -n av1 -w          # volta a 1 réplica após ~300s
```
📸 **print:** HPA de volta a 1 réplica.

### A.7 — Limpeza
```bash
kubectl delete namespace av1
minikube delete -p av1-local
```

> Alternativa automatizada: `bash scripts/run_implantacao_a_minikube.sh "<Seu Nome>" .` executa A.1–A.7 e
> salva as saídas (mas para os **screenshots** você precisa acompanhar em tela).

---

# PARTE 2 — Implantação B: Amazon EKS (nuvem)

> ⚠️ **Custo ~US$ 0,20 e limpeza obrigatória no mesmo dia.** Use identidade IAM **não-root**. Região `us-east-1`.

### B.0 — Identidade + variáveis (no AWS CloudShell)
No Console: selecione a região **us-east-1** e faça login com um usuário **IAM administrativo (não-root)**.
Abra o **CloudShell** e cole (repita estes `export` sempre que a sessão reconectar):
```bash
export AWS_PAGER=""; export REGIAO=us-east-1; export VPC_STACK=av1-vpc
export CLUSTER=av1-eks; export NODEGROUP=av1-ng; export NAMESPACE=av1
aws sts get-caller-identity                # Arn deve ser ...:user/<voce>, NÃO :root
```
📸 **print 1:** identidade (mascare o Account ID no relatório).

### B.1 — Roles IAM (Console → IAM → Roles → Create role)
- **Role do cluster:** AWS service → **EKS** → *EKS - Cluster* → política `AmazonEKSClusterPolicy` → nome **`av1-eks-cluster-role`**.
- **Role dos nós:** AWS service → **EC2** → políticas `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryPullOnly`, `AmazonEKS_CNI_Policy` → nome **`av1-eks-node-role`**.

📸 **print 2:** as duas roles no IAM.

### B.2 — VPC via CloudFormation (Console → CloudFormation → Create stack)
- Template is ready → **Amazon S3 URL**:
  `https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-sample.yaml`
- Stack name **`av1-vpc`** → Submit. Aguarde **`CREATE_COMPLETE`**. Anote os Outputs (VpcId, SubnetIds, SecurityGroups).

📸 **print 3:** stack `CREATE_COMPLETE` + Outputs.

### B.3 — Criar o cluster EKS (Console → EKS → Create cluster)
- **⚠️ DESLIGUE o "EKS Auto Mode"** (o toggle vem LIGADO por padrão; sem desligar, ele exige políticas extras e
  não usa managed node group). **Confirme depois:**
  `aws eks describe-cluster --region "$REGIAO" --name "$CLUSTER" --query 'cluster.computeConfig'` → deve dar `null`.
- Name **`av1-eks`**; Cluster IAM role **`av1-eks-cluster-role`**; versão recente em Standard support.
- Networking: VPC/subnets/SG dos Outputs do B.2; endpoint **Public**.
- Add-ons: **VPC CNI, CoreDNS, kube-proxy**. Create. Aguarde **`Active`** (~10 min).

📸 **print 4:** cluster `av1-eks` **Ativo**.

### B.4 — Node group (Cluster → Compute → Add node group)
- Name **`av1-ng`**; Node IAM role **`av1-eks-node-role`**; **`t3.medium`**; disco 20 GiB;
  **Desired/Min/Max = 2/2/2** (dois nós, para ver a distribuição); as 3 subnets; sem SSH/Spot. Create → **Active**.

📸 **print 5:** node group `av1-ng` **Ativo**.

### B.5 — Conectar + Metrics Server
```bash
aws eks update-kubeconfig --region "$REGIAO" --name "$CLUSTER"
kubectl get nodes -o wide                 # 2 nós Ready
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s
kubectl top nodes
```
📸 **print 6:** 2 nós Ready + `top nodes`.

### B.6 — Implantar app + HPA (imagem pública, sem ECR)
```bash
mkdir -p ~/av1 && cd ~/av1
cat > app.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata: { name: av1 }
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: web, namespace: av1, labels: { app: web } }
spec:
  replicas: 1
  selector: { matchLabels: { app: web } }
  template:
    metadata: { labels: { app: web } }
    spec:
      containers:
      - name: web
        image: registry.k8s.io/hpa-example
        ports: [ { containerPort: 80 } ]
        resources:
          requests: { cpu: 200m, memory: 64Mi }
          limits:   { cpu: 500m, memory: 128Mi }
---
apiVersion: v1
kind: Service
metadata: { name: web, namespace: av1, labels: { app: web } }
spec:
  type: ClusterIP
  selector: { app: web }
  ports: [ { name: http, port: 80, targetPort: 80 } ]
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: web, namespace: av1 }
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: web }
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource: { name: cpu, target: { type: Utilization, averageUtilization: 50 } }
EOF
kubectl apply -f ~/av1/app.yaml
kubectl rollout status deployment/web -n av1 --timeout=180s
sleep 60
kubectl get deployment,hpa,pods -n av1 -o wide
```
📸 **print 7:** baseline (HPA `cpu 0%/50%`, 1 réplica; coluna NODE).

### B.7 — Teste de estresse: escala SOBE (com distribuição entre nós)
```bash
cat > ~/av1/load.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: load-generator, namespace: av1, labels: { app: load-generator } }
spec:
  replicas: 5
  selector: { matchLabels: { app: load-generator } }
  template:
    metadata: { labels: { app: load-generator } }
    spec:
      containers:
      - name: load
        image: busybox:1.36
        command: ["/bin/sh","-c","while true; do wget -q -O- http://web > /dev/null; done"]
EOF
kubectl apply -f ~/av1/load.yaml
for i in $(seq 1 15); do
  echo "[$(date +%H:%M:%S)] $(kubectl get hpa web -n av1 --no-headers)"
  kubectl get pods -n av1 -l app=web -o wide --no-headers | awk '{print "   "$1"  -> "$7}'
  echo "---"; sleep 20
done
kubectl get pods -n av1 -l app=web -o wide
kubectl top pods -n av1 -l app=web
kubectl describe hpa web -n av1 | sed -n '/Events:/,$p'
```
📸 **print 8:** HPA subindo (1→...→10). 📸 **print 9:** pods distribuídos entre os 2 nós. 📸 **print 10:** `top pods` + eventos.

### B.8 — Fim da carga: escala DESCE
```bash
kubectl delete -f ~/av1/load.yaml
for i in $(seq 1 24); do
  H="$(kubectl get hpa web -n av1 --no-headers)"; echo "[$(date +%H:%M:%S)] $H"
  echo "$H" | awk '{print $6}' | grep -qx 1 && { echo ">>> voltou a 1 <<<"; break; }
  sleep 20
done
kubectl describe hpa web -n av1 | sed -n '/Events:/,$p'
```
📸 **print 11:** HPA de volta a 1 réplica.

### B.9 — LIMPEZA (obrigatória, no mesmo dia)
```bash
kubectl delete namespace av1
aws eks delete-nodegroup --region "$REGIAO" --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP"
aws eks wait nodegroup-deleted --region "$REGIAO" --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP"
aws eks delete-cluster --region "$REGIAO" --name "$CLUSTER"
aws eks wait cluster-deleted --region "$REGIAO" --name "$CLUSTER"
aws cloudformation delete-stack --region "$REGIAO" --stack-name "$VPC_STACK"
aws cloudformation wait stack-delete-complete --region "$REGIAO" --stack-name "$VPC_STACK"
for R in av1-eks-cluster-role av1-eks-node-role; do
  for IP in $(aws iam list-instance-profiles-for-role --role-name "$R" --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null); do
    aws iam remove-role-from-instance-profile --instance-profile-name "$IP" --role-name "$R"
    aws iam delete-instance-profile --instance-profile-name "$IP"; done
  for P in $(aws iam list-attached-role-policies --role-name "$R" --query 'AttachedPolicies[].PolicyArn' --output text); do
    aws iam detach-role-policy --role-name "$R" --policy-arn "$P"; done
  aws iam delete-role --role-name "$R"; done
# verificacao final (tudo vazio):
aws eks list-clusters --region "$REGIAO" --output text
aws cloudformation list-stacks --region "$REGIAO" --query "StackSummaries[?contains(StackName,'av1') && StackStatus!='DELETE_COMPLETE'].StackName" --output text
aws iam list-roles --query "Roles[?contains(RoleName,'av1')].RoleName" --output text
```
📸 **print 12:** verificação final vazia. 📸 **print 13:** Billing (custo do dia).

---

# Submissão (cada integrante, individualmente no Moodle)
Anexar o **PDF do artigo** (`artigo/artigo_av1_hpa.pdf`) e informar o **link do repositório**:
`https://github.com/MuriloGAzevedo/psi5120-avaliacao1-hpa`

> Dúvidas na execução: sigam este guia com calma; a execução de referência (evidências do Murilo) mostra
> exatamente o resultado esperado em cada etapa.
