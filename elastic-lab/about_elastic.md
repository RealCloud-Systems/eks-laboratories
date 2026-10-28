# Flexera Elastigroup

## Resumo

O **Elastigroup** é o serviço de gerenciamento de grupos de instâncias da Spot.io (adquirida pela NetApp e, em 2025, pela Flexera). Ele ocupa o lugar de um **Auto Scaling Group** da AWS (ou de um Managed Instance Group no GCP e de um Scale Set na Azure): você define a imagem, a rede, a capacidade e as políticas de escala, e o Elastigroup lança, monitora e substitui as instâncias, usando majoritariamente instâncias **Spot**.

Enquanto o [Ocean](../ocean-lab/about_ocean.md) é orientado a containers (ele olha para os pods pendentes e escolhe os nodes), o Elastigroup é orientado a **instâncias**: ele mantém uma quantidade de máquinas idênticas rodando a mesma aplicação, como um ASG. É a opção indicada para workloads em VMs: aplicações web stateless, workers de filas, jobs de batch, agentes de CI e qualquer serviço que hoje roda em um Auto Scaling Group.

O objetivo é o mesmo do Ocean: **reduzir o custo de computação** com Spot (até 90% mais barato que On-Demand) **sem perder disponibilidade**.

## Como funciona

1. **Grupo** — o Elastigroup é criado no SaaS da Spot (ID com prefixo `sig-`) e guarda toda a configuração: AMI, user data, instance profile, security groups, subnets, tipos de instância e capacidade. Ele não cria um ASG nem um Launch Template na AWS: as instâncias são lançadas diretamente pela role da Spot na sua conta.
2. **Capacidade** — como em um ASG, o grupo tem `min`, `max` e `target` (desired). A capacidade pode ser medida em **instâncias** ou em **unidades ponderadas** (por exemplo vCPU), quando tipos de tamanhos diferentes são misturados.
3. **Mercados e tipos de instância** — o grupo recebe uma lista de tipos Spot e um tipo On-Demand. O Elastigroup avalia o preço e o risco de interrupção de cada combinação de tipo e zona (*market scoring*) e distribui as instâncias entre elas, segundo a estratégia (`orientation`) escolhida.
4. **Previsão de interrupções** — com base no histórico dos mercados Spot, o Elastigroup procura substituir uma instância **antes** que a AWS a retome. Quando a interrupção acontece mesmo assim, ele repõe a capacidade com outro mercado Spot ou, se não houver, com On-Demand (*fallback*).
5. **Integração com load balancers** — as instâncias são registradas e removidas automaticamente de Target Groups (ALB/NLB) ou Classic Load Balancers, com drenagem das conexões antes do encerramento.
6. **Health checks e auto healing** — o grupo monitora a saúde das instâncias (status do EC2, target group do ALB, entre outros) e substitui as que ficam doentes.

## Principais funcionalidades

- **Uso inteligente de Spot** — *market scoring*, distribuição entre vários tipos e zonas de disponibilidade, e substituição proativa antes das interrupções.
- **Fallback para On-Demand e Revert to Spot** — usa On-Demand quando não há capacidade Spot, e volta para Spot assim que possível (sempre, nunca ou em uma janela de horário).
- **Mistura de mercados** — percentual de Spot (`spot_percentage`) ou uma quantidade fixa de instâncias On-Demand (`ondemand_count`) como base garantida.
- **Orientation** — a estratégia de escolha dos mercados Spot: priorizar o custo (`costOriented`), a disponibilidade (`availabilityOriented`), o equilíbrio entre os dois (`balanced`) ou a distribuição igual entre zonas (`equalAzDistribution`).
- **Aproveitamento de compromissos** — utiliza Reserved Instances e Savings Plans livres antes de lançar instâncias novas.
- **Escalonamento** — políticas simples e por *step* (como as do ASG), *target tracking* em métricas como CPU ou requisições por target do ALB, e **Predictive Autoscaling**, que prevê a carga com machine learning e escala com antecedência.
- **Deployments blue/green (Roll)** — troca de todas as instâncias em lotes quando a configuração muda (nova AMI, novo user data), verificando a saúde de cada lote antes de seguir.
- **Agendamento (Scheduling)** — tarefas com cron para escalar o grupo (por exemplo, desligar ambientes de dev à noite), fazer um roll ou criar uma AMI de backup.
- **Stateful** — com o recurso de *Stateful Node*, preserva volumes, IP privado e o root device entre as substituições, permitindo usar Spot em workloads com estado (bancos de dados, servidores legados).
- **Integrações** — Elastic Beanstalk, CodeDeploy, ECS, Kubernetes, Nomad, Route 53, entre outras.
- **Infraestrutura como código** — gerenciável via Terraform (provider `spotinst`, recurso `spotinst_elastigroup_aws`), CloudFormation, API REST e o console da Flexera/Spot. Um ASG existente pode ser importado para um Elastigroup.

## Elastigroup x Auto Scaling Group

| | Auto Scaling Group | Elastigroup |
|---|---|---|
| Spot | Suportado com *mixed instances policy*, sem previsão de interrupções | Market scoring, substituição proativa e fallback automático |
| Volta para Spot | Manual (ou *capacity rebalancing*) | Automática (`revert_to_spot`) |
| Deploy de nova versão | *Instance refresh* | Roll blue/green com verificação de saúde por lote |
| Escala | Simple, step, target tracking, predictive | Simple, step, target tracking, predictive |
| Workloads com estado | Não preserva volumes ao trocar a instância | Stateful Node preserva volumes e IP |
| Custo do serviço | Sem custo adicional | Licença da Flexera, normalmente atrelada à economia gerada |

## Quando usar

- Aplicações em VMs, fora do Kubernetes, com custo relevante de computação.
- Workloads stateless que já rodam em Auto Scaling Groups e toleram a troca de instâncias.
- Workers de filas, jobs de batch e runners de CI, que se beneficiam de Spot.
- Ambientes de dev/teste que podem ser desligados fora do horário comercial.

Para workloads em Kubernetes ou ECS, prefira o [Ocean](../ocean-lab/about_ocean.md), que escolhe os nodes a partir dos containers.
