<?php
// index.php - PSI5120 Avaliacao Intermediaria 1
// Servidor web didatico para demonstrar o Horizontal Pod Autoscaler (HPA).
// A cada requisicao HTTP, o processo executa um laco de calculo (raiz quadrada)
// que consome CPU de forma mensuravel. Isso eleva a utilizacao de CPU do Pod,
// permitindo que o HPA observe a metrica e decida escalar horizontalmente.
//
// Referencia conceitual: a mesma logica da imagem oficial
// registry.k8s.io/hpa-example usada no walkthrough do Kubernetes (Referencia 1).

$x = 0.0001;
// 1.000.000 de iteracoes de sqrt() geram carga de CPU suficiente para,
// sob varias requisicoes concorrentes, ultrapassar o alvo de utilizacao do HPA.
for ($i = 0; $i <= 1000000; $i++) {
    $x += sqrt($x);
}

// Resposta simples: identifica o Pod (hostname) que atendeu a requisicao.
// Ver qual Pod respondeu ajuda a evidenciar o balanceamento entre as replicas.
header('Content-Type: text/plain; charset=utf-8');
echo "PSI5120 - Avaliacao 1 - servidor web com carga de CPU\n";
echo "OK! Pod: " . gethostname() . "\n";
?>
