# Screenshots da Implantação B (EKS) — Murilo

Salve aqui os arquivos de imagem (`.png`) dos prints que você tirou durante a execução do EKS.
Sugestão de nomes (para casar com o roteiro e o artigo):

| Arquivo sugerido | Conteúdo |
|---|---|
| `01-identidade.png` | `aws sts get-caller-identity` (Arn não-root, us-east-1) |
| `02-roles-iam.png` | roles `av1-eks-cluster-role` e `av1-eks-node-role` no IAM |
| `03-vpc-complete.png` | stack `av1-vpc` em `CREATE_COMPLETE` + Outputs |
| `04-cluster-active.png` | cluster `av1-eks` em estado **Ativo** (v1.36) |
| `05-nodegroup-active.png` | node group `av1-ng` **Ativo** (2× t3.medium) |
| `06-nodes-ready.png` | `kubectl get nodes -o wide` (2 nós Ready) + `top nodes` |
| `07-baseline.png` | `get deployment,hpa,pods` no baseline (1 réplica) |
| `08-scaleup-timeline.png` | linha do tempo do HPA subindo (1→3→5→9→10) |
| `09-distribuicao.png` | `get pods -o wide` — réplicas 5/5 entre os 2 nós |
| `10-top-events.png` | `top pods` + eventos `SuccessfulRescale` |
| `11-scaledown.png` | HPA voltando a 1 réplica após 300s |
| `12-limpeza.png` | verificação final (tudo vazio) |
| `13-billing.png` | Billing month-to-date (~US$ 0,19) |

As saídas em texto correspondentes estão em `evidencias_eks.txt` (nesta pasta).
