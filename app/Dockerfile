# Dockerfile - PSI5120 Avaliacao Intermediaria 1
# Imagem do servidor web didatico usado nas duas implantacoes (Minikube e EKS).
# O objetivo do app e gerar carga de CPU por requisicao para acionar o HPA.

# Imagem base: PHP com Apache ja embutido (serve index.php automaticamente).
# Tag versionada (nao "latest") para garantir reprodutibilidade entre Minikube e EKS.
FROM php:8.2-apache

# Metadados da imagem (boa pratica; util para rastreabilidade).
LABEL org.opencontainers.image.title="PSI5120 Av1 - WebCPU" \
      org.opencontainers.image.description="Servidor web que consome CPU por requisicao para demonstrar HPA"

# Copia a aplicacao para o diretorio raiz servido pelo Apache.
# O Apache do php:apache serve /var/www/html/ por padrao.
COPY index.php /var/www/html/index.php

# O container escuta na porta 80 (padrao do Apache).
EXPOSE 80

# Nao definimos CMD/ENTRYPOINT: a imagem base ja inicia o Apache em foreground
# (apache2-foreground), servindo a aplicacao.
