# Ocean Lab

Recomendamos a leitura desta [documentação](./about_ocean.md) para que você possa ter uma visão geral de como o Flexera Ocean funciona.

A seguir, você poderá executar este laboratório para ver na prática como configurar o Ocean em seu cluster, e entender e testar as suas funcionalidades.

## Cenários

Cada cenário é um arquivo `.tfvars` dentro de [scenarios/](./scenarios/), e os workloads de teste ficam em [workloads/](./workloads/).

| # | Cenário | Arquivo | O que explora |
|---|---------|---------|---------------|
| 01 | [Configuração do Ocean](#configuração-do-ocean) | [01-baseline.tfvars](./scenarios/01-baseline.tfvars) | Ocean Cluster, VNG `general`, Controller, scale up e scale down |
| 02 | [Explorando o Headroom](#explorando-o-headroom) | [02-headroom.tfvars](./scenarios/02-headroom.tfvars) | Headroom automático + manual |
| 03 | [Explorando os Virtual Node Groups](#explorando-os-virtual-node-groups) | [03-vngs.tfvars](./scenarios/03-vngs.tfvars) | Isolamento de workloads com labels, taints e On-Demand |
| 04 | [Explorando tipos de instâncias](#explorando-tipos-de-instâncias) | [04-instances.tfvars](./scenarios/04-instances.tfvars) | Filtros de instâncias, `availability_vs_cost` e ARM (Graviton) |

Um cenário é aplicado com:

```bash
terraform apply -var-file=scenarios/<cenário>.tfvars
```

> Os cenários **não são cumulativos**: cada arquivo altera somente alguns valores, e tudo o que ele não define volta para o padrão do [variables.tf](./variables.tf). Por exemplo, ao aplicar o cenário 03 o headroom manual do cenário 02 é removido.

## Passo a Passo

### Dependências

Este projeto usa o [mise](https://mise.jdx.dev/) como gestor das ferramentas.
Em seu arquivo temos configuradas todas as ferramentas necessárias para executar esse laboratório e validar as funcionalidades do Ocean (`terraform`, `kubectl`, `helm` e `eks-node-viewer`).

### Criação do EKS

Este projeto depende da criação de um cluster EKS na AWS.
Consulte o projeto [eks-workshop](../eks-workshop/), verifique as configurações no arquivo `locals.tf` e execute o terraform em seu ambiente.

O Ocean Lab lê os dados do cluster (endpoint, subnets, security groups, instance profile dos nodes) a partir do state do eks-workshop, então ajuste o backend em [data.tf](./data.tf) e [versions.tf](./versions.tf) caso esteja usando outro bucket.

### Arquivo env

Copie o arquivo [.env.example](./.env.example) para `.env` e preencha as variáveis com os valores do próximo passo. O `.env` é carregado automaticamente pelo mise e não deve ser commitado.

Caso não queira usar o arquivo `.env` você pode configurar as variáveis em um arquivo **env.tfvars** e passar esse arquivo para os comandos `terraform plan` e `terraform apply` com `-var-file=env.tfvars`.

### Criar o Token e Buscar o ID da Conta

Ao logar no console da [Spot](https://console.spotinst.com/), vá em **Profile > Organization > General Details**. Dentro da seção My Spot Account, busque pelo valor "Spot Account ID" que começa com o prefixo **act-**. Esse ID será configurado na env `TF_VAR_spotinst_account`.

> Confira se você está na Organization correta: o token só enxerga as contas da Organization em que foi criado.

Com o ID da conta em mãos agora é necessário criar um Programmatic User, que será o nosso API Token da Spot.
Para isso vá em **Profile > Organization > Users** e clique no botão "Create New User" no canto superior direito.

No formulário escolha a opção de "Programmatic", e dê um nome para o token:

![Criação de um Programmatic User no console da Spot](./images/create_new_user.png)

Na próxima tela temos mais duas configurações opcionais:

Adicionar esse novo usuário em um Grupo, caso queira organizar por ambientes e/ou uma estrutura que faça sentido para você.

Na opção de adicionar "Policies", precisamos selecionar algumas permissões:
- A primeira de "Account Viewer"
- A segunda de "Ocean Full Access"

Ambas selecionadas para a conta da AWS em que iremos fazer o laboratório (no exemplo abaixo, a conta se chama "RealCloud Services"; selecione a sua).

![Policies Account Viewer e Ocean Full Access associadas à conta](./images/create_user_policies.png)

O token de API será mostrado, e você deverá configurar na env `TF_VAR_spotinst_token`.

> As policies não podem ser editadas depois que o usuário é criado. Caso falte alguma permissão, será necessário criar um novo usuário.

> Em produção, recomendamos a criação de um token por Cluster. Pode-se utilizar a API da Spot para criar esses usuários via script. Confira a documentação [aqui](https://spec.dev.spot.io/?section=administration#tag/Organizations/operation/OrganizationsAndAccountsCreateUser).


### Configuração do Ocean

Com as configurações acima feitas, agora execute o terraform plan e apply deste projeto para criar a integração do Ocean com o EKS. O cenário [01-baseline.tfvars](./scenarios/01-baseline.tfvars) não altera nenhum valor, ele usa somente os padrões do [variables.tf](./variables.tf):

```bash
terraform init
terraform apply -var-file=scenarios/01-baseline.tfvars
```

Vamos primeiro fazer uma revisão dos conceitos relativos ao Ocean para então validar a nossa infraestrutura.

#### Conceitos

Nesta etapa são criados três recursos do lado da Spot/Kubernetes: o **Ocean Cluster**, um **Virtual Node Group (VNG)** e o **Ocean Controller**.

**Ocean Cluster**

É o objeto principal do Ocean, criado no SaaS da Spot (recurso `spotinst_ocean_aws`, ID com prefixo `o-`). Ele representa o cluster EKS dentro da Spot e concentra as configurações que valem para todos os nodes:

- **Limites de capacidade**: quantidade mínima e máxima de nodes, e o total máximo de vCPU e memória que o Ocean pode provisionar. Os valores padrão deste projeto são baixos (máximo de 10 nodes e 64 vCPU) para manter o custo controlado.
- **Template de lançamento**: AMI, user data, instance profile, security groups, subnets, volume raiz e configurações de metadata (IMDSv2). Com `use_as_template_only = true`, essas configurações servem apenas como base: nenhum node é criado diretamente pelo cluster, todos vêm de um VNG.
- **Estratégia**: fallback para On-Demand quando não há capacidade Spot, uso (ou não) de Reserved Instances, tempo de drenagem dos nodes antes de serem removidos.
- **Autoscaler**: liga o escalonamento automático, define o headroom e o comportamento de scale down.
- **Roll**: define como os nodes são substituídos quando a configuração muda (tamanho do lote, respeito aos PodDisruptionBudgets).

> O Ocean não cria Auto Scaling Groups nem Launch Templates na AWS. As instâncias são lançadas diretamente como Spot Requests (ou On-Demand) pela role da Spot na sua conta, e as configurações ficam armazenadas no console da Spot.

**Virtual Node Group (VNG)**

Um VNG é um **template de um tipo de node**, e não um grupo fixo de instâncias. Na API e no Terraform ele é chamado de *launch spec* (recurso `spotinst_ocean_aws_launch_spec`, ID com prefixo `ols-`).

- Cada node do Ocean pertence a exatamente um VNG, e herda dele labels, taints, tipos de instância permitidos, percentual de Spot e demais configurações.
- O que o VNG não define é herdado do Ocean Cluster (AMI, user data, security groups, headroom, etc.).
- Diferente de um Managed Node Group, o VNG não tem uma quantidade desejada de nodes nem uma lista fixa de tipos de instância: o Ocean decide quantos nodes criar e qual o tipo mais barato que acomoda os pods pendentes.
- O Ocean escolhe o VNG olhando para os requisitos dos pods (`nodeSelector`, affinity e tolerations) e comparando com os labels e taints de cada VNG.

Neste passo criamos o VNG `general`, com 100% de Spot e o label `ocean-lab/vng=general`. Todo VNG do laboratório recebe o label `ocean-lab/vng=<nome do VNG>`, e os workloads de teste usam esse label para garantir que rodem somente em nodes do Ocean.

Alguns pontos de atenção na configuração:
- O `spot_percentage` não pode ser definido no cluster e no VNG ao mesmo tempo, por isso ele é configurado apenas nos VNGs.
- O `draining_timeout` de um VNG precisa ser de no mínimo 300 segundos, por isso o VNG herda o valor do cluster.
- Com `delete_nodes = true`, os nodes de um VNG são encerrados quando o VNG é removido.

**Ocean Controller**

É o componente instalado **dentro** do cluster EKS via Helm (chart `ocean-kubernetes-controller`, namespace `spot-system`). Ele é a ponte entre o Kubernetes e o SaaS da Spot:

- Envia para a Spot o estado do cluster: pods pendentes, requisições de CPU e memória, nodes e sua utilização.
- Recebe as decisões do Ocean, como drenar um node antes de removê-lo.
- Coleta o consumo dos containers para o Right-Sizing, quando habilitado.

O Controller se identifica pelo `clusterIdentifier`, que precisa ser igual ao `controller_id` do Ocean Cluster (neste projeto, o nome do cluster EKS). Ele roda nos nodes do Managed Node Group, assim continua funcionando mesmo quando o Ocean está com zero nodes.

Para validar a conexão, verifique se os pods estão rodando com `kubectl -n spot-system get pods` e se o status do Controller aparece como conectado no console da Spot.

**Headroom**

É uma reserva de capacidade livre mantida pelo Ocean para que novos pods sejam agendados imediatamente, sem esperar um node subir. Neste passo ele está no modo automático (`auto_headroom_percentage = 5`), ou seja, o Ocean mantém cerca de 5% de capacidade extra calculada a partir dos workloads do cluster.

**Scale Up e Scale Down**

- **Scale up**: quando existem pods pendentes que nenhum node comporta, o Ocean escolhe o VNG e o tipo de instância e lança o node. Normalmente os pods estão rodando em menos de um minuto.
- **Scale down**: nodes subutilizados são drenados e removidos. Com as configurações padrão (no máximo 10% dos nodes por ciclo, scale down agressivo desligado), um node vazio leva por volta de 10 minutos para ser removido.

#### Validação

**Acesso ao cluster**: para gerenciar o cluster localmente com o `kubectl`, configure o kubeconfig com o AWS CLI, usando a região, o nome do cluster e o profile do seu ambiente:

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-workshop --profile <seu profile>
kubectl get nodes
kubectl -n spot-system get pods
```

O primeiro comando lista os nodes do Managed Node Group, e o segundo os pods do Ocean Controller, que devem estar em `Running`.

**No Console AWS**: Verifique no dashboard do EKS os nodes do Managed Node Group criado pelo eks-workshop (onde rodam o Controller e os add-ons). Os nodes do Ocean aparecem como "Self-Managed", sem node group, já que são gerenciados pelo Ocean.

**No Console Spot**: Clique nos quadradinhos no canto superior esquerdo > selecione o produto Ocean, e na listagem de clusters selecione o cluster com o nome do seu EKS (por padrão `eks-workshop`).
Nesse momento você vai ter uma visão geral da configuração do cluster Ocean:

![Overview do cluster no console do Ocean](./images/console.png)

> Logo após o apply, o Ocean ainda não gerencia nenhum node: os nodes contados no "out of" são os do Managed Node Group, por isso o console sugere uma migração. O ID `o-` e o nome do cluster serão os do seu ambiente.

Para ver um scale up, faça o deploy do workload [inflate](./workloads/inflate.yaml), que somente reserva CPU e memória no VNG `general`, e escale para 4 réplicas:

```bash
kubectl apply -f workloads/inflate.yaml
kubectl scale deploy/inflate --replicas=4
kubectl get nodes -l ocean-lab/vng=general -L node.kubernetes.io/instance-type,spotinst.io/node-lifecycle
```

O Ocean sobe um único node Spot que acomode os 4 pods. Ao voltar o `inflate` para 0 réplicas, o Ocean decomissiona a EC2 que ele subiu em alguns minutos. Este e outros eventos no cluster podem ser acompanhados na aba Log do console:

![Eventos de scale up e scale down na aba Log](./images/ocean_logs.png)

> Repare que o evento de scale up informa os recursos pendentes que o motivaram (CPU e memória somados dos pods), e o scale down passa pelas etapas de detach e terminate da instância.

### Explorando o Headroom

Quando subimos a infraestrutura, tínhamos somente 5% de headroom, e a configuração atual foi feita em cima do baseline default de configuração dos módulos terraform da Ocean.

Agora vamos explorar um ajuste onde habilitamos a variável `enable_automatic_and_manual_headroom`, que permite usar o headroom manual em conjunto com o automático.

#### Como funciona

O Ocean oferece dois tipos de headroom, que podem ser usados juntos:

- **Automático** (`auto_headroom_percentage`): um percentual calculado a partir dos recursos usados pelos workloads. Ele cresce e diminui junto com o cluster. Por isso, no baseline, com nenhum workload rodando, os 5% não reservavam praticamente nada.
- **Manual** (`cpu_per_unit`, `memory_per_unit` e `num_of_unit`): uma quantidade fixa de capacidade livre, definida em "unidades". Cada unidade representa o tamanho de um pod típico, e o Ocean mantém sempre o número de unidades configurado disponível no cluster.

O arquivo [02-headroom.tfvars](./scenarios/02-headroom.tfvars) altera somente o headroom, e todo o resto continua igual ao baseline:

```hcl
ocean = {
  enable_automatic_and_manual_headroom = true # headroom manual além dos 5% automáticos
  cpu_per_unit                         = 1000 # cada unidade = 1 vCPU (em millicores)
  memory_per_unit                      = 1536 # ... e 1.5 GiB (em MiB)
  num_of_unit                          = 2    # manter sempre 2 unidades livres
}
```

Ou seja, o Ocean passa a manter espaço livre para 2 pods de 1 vCPU e 1.5 GiB, além dos 5% automáticos. O tamanho da unidade é o mesmo dos pods do [inflate](./workloads/inflate.yaml), para facilitar a validação.

> **Atenção:** o `enable_automatic_and_manual_headroom = true` só funciona com `autoscale_is_auto_config = true` (o valor padrão). Se o automático estiver desligado, a API da Spot recusa a alteração com o erro `The enableAutomaticAndManualHeadroom flag cannot be true when isAutoConfig is false`.

Antes de aplicar, volte o `inflate` para 0 réplicas, e aplique o cenário:

```bash
kubectl scale deploy/inflate --replicas=0
terraform apply -var-file=scenarios/02-headroom.tfvars
```

#### Validação

> No console da Ocean você pode verificar a configuração do Headroom em: **Cluster > Actions > Customize Scaling**
> Essa configuração também pode ser definida em um VNG e você pode conferir em: **Cluster > Virtual Node Groups > Advanced (seção no fim da página)**

1. **Node criado somente para o headroom**: cerca de 1 minuto após o apply, o Ocean sobe um node Spot sem nenhum workload, somente com os pods de sistema (`aws-node`, `kube-proxy`, `eks-pod-identity-agent`). O tipo de instância varia conforme o preço do Spot no momento, por exemplo um `c5a.xlarge`.

   ```bash
   kubectl get nodes -l ocean-lab/vng=general -L node.kubernetes.io/instance-type,spotinst.io/node-lifecycle
   ```

2. **Pods agendados imediatamente**: escale o deployment `inflate` para 2 réplicas. Os pods devem ir direto para o node do headroom, sem aguardar um scale up.

   ```bash
   kubectl scale deploy/inflate --replicas=2
   kubectl get pods -l app=inflate -o wide
   ```

   Os 2 pods devem estar rodando em **poucos segundos**, contra quase **um minuto** no baseline, onde o Ocean precisou subir um node novo.

3. **Reposição do headroom**: como os pods consumiram a reserva, o Ocean sobe um novo node para voltar a ter 2 unidades livres. Esse novo node fica pronto em cerca de 2 minutos, também sem workloads.

Os eventos de scale up, com o motivo de cada um, podem ser acompanhados na aba **Log** do cluster no console da Spot.

#### Custo x Benefício

O headroom é capacidade que você paga mesmo sem uso. Neste cenário, o Ocean mantém cerca de 2 vCPU e 3 GiB de Spot sempre ligados, mesmo sem nenhum workload. Em troca, novos pods iniciam em segundos, em vez de esperar o node subir.

Em produção, o headroom costuma ser dimensionado para o pico esperado, por exemplo os pods extras de um deploy ou um aumento repentino de tráfego. Ele também pode ser configurado por VNG, assim somente os workloads sensíveis à latência pagam por essa reserva.

### Explorando os Virtual Node Groups

Neste cenário vamos explorar a criação de mais 2 VNG's além do `general` que criamos no primeiro passo: `batch` e `critical`.
A ideia é que temos diferentes templates de instâncias para diferentes cenários de workloads.

#### Como funciona

O arquivo [03-vngs.tfvars](./scenarios/03-vngs.tfvars) define os 3 VNGs:

```hcl
vngs = {
  general = {}
  batch = {
    taints = [{ key = "ocean-lab/batch", value = "true", effect = "NoSchedule" }]
  }
  critical = {
    spot_percentage = 0 # somente On-Demand
  }
}
```

- **`general`**: o mesmo do baseline, 100% Spot.
- **`batch`**: 100% Spot e com um taint. Somente pods com a toleration `ocean-lab/batch` podem rodar nos seus nodes, assim nenhum outro workload ocupa esses nodes por engano.
- **`critical`**: 0% de Spot, ou seja, todos os nodes são On-Demand. É o VNG para workloads que não podem sofrer interrupções do Spot.

Dentro de um deployment utilizamos o `nodeSelector` com o label do VNG para definir onde aquele deploy será feito:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical
spec:
  replicas: 2
  selector:
    matchLabels:
      app: critical
  template:
    metadata:
      labels:
        app: critical
    spec:
      nodeSelector:
        ocean-lab/vng: critical
```

O `batch` precisa, além do `nodeSelector`, da toleration para o taint do VNG:

```yaml
      nodeSelector:
        ocean-lab/vng: batch
      tolerations:
        - key: ocean-lab/batch
          operator: Equal
          value: "true"
          effect: NoSchedule
```

Confira aqui os 3 deployments: [Critical](./workloads/critical.yaml) | [Batch](./workloads/batch.yaml) | [General](./workloads/inflate.yaml)

Aplique o cenário e os workloads:

```bash
terraform apply -var-file=scenarios/03-vngs.tfvars
kubectl apply -f workloads/batch.yaml -f workloads/critical.yaml
```

#### Validação

Confira em qual VNG e com qual lifecycle (Spot ou On-Demand) cada node subiu:

```bash
kubectl get nodes -l ocean-lab/vng -L ocean-lab/vng,node.kubernetes.io/instance-type,spotinst.io/node-lifecycle
kubectl get pods -o wide
```

- Os pods do `batch` rodam em um node **Spot** do VNG `batch`.
- Os pods do `critical` rodam em um node **On-Demand** do VNG `critical`.
- Um pod com `nodeSelector` do `batch`, mas sem a toleration, fica `Pending` e o Ocean não faz scale up para ele, já que nenhum VNG aceita esse pod.

Explore no console da Ocean como todos os VNG's estão estruturados, vendo quais pods estão rodando em cada um, e no console da AWS em Resources explore como estão divididos os pods.

![Listagem de VNGs no console do Ocean](./images/vng.png)

> Na listagem, cada VNG mostra a alocação de CPU e memória, os pods e nodes que está usando, e a quantidade de labels e taints. Repare que somente o `batch` tem um taint. Os IDs `ols-` serão os do seu ambiente.

Neste exemplo, nenhum dos 3 VNG's possuem headroom configurados. E aqui destacamos que o headroom pode ser configurado a nível do Cluster do Ocean ou dentro dos próprios VNG's.

### Explorando tipos de instâncias

Até aqui, não definimos nenhuma restrição de tipos de instância. O Ocean escolhe livremente entre todos os tipos disponíveis na região, e por isso é comum ver nodes bem variados, inclusive de gerações antigas como `c3` e `c4`.

Neste cenário vamos controlar **quais instâncias o Ocean pode usar** e **como ele escolhe entre elas**, e também criar um VNG com instâncias ARM (Graviton).

#### Como funciona

O Ocean escolhe a instância de um node em duas etapas:

1. **Quais tipos são permitidos**: definido por filtros no cluster (valem para todos os VNGs) e, opcionalmente, por uma lista de tipos em cada VNG. A lista do VNG precisa estar dentro do que o cluster permite.
2. **Qual tipo usar entre os permitidos**: definido pela estratégia `availability_vs_cost`:
   - `balanced` (padrão): equilibra preço e disponibilidade das instâncias Spot.
   - `costOriented`: prioriza o custo, considerando a disponibilidade.
   - `cheapest`: escolhe sempre o tipo mais barato que acomoda os pods.

O arquivo [04-instances.tfvars](./scenarios/04-instances.tfvars) configura:

```hcl
ocean = {
  availability_vs_cost = "cheapest"
  filters = {
    exclude_metal    = true
    exclude_families = ["t*"] # todas as famílias burstable, inclusive as futuras
    categories       = ["General_purpose", "Compute_optimized", "Memory_optimized"]
  }
}

vngs = {
  general = {}
  arm64 = {
    arch           = "arm64"
    instance_types = ["m7g.large", "m7g.xlarge", "c7g.large", "c7g.xlarge", "m6g.large", "c6g.large"]
  }
}
```

- **Filtros do cluster**: removem as instâncias bare metal, todas as famílias burstable (`t*`) e mantêm somente as categorias de uso geral, otimizadas para computação e para memória. Assim ficam de fora as instâncias com aceleradores (GPU, Inferentia, FPGA) e as otimizadas para storage.
- **VNG `arm64`**: usa uma AMI AL2023 para arm64 (o laboratório busca automaticamente no SSM da AWS) e uma lista fixa de tipos Graviton. O módulo de VNG não possui filtro de arquitetura, por isso usamos a lista de tipos.
- **VNGs `batch` e `critical`**: deixam de existir neste cenário e serão removidos.

> **Atenção:** o módulo de VNG sempre envia `availability_vs_cost = "balanced"` como padrão, o que sobrescreve o valor definido no cluster. Por isso, o laboratório repassa o valor do cluster para todos os VNGs (podendo ser sobrescrito por VNG através do campo `availability_vs_cost` em `vngs`).

#### Preparação

Antes de aplicar, remova os workloads do cenário anterior. Como os VNGs `batch` e `critical` serão apagados, os pods ficariam pendentes sem nenhum node que os aceite:

```bash
kubectl delete -f workloads/batch.yaml -f workloads/critical.yaml
```

Aplique o cenário:

```bash
terraform apply -var-file=scenarios/04-instances.tfvars
```

#### Validação

1. **Nodes ARM**: faça o deploy do workload [arm64](./workloads/arm64.yaml), que seleciona nodes com `kubernetes.io/arch: arm64` do VNG `arm64`.

   ```bash
   kubectl apply -f workloads/arm64.yaml
   kubectl get nodes -l ocean-lab/vng -L ocean-lab/vng,node.kubernetes.io/instance-type,kubernetes.io/arch
   ```

   Os 2 pods devem rodar em um node Spot Graviton, de um dos tipos da lista do VNG (por exemplo `c7g.xlarge`).

2. **Tipos de instância permitidos**: escale o `inflate` para forçar novos nodes no VNG `general` e confira os tipos escolhidos. Nenhum deve ser burstable (`t*`), bare metal ou com aceleradores.

   ```bash
   kubectl scale deploy/inflate --replicas=7
   kubectl get nodes -l ocean-lab/vng=general -L node.kubernetes.io/instance-type,spotinst.io/node-lifecycle
   ```

3. **Remoção dos VNGs antigos**: os nodes dos VNGs `batch` e `critical` são marcados como `SchedulingDisabled`, drenados e depois encerrados, o que leva alguns minutos após o apply. Durante esse tempo as instâncias continuam rodando e sendo cobradas.

#### Por que esses filtros

Os filtros deste cenário evitam dois comportamentos do `cheapest` que podem surpreender na prática:

- **Somente `cheapest`, sem filtro de categoria**: o Ocean pode escolher instâncias como a `inf1.xlarge`, com acelerador de machine learning (AWS Inferentia). Ela pode ser a mais barata no Spot em algum momento, mas não faz sentido para workloads comuns. A solução é filtrar por `categories`.
- **Excluindo famílias pelo nome** (`t2`, `t3`, `t3a`, `t4g`): o Ocean pode escolher uma família burstable mais nova que não está na lista, como a `t8i`. A solução é usar o curinga `t*`, que continua funcionando quando a AWS lança novas famílias.

Com os filtros do cenário, os novos nodes do `general` devem ser de famílias como `c5` e `m5`.

Alguns pontos importantes:

- **Filtros valem somente para novos nodes.** Nodes que já existiam antes da alteração continuam rodando com o tipo antigo. Para substituí-los é necessário um *roll* do cluster, explorado em outro cenário.
- **Prefira filtros por categoria e curingas** em vez de listas fixas de tipos, para que o Ocean continue com muitas opções de instâncias, o que aumenta a disponibilidade no Spot.
- Remova os workloads ao final do cenário para que o Ocean desligue os nodes:

  ```bash
  kubectl scale deploy/inflate --replicas=0
  kubectl delete -f workloads/arm64.yaml
  ```
