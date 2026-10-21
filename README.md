# Terraform for RealCloud Pocs

Repositório de provas de conceito (PoCs) de infraestrutura na AWS com Terraform. Cada pasta na raiz é um projeto Terraform independente, com o seu próprio state, e pode depender dos outputs de outro projeto.

## Projetos

| Projeto | O que faz | Depende de |
|---------|-----------|------------|
| [eks-workshop](./eks-workshop/README.md) | VPC, cluster EKS, Managed Node Group e a role dos nodes do Ocean | - |
| [ocean-lab](./ocean-lab/lab_ocean.md) | Integração do Flexera Ocean com o EKS e cenários para testar as suas funcionalidades | eks-workshop |

Comece pelo README de cada projeto, que explica o que precisa ser configurado antes de aplicar.

## Como o repositório funciona

### Ferramentas

As ferramentas (`terraform`, `aws`, `kubectl`, `helm`, `eks-node-viewer`) são instaladas pelo [mise](https://mise.jdx.dev/) a partir do [mise.toml](./mise.toml) na raiz:

```bash
mise install
```

Alguns projetos têm o seu próprio `mise.toml`, por exemplo para carregar variáveis de um arquivo `.env`.

### State e dependências entre projetos

- O state de cada projeto fica em um bucket S3, com uma key por projeto (por exemplo `eks-workshop/terraform.tfstate`). O bucket precisa existir antes do `terraform init`.
- Quando um projeto depende de outro, ele lê os outputs através de um `terraform_remote_state`. Por isso os projetos devem ser aplicados na ordem da tabela acima, e destruídos na ordem inversa.
- O bucket e o profile da AWS estão definidos no bloco `backend` de cada `versions.tf` e no `locals.tf`. Para usar em outra conta, altere esses valores em todos os projetos.

### Convenções

- Os recursos da AWS são criados sempre com os módulos [terraform-aws-modules](https://github.com/terraform-aws-modules).
- As configurações de cada projeto ficam no `locals.tf` (nome, região, profile, tamanhos).
- Credenciais nunca são commitadas: ficam em arquivos `.env` (ignorados pelo git), carregados pelo mise como variáveis `TF_VAR_*`. Cada projeto que precisa de credenciais tem um `.env.example`.
- Arquivos `.tfvars` são ignorados pelo git, exceto os cenários do [ocean-lab](./ocean-lab/scenarios/), que não contêm segredos.

### Executando um projeto

```bash
cd <projeto>
terraform init
terraform plan -out plan
terraform apply plan
```

> Os recursos destes projetos (EKS, NAT Gateway, instâncias EC2) geram custos enquanto estiverem ligados. Ao terminar os testes, execute `terraform destroy` em cada projeto, do último para o primeiro.
