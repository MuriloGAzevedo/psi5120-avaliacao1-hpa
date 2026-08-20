# Roteiro B — Implantação em Nuvem (AWS EKS) com HPA

Passo a passo para reproduzir a mesma solução (servidor web + HPA + teste de estresse) em um cluster
gerenciado **Amazon EKS**, via **Console + AWS CloudShell**. Região de referência: `us-east-1`.

> ⚠️ **Custo e limpeza:** EKS, nós EC2 e volumes geram cobrança. Executar tudo em sessão curta e **remover
> os recursos ao final** (Seção 7). Usar identidade IAM **administrativa não-root**; o CloudShell usa
> credenciais temporárias — **não** criar access keys de longa duração.

## 1. Cluster EKS + node group

Seguir o fluxo já validado (Console → EKS → Create cluster; depois Compute → Add node group). Parâmetros:
cluster `av1-eks`, node group `av1-ng` com **2× t3.small** (ou t3.medium) para haver capacidade de escala,
região `us-east-1`. Conectar o CloudShell:

```bash
export AWS_PAGER=""; export REGIAO=us-east-1; export CLUSTER=av1-eks
aws eks update-kubeconfig --region "$REGIAO" --name "$CLUSTER"
kubectl get nodes -o wide
```

## 2. Instalar o Metrics Server (o EKS não o traz por padrão)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s
kubectl top nodes
```

## 3. Publicar a imagem em um registry acessível ao EKS

No EKS a imagem precisa vir de um registry (Amazon ECR ou Docker Hub), diferente do `minikube image load`:

```bash
# Exemplo com Amazon ECR (na conta do aluno):
aws ecr create-repository --repository-name av1-webcpu --region "$REGIAO"
# autenticar o Docker no ECR, docker build, docker tag e docker push (ver script)
```
Ajustar `image:` no `k8s/01-deployment.yaml` para o URI do ECR/Docker Hub.

## 4. Implantar Deployment, Service e HPA (mesmos manifestos da Implantação A)

```bash
kubectl apply -f k8s/00-namespace.yaml -f k8s/01-deployment.yaml -f k8s/02-service.yaml
kubectl rollout status deployment/web -n av1 --timeout=180s
kubectl apply -f k8s/03-hpa.yaml
kubectl get deployment,hpa,pods -n av1
```

## 5. Teste de estresse — scale UP

```bash
kubectl apply -f k8s/04-load-generator.yaml
kubectl get hpa web -n av1 -w
kubectl get pods -n av1 -l app=web -o wide     # observar se os Pods se distribuem entre nós
kubectl top pods -n av1 -l app=web
```
**Screenshots:** HPA com CPU > 50% e réplicas subindo; Pods distribuídos entre os nós EC2; `kubectl top`.

## 6. Fim da carga — scale DOWN

```bash
kubectl delete -f k8s/04-load-generator.yaml
kubectl get hpa web -n av1 -w     # réplicas retornam a 1 após a janela de estabilização
```

## 7. Limpeza (obrigatória)

```bash
kubectl delete namespace av1
# remover node group e cluster (Console ou CLI), o repositório ECR e verificar resíduos:
aws ecr delete-repository --repository-name av1-webcpu --region "$REGIAO" --force
```
Confirmar no Console que EKS, EC2, EBS e ECR da atividade não deixaram recursos.

> Diferença-chave vs. Minikube: no EKS o **Metrics Server é instalado manualmente**, a **imagem vem de um
> registry**, os Pods podem se **distribuir entre múltiplos nós**, e a **capacidade de nós** (não só de Pods)
> pode precisar escalar — o que o HPA sozinho não faz (exigiria Cluster Autoscaler/Karpenter).
