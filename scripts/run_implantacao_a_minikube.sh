#!/usr/bin/env bash
# PSI5120 Avaliacao Intermediaria 1 - Implantacao A (Minikube + HPA)
# Uso: run_av1_minikube.sh "<PESSOA>" <WORKDIR com app/ e k8s/>
set -uo pipefail
PERSON="${1:?informe a pessoa}"
WORKDIR="${2:?informe o workdir}"
cd "$WORKDIR"
EVID="$WORKDIR/evidencias_minikube"; rm -rf "$EVID"; mkdir -p "$EVID"
NS=av1; PROFILE=av1-local
HOSTN="$(hostname)"
line(){ echo "----------------------------------------------------------------"; }
stamp(){ date +%H:%M:%S; }

# cluster limpo por pessoa (dados/timestamps independentes)
minikube delete -p "$PROFILE" >/dev/null 2>&1 || true

########## E1 - Ambiente: cluster + metrics-server ##########
{
  echo "== Av1 | Implantacao A (Minikube) | E1 - Ambiente + Metrics Server =="
  echo "Pessoa: $PERSON | Host: $HOSTN | Data: $(date -Is)"; line
  echo "\$ minikube start -p av1-local --driver=docker"
  minikube start -p "$PROFILE" --driver=docker
  kubectl wait --for=condition=Ready nodes --all --timeout=150s >/dev/null 2>&1 || true
  line; echo "\$ minikube addons enable metrics-server -p av1-local"
  minikube addons enable metrics-server -p "$PROFILE"
  line; echo "\$ kubectl get nodes -o wide"; kubectl get nodes -o wide
  echo "\$ kubectl version (server)"; kubectl version 2>/dev/null | grep -i server
} > "$EVID/E1_ambiente.txt" 2>&1
echo "E1 done"

# construir a imagem propria e carregar no cluster
docker build -t av1-webcpu:v1 "$WORKDIR/app" >/dev/null 2>&1
minikube image load av1-webcpu:v1 -p "$PROFILE" >/dev/null 2>&1 || true

########## E2 - Deploy + Service + HPA ##########
{
  echo "== Av1 | Implantacao A | E2 - Deployment, Service e HPA =="
  echo "Pessoa: $PERSON | Data: $(date -Is)"; line
  echo "\$ kubectl apply -f k8s/00-namespace.yaml -f k8s/01-deployment.yaml -f k8s/02-service.yaml"
  kubectl apply -f k8s/00-namespace.yaml -f k8s/01-deployment.yaml -f k8s/02-service.yaml
  kubectl rollout status deployment/web -n "$NS" --timeout=180s
  line; echo "\$ kubectl apply -f k8s/03-hpa.yaml"; kubectl apply -f k8s/03-hpa.yaml
  line; echo "aguardando o Metrics Server reportar CPU ao HPA (pode levar ~1-2 min)..."
  for i in $(seq 1 24); do
    OUT="$(kubectl get hpa web -n "$NS" --no-headers 2>/dev/null)"
    echo "$OUT" | grep -q "<unknown>" || { echo "métricas disponíveis."; break; }
    sleep 5
  done
  line; echo "\$ kubectl get deployment,hpa,pods -n av1"; kubectl get deployment,hpa,pods -n "$NS"
} > "$EVID/E2_deploy_hpa.txt" 2>&1
echo "E2 done"

########## E3 - Baseline (antes da carga) ##########
{
  echo "== Av1 | Implantacao A | E3 - BASELINE (antes do teste de estresse) =="
  echo "Pessoa: $PERSON | Data: $(date -Is) | hora=$(stamp)"; line
  echo "\$ kubectl get hpa web -n av1"; kubectl get hpa web -n "$NS"
  echo "\$ kubectl get pods -n av1 -l app=web"; kubectl get pods -n "$NS" -l app=web
  echo "\$ kubectl top pods -n av1 -l app=web"; kubectl top pods -n "$NS" -l app=web 2>&1
} > "$EVID/E3_baseline.txt" 2>&1
echo "E3 done"

########## E4 - Carga: escala SOBE ##########
{
  echo "== Av1 | Implantacao A | E4 - TESTE DE ESTRESSE: escala SOBE =="
  echo "Pessoa: $PERSON | Data: $(date -Is)"; line
  echo "\$ kubectl apply -f k8s/04-load-generator.yaml   (inicia a carga)"
  kubectl apply -f k8s/04-load-generator.yaml
  echo "hora de inicio da carga: $(stamp)"; line
  echo "Linha do tempo (HPA e nº de Pods a cada 20s):"
  MAXREP=1
  for i in $(seq 1 18); do
    H="$(kubectl get hpa web -n "$NS" --no-headers 2>/dev/null)"
    NP="$(kubectl get pods -n "$NS" -l app=web --no-headers 2>/dev/null | grep -c Running)"
    REP="$(echo "$H" | awk '{print $NF}')"
    printf '[%s] HPA: %s | Pods Running(app=web): %s\n' "$(stamp)" "$H" "$NP"
    [ "${REP:-1}" -gt "$MAXREP" ] 2>/dev/null && MAXREP=$REP
    # parar cedo se ja escalou bem e estabilizou perto do teto
    sleep 20
  done
  line; echo "pico de replicas desejadas observado (REPLICAS do HPA): $MAXREP"
} > "$EVID/E4_carga_subida.txt" 2>&1
echo "E4 done"

########## E5 - Pico (durante a carga) ##########
{
  echo "== Av1 | Implantacao A | E5 - PICO (durante o estresse) =="
  echo "Pessoa: $PERSON | Data: $(date -Is) | hora=$(stamp)"; line
  echo "\$ kubectl get hpa web -n av1"; kubectl get hpa web -n "$NS"
  echo "\$ kubectl get deployment web -n av1"; kubectl get deployment web -n "$NS"
  echo "\$ kubectl get pods -n av1 -l app=web -o wide"; kubectl get pods -n "$NS" -l app=web -o wide
  echo "\$ kubectl top pods -n av1 -l app=web"; kubectl top pods -n "$NS" -l app=web 2>&1
  echo "\$ kubectl describe hpa web -n av1 (eventos de escala)"; kubectl describe hpa web -n "$NS" 2>&1 | sed -n '1,40p'
} > "$EVID/E5_pico.txt" 2>&1
echo "E5 done"

########## E6 - Remover carga: escala DESCE ##########
{
  echo "== Av1 | Implantacao A | E6 - FIM DA CARGA: escala DESCE =="
  echo "Pessoa: $PERSON | Data: $(date -Is)"; line
  echo "\$ kubectl delete -f k8s/04-load-generator.yaml   (encerra a carga)"
  kubectl delete -f k8s/04-load-generator.yaml
  echo "hora do fim da carga: $(stamp)"; line
  echo "Linha do tempo da reducao (janela de estabilizacao de scaleDown = 300s):"
  for i in $(seq 1 24); do
    H="$(kubectl get hpa web -n "$NS" --no-headers 2>/dev/null)"
    NP="$(kubectl get pods -n "$NS" -l app=web --no-headers 2>/dev/null | grep -c Running)"
    REP="$(echo "$H" | awk '{print $NF}')"
    printf '[%s] HPA: %s | Pods Running(app=web): %s\n' "$(stamp)" "$H" "$NP"
    [ "${REP:-9}" = "1" ] && { echo "voltou a 1 replica (estado inicial)."; break; }
    sleep 20
  done
  line; echo "\$ kubectl get hpa,pods -n av1 -l app=web"; kubectl get hpa web -n "$NS"; kubectl get pods -n "$NS" -l app=web
  echo "\$ kubectl describe hpa web -n av1 (eventos finais)"; kubectl describe hpa web -n "$NS" 2>&1 | sed -n '/Events:/,$p'
} > "$EVID/E6_reducao.txt" 2>&1
echo "E6 done"

########## Metadados ##########
{
  echo "== Av1 | Implantacao A (Minikube) | Metadados | $PERSON =="
  echo "Data: $(date -Is) | Host: $HOSTN | Usuario: $(id -un)"; line
  echo "\$ minikube version"; minikube version | head -1
  echo "\$ kubectl version"; kubectl version 2>/dev/null
  echo "\$ docker --version"; docker --version
  echo "\$ kubectl get nodes -o wide"; kubectl get nodes -o wide
  echo "\$ nproc / free -h"; nproc; free -h | head -2
} > "$EVID/metadados.txt" 2>&1
echo "META done"
echo "=== IMPLANTACAO A (MINIKUBE) CONCLUIDA para $PERSON ==="
ls -la "$EVID"
