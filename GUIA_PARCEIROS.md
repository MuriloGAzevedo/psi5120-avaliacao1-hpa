# Guia para o grupo — Avaliação Intermediária 1 (HPA em Kubernetes)

**Grupo:** Murilo Gabriel Moraes de Azevedo (NUSP 13782776), Bruno Valle Martins (NUSP 13681036),
Pedro Remus de Ávila (NUSP 13682486).

Este repositório reúne todo o material do trabalho. Leia este guia antes de começar.

## O que o trabalho pede (resumo)
Implantar um servidor web em Kubernetes com **HPA (autoescalamento horizontal)** e testá-lo sob carga,
em **duas plataformas obrigatórias**: **A) Minikube (local)** e **B) AWS EKS (nuvem)**. Entregáveis:
roteiros, código/manifestos comentados, **screenshots**, **artigo técnico IEEE (≥6 páginas)** e o **link
deste repositório**. O artigo pode ser em grupo (os três nomes constam); **cada aluno faz e valida a sua
própria implantação** e submete individualmente no Moodle.

## O que JÁ está pronto
- **Implantação A (Minikube):** executada e documentada (evidências reais em `evidencias/minikube/`).
  O HPA escalou 1$\to$4$\to$8$\to$10 sob carga e voltou a 1 após a janela de 300 s.
- **Código e manifestos comentados:** `app/` (Dockerfile + index.php) e `k8s/` (Deployment, Service, HPA,
  gerador de carga).
- **Artigo IEEE:** `artigo/artigo_av1_hpa.tex` (+ PDF) — com a Implantação A completa; a seção do EKS será
  preenchida após a execução (Passo abaixo).
- **Roteiros:** `roteiros/roteiro_A_minikube.md` e `roteiros/roteiro_B_eks.md` (passo a passo detalhado).

## O que CADA integrante precisa fazer (execução individual)
1. **Implantação A (Minikube):** rodar na sua máquina (Docker + Minikube + kubectl) seguindo
   `roteiros/roteiro_A_minikube.md` — ou reexecutar o `scripts/run_implantacao_a_minikube.sh` — e **tirar
   os screenshots** do HPA subindo e descendo. (As evidências textuais já no repo servem de referência.)
2. **Implantação B (AWS EKS):** na **sua própria conta AWS**, seguir o passo a passo completo de
   `roteiros/roteiro_B_eks.md`, que indica **exatamente quais telas printar** (📸) em cada etapa.
   ⚠️ Gera custo pequeno (~US$ 0,50–1,00); **limpar tudo no mesmo dia** (Passo 10 do roteiro).
3. **Guardar os screenshots** de cada um (sugestão: `evidencias/minikube/<seu-nome>/` e
   `evidencias/eks/<seu-nome>/`).

## O que ainda falta no artigo
A seção **"Implantação B --- Amazon EKS"** está marcada como *[execução em andamento]*. Após rodar o EKS,
insira a tabela da linha do tempo do HPA (análoga à do Minikube), o tempo de reação e a observação sobre a
**distribuição das réplicas entre nós**. Com isso o artigo passa de ~5 para **mais de 6 páginas**.

## Como compilar o artigo
Requer LaTeX (ex.: MiKTeX/TeX Live). Duas passadas:
```bash
pdflatex artigo/artigo_av1_hpa.tex && pdflatex artigo/artigo_av1_hpa.tex
```

## Submissão
Cada integrante submete individualmente no Moodle: o **PDF do artigo** + o **link deste repositório**.
Se o repositório for privado, liberar acesso aos docentes.
