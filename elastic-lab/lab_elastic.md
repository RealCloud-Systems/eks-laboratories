# Elastigroup Lab

Recomendamos a leitura desta [documentação](./about_elastic.md) para que você possa ter uma visão geral de como o Flexera Elastigroup funciona.

A seguir, você poderá executar este laboratório para ver na prática como criar um Elastigroup, e entender e testar as suas funcionalidades. O laboratório sobe um nginx em instâncias EC2 atrás de um Application Load Balancer, e cada instância responde com a versão da aplicação e com os dados de onde está rodando (tipo, zona e se é Spot ou On-Demand). Assim, um simples `curl` mostra o que o Elastigroup está fazendo.

## Arquitetura

```
Internet ──> ALB (subnets públicas) ──> Target Group ──> instâncias do Elastigroup (subnets privadas)
                                              ^                         |
                                              └── registro automático ──┘
```

- **Rede**: uma VPC própria (`10.1.0.0/16`) com subnets públicas e privadas em 2 zonas de disponibilidade e um único NAT Gateway, criada em [vpc.tf](./vpc.tf). O laboratório não depende de nenhum outro projeto do repositório.
- **ALB, Security Groups e IAM**: criados com os módulos [terraform-aws-modules](https://github.com/terraform-aws-modules) em [network.tf](./network.tf) e [iam.tf](./iam.tf). As instâncias só recebem tráfego do ALB e não têm SSH: o acesso é feito pelo SSM.
- **Elastigroup**: o recurso `spotinst_elastigroup_aws` em [elastigroup.tf](./elastigroup.tf). Não existe módulo da terraform-aws-modules para ele, já que é um recurso da Spot.

## Cenários

Cada cenário é um arquivo `.tfvars` dentro de [scenarios/](./scenarios/).

| # | Cenário | Arquivo | O que explora |
|---|---------|---------|---------------|
| 01 | [Configuração do Elastigroup](#configuração-do-elastigroup) | [01-baseline.tfvars](./scenarios/01-baseline.tfvars) | Grupo com 2 instâncias Spot, fallback para On-Demand e registro no ALB |
| 02 | [Explorando os mercados: Spot e On-Demand](#explorando-os-mercados-spot-e-on-demand) | [02-markets.tfvars](./scenarios/02-markets.tfvars) | Base fixa de On-Demand com `ondemand_count`, tipos Spot preferidos, `orientation` e um Roll pela API para aplicar a mudança |
| 03 | [Explorando o Auto Healing](#explorando-o-auto-healing) | [03-auto-healing.tfvars](./scenarios/03-auto-healing.tfvars) | Health check pelo Target Group e substituição de instâncias doentes |

Um cenário é aplicado gerando o plano com o arquivo do cenário e aplicando o plano:

```bash
terraform plan -out plan -var-file=scenarios/<cenário>.tfvars
terraform apply plan
```

> Os cenários **não são cumulativos**: cada arquivo altera somente alguns valores, e tudo o que ele não define volta para o padrão do [variables.tf](./variables.tf). Isso inclui a capacidade: todo apply volta o grupo para o `desired_capacity` de 2 instâncias, mesmo que o Elastigroup tenha alterado esse valor.

## Passo a Passo

### Dependências

As ferramentas (`terraform` e `aws`) são instaladas pelo [mise](https://mise.jdx.dev/) a partir do [mise.toml](../mise.toml) da raiz do repositório:

```bash
mise install
```

### Backend e profile

O state fica no bucket S3 definido no bloco `backend` do [versions.tf](./versions.tf), e o profile da AWS em [locals.tf](./locals.tf). Ajuste os dois caso esteja usando outro bucket ou outro profile.

> As instâncias rodam nas subnets privadas e usam o NAT Gateway para instalar o nginx e falar com o SSM. O ALB fica nas subnets públicas. Para manter o custo baixo, existe um único NAT Gateway, o que não é altamente disponível.

### Arquivo env

Copie o arquivo [.env.example](./.env.example) para `.env` e preencha as variáveis com os valores do próximo passo. O `.env` é carregado automaticamente pelo mise (pelo [mise.toml](./mise.toml) desta pasta, que precisa ser marcado como confiável uma vez) e não deve ser commitado:

```bash
cd elastic-lab
cp .env.example .env
mise trust
```

### Token e ID da Conta

O processo é o mesmo do [Ocean Lab](../ocean-lab/lab_ocean.md#criar-o-token-e-buscar-o-id-da-conta): o ID da conta (`act-...`) vai na env `TF_VAR_spotinst_account` e o token de um Programmatic User vai na env `TF_VAR_spotinst_token`.

A diferença está nas policies do usuário: o token do Ocean Lab tem somente "Account Viewer" e "Ocean Full Access", e **não consegue criar um Elastigroup**. Crie um novo Programmatic User com:
- "Account Viewer"
- "Elastigroup Full Access"

Ambas associadas à conta da AWS do laboratório (no exemplo abaixo, a conta se chama "RealCloud Services"; selecione a sua):

![Policies Account Viewer e Elastigroup Full Access associadas à conta](./images/create_user.png)

> As policies não podem ser editadas depois que o usuário é criado, por isso é necessário um novo usuário em vez de reaproveitar o do Ocean.

### Configuração do Elastigroup

Com as configurações acima feitas, execute o plan e o apply com o cenário [01-baseline.tfvars](./scenarios/01-baseline.tfvars), que não altera nenhum valor e usa somente os padrões do [variables.tf](./variables.tf):

```bash
terraform init
terraform plan -out plan -var-file=scenarios/01-baseline.tfvars
terraform apply plan
```

### Conceitos

**Elastigroup**

É o objeto principal, criado no SaaS da Spot (recurso `spotinst_elastigroup_aws`, ID com prefixo `sig-`). Ele faz o papel de um Auto Scaling Group e concentra:

- **Capacidade**: `min_size = 1`, `max_size = 4` e `desired_capacity = 2`. Com `capacity_unit = "instance"`, cada instância conta como uma unidade, independente do tipo.
- **Configuração de lançamento**: a AMI Amazon Linux 2023 mais recente (lida do SSM da AWS), o user data que instala o nginx, o instance profile com a policy do SSM, o security group e as subnets privadas, uma por zona de disponibilidade.
- **Tipos de instância**: uma lista de tipos Spot (`instance_types_spot`) e um tipo On-Demand (`instance_types_ondemand`). Todos os tipos da lista têm 2 vCPU, para que a aplicação se comporte da mesma forma em qualquer um deles.
- **Estratégia**: `spot_percentage = 100`, `fallback_to_ondemand = true` (usa On-Demand se não houver capacidade Spot) e `revert_to_spot = "always"` (volta para Spot assim que possível).
- **Load balancer**: o Target Group do ALB em `target_group_arns`. O Elastigroup registra cada instância nova e remove as que vão ser encerradas, respeitando o `draining_timeout` de 60 segundos.

> Assim como o Ocean, o Elastigroup **não cria um Auto Scaling Group nem um Launch Template** na AWS. As instâncias são lançadas diretamente pela role da Spot na sua conta, e aparecem no console do EC2 como instâncias comuns.

**Diversificação de tipos e zonas**

Em vez de lançar todas as instâncias no mesmo tipo, o Elastigroup distribui o grupo entre os tipos permitidos e as zonas de disponibilidade. Se a AWS retomar a capacidade Spot de um tipo em uma zona, somente parte do grupo é afetada. Quanto maior a lista de tipos, mais mercados Spot o Elastigroup tem para escolher, e menor o risco de interrupções.

**Tags**

O Elastigroup aplica as tags do bloco `tags` em todas as instâncias que lança. O laboratório usa a tag `elastic-lab/group = elastic-lab` para encontrar as instâncias nos comandos da AWS CLI e no SSM.

> **Documentação do Elastigroup:** [Criar um Elastigroup](https://docs.flexera.com/spot/elastigroup/tutorials/elastigroup-tasks/create-an-elastigroup-from-scratch-nw) | [Visão geral dos grupos no console](https://docs.flexera.com/spot/elastigroup/tutorials/elastigroup-actions-menu/elastigroup-overview) | [Capacidade em instâncias ou ponderada](https://docs.flexera.com/spot/elastigroup/features/core-features/elastigroup-capacity-instances-or-weighted)

#### Validação

**Comandos de apoio**: o [mise.toml](./mise.toml) desta pasta tem tasks do mise usadas nos cenários. Elas leem a URL da aplicação e o ARN do Target Group dos outputs do Terraform, e usam o `AWS_PROFILE` definido no próprio `mise.toml` (ajuste caso use outro profile, junto com o [locals.tf](./locals.tf)):

| Task | O que faz |
|------|-----------|
| `mise run instances` | Instâncias do grupo: ID, tipo, Spot ou On-Demand, zona e estado |
| `mise run targets` | Saúde das instâncias no Target Group do ALB |
| `mise run hits` | 10 requisições para a aplicação |
| `mise run stop-nginx [id]` | Para o nginx de uma instância pelo SSM ([Auto Healing](#explorando-o-auto-healing)) |
| `mise run roll [--batch 50]` | Inicia um Roll do grupo pela API da Spot ([Mercados](#explorando-os-mercados-spot-e-on-demand)) |
| `mise run roll-status` | Status e progresso dos últimos Rolls do grupo |

Para listar as tasks: `mise tasks`.

1. **Instâncias**: cerca de 1 minuto após o apply, o grupo tem 2 instâncias Spot, normalmente de tipos e zonas diferentes.

   ```bash
   mise run instances
   ```

2. **Load balancer**: depois que o nginx é instalado (1 a 2 minutos), as 2 instâncias ficam `healthy` no Target Group, e as requisições se alternam entre elas:

   ```bash
   mise run targets
   mise run hits
   ```

   ```
   version=v1 instance=i-0a1... type=c6a.large az=us-east-1a lifecycle=spot
   version=v1 instance=i-0b2... type=m5.large az=us-east-1b lifecycle=spot
   ```

**No Console AWS**: no EC2, as instâncias aparecem com o nome `elastic-lab-app`, com o tipo de ciclo de vida "Spot" e sem nenhum Auto Scaling Group. No Target Group `app-...`, as instâncias foram registradas pelo Elastigroup, e não pelo Terraform.

**No Console Spot**: clique nos quadradinhos no canto superior esquerdo > selecione o produto **Elastigroup**, e na listagem de grupos selecione o `elastic-lab`. O grupo tem as abas **Overview**, **Load Balancers**, **Instances**, **Costs**, **Deployments**, **Recommendations**, **Monitoring** e **Log**.

Na **Overview**, a seção **Group information** resume a configuração do grupo:

![Seção Group information na Overview do grupo](./images/group_information.png)

> O ID `sig-`, a lista de tipos Spot do `instance_types_spot`, a AMI lida do SSM, o ALB em **Load balancers** (a integração aparece como "Elastic Load Balancer") e as 2 zonas de disponibilidade das subnets privadas. Os IDs serão os do seu ambiente.

A aba **Log** registra cada ação do grupo. Logo após o apply, ela mostra a criação do grupo, o lançamento das 2 instâncias e o registro delas no Target Group:

![Criação do grupo, lançamento das instâncias e registro no load balancer na aba Log](./images/create_log.png)

> Lendo de baixo para cima: o grupo é criado, as 2 instâncias são lançadas com o motivo `Group creation` e, cerca de 20 segundos depois, registradas no Target Group `app-...`. Os horários são mostrados no fuso do seu navegador.

### Explorando os mercados: Spot e On-Demand

No baseline, todas as instâncias são Spot e o On-Demand só é usado como fallback. Neste cenário vamos manter uma **base garantida de On-Demand** e influenciar quais tipos Spot o Elastigroup escolhe.

#### Como funciona

O Elastigroup oferece duas formas de misturar os mercados:

- **`spot_percentage`**: o percentual de instâncias Spot do grupo. Com 50%, metade é Spot e metade On-Demand, e a proporção acompanha o tamanho do grupo.
- **`ondemand_count`**: uma quantidade fixa de instâncias On-Demand, e o restante Spot. É útil para ter um mínimo de capacidade que nunca sofre interrupções, independente do tamanho do grupo. Quando definido, ele substitui o `spot_percentage` (a Spot não aceita os dois ao mesmo tempo, então o laboratório envia somente um deles).

E duas formas de influenciar a escolha das instâncias Spot:

- **`instance_types_preferred_spot`**: tipos que o Elastigroup tenta usar primeiro, desde que o mercado esteja saudável. Os demais tipos de `instance_types_spot` continuam disponíveis como alternativa.
- **`orientation`**: a estratégia de escolha dos mercados:
  - `balanced` (padrão): equilibra custo e disponibilidade.
  - `costOriented`: prioriza os mercados mais baratos.
  - `availabilityOriented`: prioriza os mercados com menor risco de interrupção.
  - `equalAzDistribution`: distribui as instâncias igualmente entre as zonas de disponibilidade.

O arquivo [02-markets.tfvars](./scenarios/02-markets.tfvars) configura:

```hcl
elastigroup = {
  ondemand_count                = 1                            # sempre 1 instância On-Demand
  instance_types_preferred_spot = ["c7i.large", "m7i.large"]   # Spot de geração mais nova primeiro
}
```

> **Atenção:** a mudança de mercados vale somente para **novos lançamentos** (scale up e substituições). O Elastigroup não converte uma instância Spot que já está rodando em On-Demand: sem um Roll, o grupo continuaria somente com Spot até alguma instância ser substituída. Por isso, depois do apply, o cenário inicia um Roll pela API da Spot com a task `mise run roll` (lotes de 50%, validados pelo Target Group).

> Ligar o `should_roll` no Terraform não resolve aqui: o `update_policy` não faz parte da configuração do grupo na API da Spot, e o provider só inicia um Roll quando o mesmo apply também altera o grupo. Se os mercados já tiverem sido aplicados antes, o apply não muda nada no grupo, e nenhum Roll acontece.

Aplique o cenário e inicie o Roll:

```bash
terraform plan -out plan -var-file=scenarios/02-markets.tfvars
terraform apply plan
mise run roll
```

#### Validação

1. **Base On-Demand**: o Roll troca as instâncias em 2 lotes, e o andamento pode ser acompanhado com `mise run roll-status`. Ao final, o grupo tem 1 instância On-Demand do tipo `c6i.large` (o `instance_types_ondemand`) e 1 Spot.

   ```bash
   mise run instances
   mise run hits
   ```

   O `mise run hits` passa a mostrar respostas com `lifecycle=spot` e `lifecycle=on-demand`. O andamento do Roll aparece na aba **Deployments** do grupo.

2. **Tipos preferidos**: a instância Spot deve ser `c7i.large` ou `m7i.large`, se houver capacidade Spot nesses tipos. Caso contrário, o Elastigroup usa outro tipo da lista.

   Os tipos preferidos, ao contrário da base On-Demand, são aplicados sem o Roll: a aba **Log** registra uma substituição com o motivo `Spot Type Preference`, em que o Elastigroup sobe uma instância Spot de um tipo preferido e depois remove uma de outro tipo. Durante essa troca, o grupo fica temporariamente com uma instância a mais.

3. **Console**: na aba **Instances**, a coluna **Life Cycle** mostra a divisão entre Spot e On-Demand (`OD`):

   ![Aba Instances com uma instância On-Demand e uma Spot](./images/on_demand.png)

   > A instância On-Demand é do tipo `c6i.large` (o `instance_types_ondemand`), e a Spot é uma `m7i.large`, um dos tipos preferidos, lançada depois pela substituição `Spot Type Preference`. As duas aparecem saudáveis na coluna **Health**. Os IDs, as zonas e os horários serão os do seu ambiente.

   Na aba **Costs**, confira a economia estimada, que diminui com a instância On-Demand.

> **Documentação do Elastigroup:** [Compute](https://docs.flexera.com/spot/elastigroup/features/compute), com os mercados, tipos de instância e estratégias

#### Custo x Benefício

Cada instância On-Demand custa várias vezes o preço de uma Spot do mesmo tamanho. Uma base On-Demand faz sentido quando a aplicação não pode ficar sem nenhuma instância durante uma interrupção, mesmo que por poucos minutos. Para a maioria dos workloads stateless, uma lista grande de tipos Spot e várias zonas de disponibilidade já dão uma disponibilidade alta, com o fallback para On-Demand como rede de segurança.

### Explorando o Auto Healing

No baseline, o health check é o status do EC2 (`health_check_type = "EC2"`): o Elastigroup só substitui uma instância se a própria máquina falhar. Se o nginx parar, o ALB deixa de mandar tráfego para a instância, mas ela continua rodando e sendo cobrada. Neste cenário, o **Target Group** passa a decidir quando uma instância está doente.

#### Como funciona

Três configurações controlam o auto healing:

- **`health_check_type`**: a origem da informação de saúde. `EC2` usa os status checks da instância; `TARGET_GROUP` usa o health check do Target Group do ALB, que aqui faz um `GET /` a cada 10 segundos.
- **`health_check_grace_period`**: o tempo, após o lançamento, em que o health check é ignorado. Ele dá tempo para a instância subir e instalar o nginx.
- **`health_check_unhealthy_duration_before_replacement`**: quanto tempo a instância pode ficar doente antes de ser substituída. Ele só vale para instâncias que já foram saudáveis pelo menos uma vez.

O arquivo [03-auto-healing.tfvars](./scenarios/03-auto-healing.tfvars) configura:

```hcl
elastigroup = {
  health_check_type                                  = "TARGET_GROUP"
  health_check_grace_period                          = 120 # segundos
  health_check_unhealthy_duration_before_replacement = 60  # segundos
}
```

A substituição segue o modelo blue/green: o Elastigroup sobe uma nova instância, espera ela ficar saudável no Target Group, e só então encerra a doente.

Aplique o cenário:

```bash
terraform plan -out plan -var-file=scenarios/03-auto-healing.tfvars
terraform apply plan
```

#### Validação

1. **Quebre uma instância**: pare o nginx de uma das instâncias pelo SSM Run Command. Sem um ID, a task escolhe a primeira instância em execução e mostra qual foi.

   ```bash
   mise run instances
   mise run stop-nginx            # ou: mise run stop-nginx <id da instância>
   ```

2. **Acompanhe o Target Group e as instâncias**: em outro terminal, repita as tasks abaixo.

   ```bash
   mise run targets
   mise run instances
   mise run hits
   ```

   A sequência esperada é:

   1. Cerca de 20 segundos depois, a instância fica `unhealthy` no Target Group (2 falhas a cada 10 segundos), e o `mise run hits` passa a mostrar somente a outra instância.
   2. Depois do `health_check_unhealthy_duration_before_replacement`, o Elastigroup lança uma instância nova, que aparece como `initial` e depois `healthy` no Target Group.
   3. A instância doente passa para `draining` e é encerrada.

   Durante a substituição, o Target Group tem 3 instâncias por alguns instantes: a doente e as 2 saudáveis, incluindo a nova.

   ![Saída do mise run targets com a instância doente e a substituta já saudável](./images/health_target.png)

   > Neste exemplo, o nginx foi parado na instância On-Demand do cenário anterior (`i-0a22...`). A substituta (`i-0bb7...`) já está `healthy`, e a doente será encerrada em seguida. Os IDs serão os do seu ambiente.

3. **Console**: a aba **Log** do grupo registra a instância marcada como doente e a substituição.

> Para comparar, repita o teste com o baseline aplicado: o ALB tira a instância do tráfego da mesma forma, mas o Elastigroup nunca a substitui, já que para o EC2 a máquina continua saudável.

> **Documentação do Elastigroup:** [Autohealing](https://docs.flexera.com/spot/elastigroup/features/compute/autohealing) | [Load Balancers da AWS e Autohealing](https://docs.flexera.com/spot/elastigroup/tools-integrations/aws-load-balancers-elb-alb)

#### Custo x Benefício

Um `unhealthy_duration` curto troca as instâncias doentes mais rápido, mas pode substituir instâncias que só estavam lentas por alguns segundos, por exemplo durante um pico de carga. Um `grace_period` curto demais faz o Elastigroup substituir instâncias que ainda estavam subindo, em um ciclo que nunca termina. Ajuste os dois de acordo com o tempo real de inicialização da aplicação.

## Limpeza

Ao terminar, destrua o laboratório. O Elastigroup encerra as instâncias ao ser removido:

```bash
terraform plan -destroy -out plan
terraform apply plan
```

A VPC e o NAT Gateway são removidos junto com o restante do laboratório.
