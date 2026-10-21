# Flexera Ocean

## Resumo

O **Ocean** é a plataforma de otimização de infraestrutura para containers originalmente criada pela Spot.io (adquirida pela NetApp e, em 2025, pela Flexera). Ele atua como um motor de infraestrutura "serverless" para clusters Kubernetes (EKS, AKS, GKE) e Amazon ECS: em vez de gerenciar node groups e Auto Scaling Groups manualmente, você delega ao Ocean a escolha, o provisionamento e a remoção dos nós com base no que os workloads realmente precisam.

O objetivo principal é **reduzir custos de computação** (usando majoritariamente instâncias Spot) **sem perder disponibilidade**, mantendo o cluster sempre dimensionado de acordo com a demanda real dos pods.

## Como funciona

1. **Ocean Controller** — um componente instalado dentro do cluster (via Helm) que coleta métricas e o estado dos pods, nós e requisições de recursos, enviando essas informações para o SaaS da Flexera/Spot.
2. **Escalonamento orientado a containers** — o Ocean observa pods pendentes (`Pending`) e as requisições de CPU, memória e GPU, e decide quais tipos e tamanhos de instância lançar para acomodá-los da forma mais eficiente (bin packing).
3. **Virtual Node Groups (VNGs)** — substituem os node groups tradicionais. Cada VNG define configurações como AMI, labels, taints, subnets, tipos de instância permitidos e user data. Os pods são direcionados aos VNGs via labels, taints/tolerations e affinity, como no Kubernetes padrão.
4. **Escolha de instâncias e mercados** — o Ocean considera uma ampla lista de tipos de instância e zonas de disponibilidade, priorizando Spot e fazendo *fallback* automático para On-Demand quando não há capacidade Spot disponível.
5. **Scale down contínuo** — nós subutilizados são identificados, os pods são drenados respeitando PodDisruptionBudgets, e as instâncias são removidas para evitar desperdício.

## Principais funcionalidades

- **Uso inteligente de instâncias Spot** — previsão de interrupções baseada em machine learning, substituindo nós de forma proativa antes que a AWS/Azure/GCP os reclame, com drenagem controlada dos pods.
- **Fallback para On-Demand** — garante disponibilidade quando não há capacidade Spot, voltando para Spot assim que possível.
- **Aproveitamento de compromissos (RIs e Savings Plans)** — prioriza capacidade já contratada antes de lançar novas instâncias Spot ou On-Demand.
- **Headroom** — mantém uma reserva de capacidade livre (automática ou manual) para que novos pods sejam agendados imediatamente, sem esperar a subida de um nó.
- **Bin packing e otimização de nós** — escolhe combinações de instâncias que minimizam recursos ociosos.
- **Right-Sizing de workloads** — analisa o consumo real dos containers e recomenda (ou aplica automaticamente) ajustes de `requests` de CPU e memória.
- **Agendamento (Scheduling)** — horários de desligamento do cluster (*shutdown hours*) para ambientes de dev/teste e tarefas agendadas como *cluster roll*.
- **Cluster Roll** — atualização gradual dos nós (por exemplo, troca de AMI ou versão do Kubernetes) sem indisponibilidade.
- **Análise de custos e showback** — visualização de custos por namespace, deployment, label ou anotação, facilitando o rateio entre times.
- **Suporte a GPU e workloads especializados** — seleção de instâncias adequadas para workloads que exigem GPU ou arquiteturas específicas (ex.: ARM/Graviton).
- **Ocean CD** — extensão para entrega progressiva (canary e blue/green) de aplicações no Kubernetes.
- **Infraestrutura como código** — gerenciável via Terraform (provider `spotinst`), API REST e consoles da Flexera/Spot.

## Quando usar

- Clusters Kubernetes ou ECS com custo relevante de computação.
- Workloads tolerantes a interrupção (stateless, batch, CI/CD) que se beneficiam de Spot.
- Times que querem reduzir o esforço operacional de gerenciar node groups, autoscaling e tipos de instância.
