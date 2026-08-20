# Roteiro A — Implantação Local (Minikube) com HPA

Passo a passo para implantar o servidor web com **Horizontal Pod Autoscaler** no **Minikube** e executar o
teste de estresse. Ambiente de referência: Ubuntu 24.04 com Docker; Minikube (driver `docker`); `kubectl`.

## Pré-requisitos

- Docker funcional (`docker version` mostra Client e Server).
- `kubectl` e `minikube` instalados.
- ~2 GiB de RAM livres para o cluster local.

## 1. Criar o cluster e habilitar o Metrics Server

```bash
minikube start -p av1-local --driver=docker
kubectl wait --for=condition=Ready nodes --all --timeout=150s
# O HPA por CPU depende do Metrics Server, que fornece as métricas dos Pods:
minikube addons enable metrics-server -p av1-local
kubectl get nodes -o wide
```

## 2. Construir e carregar a imagem do servidor web

```bash
# Constrói a imagem própria (Dockerfile em app/):
docker build -t av1-webcpu:v1 app/
# Carrega a imagem no cluster Minikube (evita depender de registry remoto):
minikube image load av1-webcpu:v1 -p av1-local
```

## 3. Implantar Deployment, Service e HPA

```bash
kubectl apply -f k8s/00-namespace.yaml -f k8s/01-deployment.yaml -f k8s/02-service.yaml
kubectl rollout status deployment/web -n av1 --timeout=180s
kubectl apply -f k8s/03-hpa.yaml
# Aguarde ~1-2 min até o HPA sair de <unknown> e mostrar a utilização de CPU:
kubectl get deployment,hpa,pods -n av1
```

## 4. Registrar o baseline (antes da carga)

```bash
kubectl get hpa web -n av1            # esperado: cpu ~0%/50%, REPLICAS 1
kubectl get pods -n av1 -l app=web    # 1 Pod Running
kubectl top pods -n av1 -l app=web    # CPU baixa (poucos milicores)
```

## 5. Teste de estresse — observar o scale UP

```bash
# Inicia a carga (gerador de requisições HTTP em laço):
kubectl apply -f k8s/04-load-generator.yaml
# Acompanhe o HPA subir a utilização e aumentar as réplicas:
kubectl get hpa web -n av1 -w
# (em outro terminal) acompanhe os Pods surgindo:
kubectl get pods -n av1 -l app=web -w
kubectl top pods -n av1 -l app=web
kubectl describe hpa web -n av1       # eventos "SuccessfulRescale"
```

**Capturar screenshots:** (a) HPA com CPU acima de 50% e REPLICAS aumentando; (b) lista de Pods `Running`
multiplicada; (c) `kubectl top` mostrando consumo; (d) eventos do `describe hpa`.

## 6. Fim da carga — observar o scale DOWN

```bash
# Encerra a carga:
kubectl delete -f k8s/04-load-generator.yaml
# Após a janela de estabilização (300 s), o HPA reduz as réplicas de volta a 1:
kubectl get hpa web -n av1 -w
kubectl get pods -n av1 -l app=web
kubectl describe hpa web -n av1       # eventos de redução
```

**Capturar screenshots:** HPA voltando a ~0%/50% e REPLICAS retornando a 1; Pods extras em `Terminating`.

## 7. Limpeza

```bash
kubectl delete namespace av1
minikube delete -p av1-local
```

> Execução automatizada equivalente: `bash scripts/run_implantacao_a_minikube.sh "<Seu Nome>" <dir-do-projeto>`.
