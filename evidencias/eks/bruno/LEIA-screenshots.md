# Screenshots da Implantação B (EKS) — Bruno Valle Martins (13681036)

Execução individual no Amazon EKS, região `us-east-1`, cluster `av1-eks` (Kubernetes 1.36),
node group `av1-ng2` (2× `t3.medium`).

As saídas em texto correspondentes estão em `evidencias_eks.txt`, nesta pasta. Os manifestos
efetivamente aplicados estão em `manifestos-aplicados-bruno.yaml`.

| Arquivo | Conteúdo |
|---|---|
| `01-identidade.png` | `aws sts get-caller-identity`, Arn de usuário IAM não-root (`psi5120-admin`), Account ID mascarado |
| `02-roles-iam.png` | roles `av1-eks-cluster-role` e `av1-eks-node-role` na lista do IAM |
| `03-vpc-complete.png` | stack `av1-vpc` em `CREATE_COMPLETE` com os Outputs (VpcId, SubnetIds, SecurityGroups) |
| `04-cluster-active.png` | cluster `av1-eks` em estado **Active**, versão 1.36, EKS Auto Mode desligado |
| `05-nodegroup-active.png` | node group `av1-ng2` **Active**, 2× `t3.medium`, Desired/Min/Max 2/2/2 |
| `06-nodes-ready.png` | `kubectl get nodes -o wide` com 2 nós Ready, mais `kubectl top nodes` com métricas |
| `07-baseline.png` | estado ANTES da carga: deployment `1/1`, HPA `cpu: 0%/50%`, 1 réplica, coluna NODE |
| `08-scaleup-timeline-01.png` | linha do tempo do HPA, de 1 para 2 e 5 réplicas, CPU chegando a 250% |
| `08-scaleup-timeline-02.png` | continuação, teto de 10 réplicas alcançado em 85 s, platô entre 82% e 95% |
| `08-scaleup-timeline-03.png` | platô sustentado com 10 réplicas |
| `09-distribuicao.png` | 10 réplicas distribuídas 5/5 entre os dois nós, diferencial do EKS frente ao Minikube |
| `10-top-events.png` | `kubectl top pods` por réplica (124m a 265m) e eventos `SuccessfulRescale` da subida |
| `11-scaledown.png` | linha do tempo da redução: CPU em 0% com 10 réplicas por 4 min 49 s, depois queda para 1 |
| `11b-events-ciclo-completo.png` | eventos do HPA com o ciclo completo: `New size` 2, 5 e 10 na subida e 1 na descida |
| `12-limpeza.png` | verificação final da limpeza, todas as consultas vazias e instâncias `terminated` |
| `13-billing.png` | decomposição de custos de agosto/2026 agrupada por serviço, com Amazon EKS, EC2-Compute e Amazon VPC identificados. Granularidade mensal, ver observação em E9 do `evidencias_eks.txt` |

## Observações sobre as imagens

- Os prints tirados do Console AWS foram recortados acima da barra de navegação, de forma a não
  incluir o identificador da conta.
- No `01-identidade.png` o identificador da conta foi coberto com retângulo opaco, porque aparece
  dentro do texto da saída do comando.
- O `11-scaledown.png` foi obtido a partir do arquivo de log gravado durante a execução, e não da
  tela ao vivo, porque a sessão do CloudShell reconectou por ociosidade durante a fase de redução.
  Os dados são os mesmos, gravados pelo laço de observação. Detalhes na nota N5 de
  `evidencias_eks.txt`.
- Os warnings `FailedGetResourceMetric` visíveis em `10-top-events.png` e
  `11b-events-ciclo-completo.png` são anteriores ao experimento e correspondem ao período em que a
  Metrics API estava indisponível. Explicação completa nas notas N3 e N4 de `evidencias_eks.txt`.
- O `13-billing.png` foi capturado com granularidade mensal, e não diária. No momento da consulta o
  Cost Explorer não retornava o detalhamento diário por serviço. Como a conta não registra outro uso
  relevante em agosto de 2026, o total do mês equivale ao custo do experimento. Os três serviços da
  legenda correspondem exatamente aos componentes da implantação: control plane, nós e rede.
