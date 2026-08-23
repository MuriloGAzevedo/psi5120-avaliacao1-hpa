# PSI5120 — Avaliação Intermediária 1 — Autoescalamento Horizontal (HPA) em Kubernetes

Projeto que implanta e testa um **servidor web** em Kubernetes com **Horizontal Pod Autoscaler (HPA)**,
em duas plataformas:

- **Implantação A (Local):** cluster **Minikube**.
- **Implantação B (Nuvem):** cluster gerenciado **AWS EKS**.

O objetivo é observar o HPA **escalar automaticamente** o número de réplicas do servidor web sob **teste de
carga (estresse de CPU)** e **reduzir** as réplicas quando a carga cessa, comparando as duas plataformas.

**Autores (grupo):** Murilo Gabriel Moraes de Azevedo (13782776), Bruno Valle Martins (13681036),
Pedro Remus de Ávila (13682486) · PSI5120 — 2026.

> ⭐ **Execução de referência:** as evidências em `evidencias/` (Minikube + EKS) são da execução realizada por
> **Murilo** e servem de referência do grupo. Cada integrante deve reproduzir as duas implantações seguindo o
> **[GUIA_EXECUCAO_PARA_O_GRUPO.md](GUIA_EXECUCAO_PARA_O_GRUPO.md)** e guardar suas próprias evidências.

## Estrutura do repositório

```
.
├── app/                         # servidor web que consome CPU por requisição
│   ├── Dockerfile               #   imagem própria (php:apache), comentado
│   └── index.php                #   handler que gera carga de CPU (laço de sqrt)
├── k8s/                         # manifestos Kubernetes (comentados)
│   ├── 00-namespace.yaml        #   namespace av1
│   ├── 01-deployment.yaml       #   Deployment web (requests/limits de CPU)
│   ├── 02-service.yaml          #   Service ClusterIP
│   ├── 03-hpa.yaml              #   HorizontalPodAutoscaler (alvo 50% CPU, 1..10)
│   └── 04-load-generator.yaml   #   gerador de carga (teste de estresse)
├── scripts/                     # automações
│   ├── run_implantacao_a_minikube.sh   # executa a Implantação A ponta a ponta
│   └── run_implantacao_b_eks.sh        # comandos da Implantação B (EKS)
├── roteiros/                    # passo a passo documentado
│   ├── roteiro_A_minikube.md
│   └── roteiro_B_eks.md
├── evidencias/                  # saídas dos experimentos (antes/durante/depois)
│   ├── minikube/
│   └── eks/
└── artigo/                      # artigo técnico (IEEE, LaTeX + PDF)
```

## Como o HPA é exercitado (resumo)

1. **Metrics Server** ativo fornece as métricas de CPU (no Minikube via addon; no EKS via manifesto oficial).
2. O **Deployment** declara `resources.requests.cpu` — base sobre a qual o HPA calcula a utilização.
3. O **HPA** mantém a utilização média de CPU em **~50%**, escalando entre **1 e 10** réplicas.
4. O **gerador de carga** envia requisições HTTP em laço, elevando a CPU e forçando o **scale up**.
5. Ao **remover** a carga, o HPA executa o **scale down** (após a janela de estabilização de 300 s).

## Reprodução rápida

- **Local (Minikube):** `bash scripts/run_implantacao_a_minikube.sh` (requer Docker + Minikube + kubectl).
- **Nuvem (EKS):** seguir `roteiros/roteiro_B_eks.md` (requer conta AWS; comandos em `scripts/run_implantacao_b_eks.sh`).

> **Nota de integridade:** execução prática individual por integrante; artigo redigido em grupo. Nenhuma
> credencial, chave ou token é versionada neste repositório.
