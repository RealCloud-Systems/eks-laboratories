# EKS Workshop

Este projeto cria um cluster EKS na AWS, usado como base para o [Ocean Lab](../ocean-lab/lab_ocean.md). Todos os recursos são criados com os módulos [terraform-aws-modules](https://github.com/terraform-aws-modules).

## O que é criado

- **VPC** ([vpc.tf](./vpc.tf)): CIDR `10.0.0.0/16` em 2 AZs, com subnets públicas e privadas e um único NAT Gateway compartilhado, para manter o custo baixo (não é altamente disponível). As subnets já recebem as tags para Load Balancers do Kubernetes.
- **Cluster EKS** ([eks.tf](./eks.tf)): versão definida em `locals.tf`, endpoint público e permissão de admin para quem executou o terraform. Add-ons: `coredns`, `kube-proxy`, `eks-pod-identity-agent` e `vpc-cni`.
- **Managed Node Group** `default`: nodes `t3.medium` que hospedam somente o Ocean Controller e os add-ons do cluster. Os workloads rodam nos nodes do Ocean.
- **Role dos nodes do Ocean** ([iam.tf](./iam.tf)): role e instance profile `eks-workshop-ocean-node`, com as policies de worker node do EKS, CNI, leitura do ECR e SSM. Uma *access entry* do tipo `EC2_LINUX` permite que os nodes lançados pelo Ocean entrem no cluster.

Os [outputs](./outputs.tf) (endpoint, CA, subnets, security groups, instance profile, etc.) são lidos pelo Ocean Lab através do state remoto, por isso este projeto precisa ser aplicado primeiro.

## Antes de começar

### Ferramentas

As ferramentas são instaladas pelo [mise](https://mise.jdx.dev/) a partir do `mise.toml` na raiz do repositório:

```bash
mise install
```

### Conta AWS e profile

Você precisa de um profile do AWS CLI com permissão para criar VPC, EKS, EC2 e IAM. O projeto usa o profile `services-admin`; altere para o seu em:

- `locals.tf`: `profile` (e `region`, se não for usar `us-east-1`)
- `versions.tf`: `profile` dentro do bloco `backend "s3"`
- `../ocean-lab/locals.tf`, `../ocean-lab/data.tf` e `../ocean-lab/versions.tf`: o Ocean Lab usa o mesmo profile

### Bucket do state

O state fica em um bucket S3, que **precisa existir antes** do `terraform init`. Crie um bucket (de preferência com versionamento e criptografia) e altere o nome em:

- `versions.tf`: `bucket` dentro do bloco `backend "s3"`
- `locals.tf`: `backend_bucket`
- `../ocean-lab/data.tf` e `../ocean-lab/versions.tf`: o Ocean Lab lê o state deste projeto (key `eks-workshop/terraform.tfstate`) e guarda o seu próprio no mesmo bucket

> O bloco `backend` não aceita variáveis nem locals, por isso o bucket e o profile precisam ser alterados diretamente no `versions.tf`.

### Configurações do cluster

Revise o `locals.tf` antes de aplicar:

- `name`: nome do cluster, que também é usado como identificador no Ocean.
- `cluster_version`: versão do Kubernetes. Os nodes do Ocean usam AMIs AL2023, buscadas no SSM para essa versão.
- `node_group`: tipo de instância e quantidade de nodes do Managed Node Group. Um node é suficiente para o laboratório. O `desired_size` só é usado na criação, depois o módulo ignora alterações nesse valor.

## Executando

```bash
terraform init
terraform plan -out plan
terraform apply plan
```

A criação leva cerca de 15 minutos. Ao final, configure o `kubectl` com o comando do output `configure_kubectl`:

```bash
export AWS_PROFILE=<seu profile>
eval "$(terraform output -raw configure_kubectl)"
kubectl get nodes
```

Com os nodes do Managed Node Group em `Ready`, siga para o [Ocean Lab](../ocean-lab/lab_ocean.md).

## Custos e remoção

O cluster EKS, o NAT Gateway e os nodes do Managed Node Group são cobrados enquanto estiverem ligados, mesmo sem workloads. Ao terminar, remova primeiro o Ocean Lab, seguindo a seção [Limpeza](../ocean-lab/lab_ocean.md#limpeza) do guia, para que o Ocean encerre os nodes que ele criou. Depois, remova este projeto:

```bash
terraform plan -destroy -out plan
terraform apply plan
```
