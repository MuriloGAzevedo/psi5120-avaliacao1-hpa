# Roteiro B — Implantação em Nuvem (AWS EKS) com HPA — passo a passo completo

Guia ponta a ponta para reproduzir a solução (servidor web + HPA + teste de estresse) em um
cluster gerenciado **Amazon EKS**, via **Console + AWS CloudShell**. Cada integrante executa na
**sua própria conta AWS**. Região de referência: `us-east-1`.

> 📸 **= tirar screenshot.** Capture as telas indicadas — elas são a evidência exigida pelo trabalho.
>
> ⚠️ **Custo e limpeza:** EKS, nós EC2 e volumes geram cobrança (~US$ 0,50–1,00 se feito em ~1h e
> limpo no mesmo dia). Use identidade IAM **administrativa não-root**; o CloudShell usa credenciais
> temporárias — **não** crie access keys de longa duração. Faça a **limpeza (Passo 10)** no mesmo dia.

---

## Passo 0 — Pré-requisitos e identidade

1. No Console, canto superior direito, selecione a região **US East (N. Virginia) / us-east-1**.
2. Faça login com uma identidade IAM **administrativa (não-root)**.
3. Abra o **AWS CloudShell** (ícone de terminal na barra superior) e defina as variáveis:
```bash
export AWS_PAGER=""
export REGIAO=us-east-1
export CLUSTER=av1-eks
export NODEGROUP=av1-ng
export NAMESPACE=av1
aws sts get-caller-identity          # confirme que o Arn NÃO é ":root"
```
📸 **Tela 1:** saída de `aws sts get-caller-identity` (mascare o Account ID no relatório).

---

## Passo 1 — Roles IAM (cluster e nós)

Console → **IAM → Roles → Create role**:
- **Role do cluster:** AWS service → **EKS** → *EKS - Cluster* → política `AmazonEKSClusterPolicy` →
  nome **`av1-eks-cluster-role`**.
- **Role dos nós:** AWS service → **EC2** → anexe **`AmazonEKSWorkerNodePolicy`**,
  **`AmazonEC2ContainerRegistryPullOnly`** e **`AmazonEKS_CNI_Policy`** → nome **`av1-eks-node-role`**.

📸 **Tela 2:** as duas roles criadas na lista do IAM.

---

## Passo 2 — VPC via CloudFormation

Console → **CloudFormation → Create stack → With new resources**:
- Template is ready → **Amazon S3 URL**:
  `https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-sample.yaml`
- Stack name: **`av1-vpc`** → Next → Submit. Aguarde **`CREATE_COMPLETE`**.
- Na aba **Outputs**, anote **VpcId**, **SubnetIds** (3) e **SecurityGroups**.

📸 **Tela 3:** stack `av1-vpc` em `CREATE_COMPLETE` com os Outputs.

---

## Passo 3 — Criar o cluster EKS

Console → **EKS → Create cluster** → *Custom configuration*, **desmarque** *EKS Auto Mode*:
- Name **`av1-eks`**; Cluster IAM role **`av1-eks-cluster-role`**; versão recente em *Standard support*.
- **Cluster access:** *Allow cluster administrator access*; *Cluster authentication mode* = **EKS API**.
- **Networking:** VPC = VpcId do Passo 2; Subnets = as 3; Additional security group = SecurityGroups do
  Passo 2; endpoint **Public**.
- **Add-ons:** manter **VPC CNI, CoreDNS, kube-proxy**. Create. Aguarde **`ACTIVE`** (~10 min).

📸 **Tela 4:** cluster `av1-eks` em estado `Active`.

---

## Passo 4 — Managed node group (com capacidade para escalar)

Cluster `av1-eks` → aba **Compute → Add node group**:
- Name **`av1-ng`**; Node IAM role **`av1-eks-node-role`**.
- **Instance type `t3.small`** (ou `t3.medium`); disco 20 GiB; **Desired 2 / Min 2 / Max 2**
  (dois nós para observar a **distribuição das réplicas entre nós**, diferencial do EKS).
- Subnets = as 3 do Passo 2. Create. Aguarde **`Active`**.

📸 **Tela 5:** node group `av1-ng` em `Active`.

> Obs.: se aparecer erro de *"instance type not eligible for Free Tier"*, a conta está no plano
> gratuito → migre para o **plano pago** (Billing) e recrie o node group.

---

## Passo 5 — Conectar o CloudShell e instalar o Metrics Server

```bash
aws eks update-kubeconfig --region "$REGIAO" --name "$CLUSTER"
kubectl get nodes -o wide            # esperado: 2 nós Ready
# O EKS NÃO traz o Metrics Server; instale-o (necessário para o HPA por CPU):
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s
kubectl top nodes
```
📸 **Tela 6:** `kubectl get nodes -o wide` mostrando **2 nós Ready** + `kubectl top nodes`.

---

## Passo 6 — Disponibilizar a imagem e implantar

**Opção rápida (recomendada):** usar a imagem pública equivalente. Edite `k8s/01-deployment.yaml`,
trocando a linha da imagem por:
```yaml
        image: registry.k8s.io/hpa-example
```
(remova/ajuste `imagePullPolicy` se necessário; essa imagem é baixada do registry público).

**Opção completa (ECR):** publicar a imagem própria — ver `scripts/run_implantacao_b_eks.sh`.

Aplicar os mesmos manifestos da Implantação A:
```bash
# (obter os manifestos: git clone do repositório do grupo, ou upload via CloudShell)
kubectl apply -f k8s/00-namespace.yaml -f k8s/01-deployment.yaml -f k8s/02-service.yaml
kubectl rollout status deployment/web -n av1 --timeout=180s
kubectl apply -f k8s/03-hpa.yaml
# aguarde ~1-2 min o HPA sair de <unknown>:
kubectl get deployment,hpa,pods -n av1 -o wide
```
📸 **Tela 7:** `kubectl get deployment,hpa,pods -n av1 -o wide` (HPA com CPU, 1 réplica no baseline;
repare na coluna **NODE** — os Pods podem estar em nós diferentes).

---

## Passo 7 — Teste de estresse: escala SOBE

```bash
kubectl apply -f k8s/04-load-generator.yaml
# acompanhe a subida (deixe rodando ~4-5 min):
kubectl get hpa web -n av1 -w
```
Em outro fluxo de observação:
```bash
kubectl get pods -n av1 -l app=web -o wide     # observe a DISTRIBUIÇÃO entre os 2 nós
kubectl top pods -n av1 -l app=web
kubectl describe hpa web -n av1                 # eventos "SuccessfulRescale"
```
📸 **Tela 8:** HPA com CPU **acima de 50%** e **REPLICAS aumentando**.
📸 **Tela 9:** `kubectl get pods -o wide` mostrando as réplicas **distribuídas entre os 2 nós**.
📸 **Tela 10:** `kubectl top pods` com o consumo por réplica.

---

## Passo 8 — Teste de estresse: escala DESCE

```bash
kubectl delete -f k8s/04-load-generator.yaml
# após ~300s (janela de estabilização), as réplicas retornam a 1:
kubectl get hpa web -n av1 -w
```
📸 **Tela 11:** HPA voltando a **~0%/50%** e **REPLICAS retornando a 1**.

---

## Passo 9 — Correlacionar com a AWS (opcional, fortalece o relatório)

📸 **Tela 12:** Console → **EKS → av1-eks → Compute** (node group e instâncias) e
**EC2 → Instances** (os 2 nós). Mostra a relação Kubernetes ↔ recursos AWS.

---

## Passo 10 — LIMPEZA (obrigatória, no mesmo dia)

```bash
kubectl delete namespace av1                # remove app, service, HPA, load-generator
```
Depois, no Console/CLI, **na ordem**:
```bash
# node group
aws eks delete-nodegroup --region "$REGIAO" --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP"
aws eks wait nodegroup-deleted --region "$REGIAO" --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP"
# cluster
aws eks delete-cluster --region "$REGIAO" --name "$CLUSTER"
aws eks wait cluster-deleted --region "$REGIAO" --name "$CLUSTER"
# stack da VPC
aws cloudformation delete-stack --region "$REGIAO" --stack-name av1-vpc
aws cloudformation wait stack-delete-complete --region "$REGIAO" --stack-name av1-vpc
```
Remova as **2 roles IAM** (`av1-eks-cluster-role`, `av1-eks-node-role`) — a role do nó pode exigir
antes removê-la do *instance profile* criado pelo EKS. Se usou ECR, apague o repositório.

**Verificação final:**
```bash
aws eks list-clusters --region "$REGIAO" --output text            # vazio
aws ec2 describe-instances --region "$REGIAO" \
  --filters "Name=tag:eks:nodegroup-name,Values=$NODEGROUP" \
  --query 'Reservations[].Instances[].State.Name' --output text    # vazio/terminated
```
📸 **Tela 13:** verificação final mostrando os recursos removidos (custo zerado).

---

## Resumo das evidências a coletar (6 a 8, conforme o enunciado)
1. Identidade AWS e região (Tela 1).
2. Cluster/node group ativos (Telas 4–5).
3. Nós Ready + Metrics Server (Tela 6).
4. Baseline: 1 réplica (Tela 7).
5. Escala **sobe** sob carga (Tela 8).
6. Réplicas **distribuídas entre nós** — diferencial do EKS (Tela 9).
7. Escala **desce** ao fim da carga (Tela 11).
8. Limpeza verificada (Tela 13).

> **Diferença-chave vs. Minikube:** aqui o Metrics Server é instalado manualmente, a imagem vem de um
> registry, e as réplicas se **distribuem entre múltiplos nós**. Note que o HPA escala **Pods**, não
> **nós**: se o teto de réplicas exigisse mais capacidade, seria preciso um **Cluster Autoscaler**.
