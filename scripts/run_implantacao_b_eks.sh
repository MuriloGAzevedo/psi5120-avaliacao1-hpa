#!/usr/bin/env bash
# PSI5120 Avaliacao 1 - Implantacao B (EKS) - comandos de apoio para o CloudShell.
# NAO executa criacao de cluster automaticamente: o cluster e o node group sao
# criados pelo Console (ver roteiros/roteiro_B_eks.md). Este script cobre a parte
# de kubectl (metrics-server, deploy, HPA, teste de carga) e a limpeza da aplicacao.
# Uso: definir as variaveis abaixo e executar bloco a bloco no CloudShell.
set -uo pipefail
export AWS_PAGER=""
export REGIAO="${REGIAO:-us-east-1}"
export CLUSTER="${CLUSTER:-av1-eks}"
NS=av1

echo "== conectar kubectl ao cluster EKS =="
aws eks update-kubeconfig --region "$REGIAO" --name "$CLUSTER"
kubectl get nodes -o wide

echo "== instalar o Metrics Server (o EKS nao traz por padrao) =="
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s
kubectl top nodes

echo "== aplicar Deployment, Service e HPA =="
# ATENCAO: ajustar 'image:' em k8s/01-deployment.yaml para o URI do ECR/Docker Hub
kubectl apply -f k8s/00-namespace.yaml -f k8s/01-deployment.yaml -f k8s/02-service.yaml
kubectl rollout status deployment/web -n "$NS" --timeout=180s
kubectl apply -f k8s/03-hpa.yaml
kubectl get deployment,hpa,pods -n "$NS" -o wide

echo "== baseline =="
kubectl get hpa web -n "$NS"; kubectl top pods -n "$NS" -l app=web

echo "== teste de estresse: scale UP (observe e capture screenshots) =="
kubectl apply -f k8s/04-load-generator.yaml
echo "acompanhe: kubectl get hpa web -n $NS -w   e   kubectl get pods -n $NS -l app=web -o wide"

echo "== fim da carga: scale DOWN =="
echo "quando terminar de observar a subida, execute:"
echo "  kubectl delete -f k8s/04-load-generator.yaml"
echo "  kubectl get hpa web -n $NS -w   # replicas retornam a 1 apos ~300s"

echo "== limpeza da aplicacao (o cluster/node group sao removidos pelo Console) =="
echo "  kubectl delete namespace $NS"
