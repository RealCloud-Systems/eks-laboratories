# Terraform for RealCloud Laboratories

Aqui você encontra laboratórios guiados para testar os produtos RealCloud em seu ambiente na nuvem.
Confira abaixo quais laboratórios nós temos.
E lembre-se, que sempre que terminar um laboratório, de destruir a infraestrutura para evitar custos indesejados.

Bom laboratório!

## Projetos

| Projeto | O que faz | Depende de |
|---------|-----------|------------|
| [eks-workshop](./eks-workshop/README.md) | VPC, cluster EKS, Managed Node Group e a role dos nodes do Ocean | - |
| [ocean-lab](./ocean-lab/lab_ocean.md) | Integração do Flexera Ocean com o EKS e cenários para testar as suas funcionalidades | eks-workshop |
| [elastic-lab](./elastic-lab/lab_elastic.md) | Flexera Elastigroup com instâncias EC2 atrás de um ALB e cenários para testar as suas funcionalidades | - |

Comece pela documentação de cada projeto (o README do eks-workshop e os guias do ocean-lab e do elastic-lab), que explica o que precisa ser configurado antes de aplicar.

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
- O bucket e o profile da AWS estão definidos no bloco `backend` de cada `versions.tf` e no `locals.tf` (no ocean-lab, também no `data.tf`, que lê o state do eks-workshop). Para usar em outra conta, altere esses valores em todos os projetos.

### Convenções

- Os recursos da AWS são criados com os módulos [terraform-aws-modules](https://github.com/terraform-aws-modules). Somente recursos que não têm módulo (como o experimento do AWS FIS do ocean-lab) usam o recurso do provider diretamente.
- As configurações de cada projeto ficam no `locals.tf` (nome, região, profile, tamanhos). No ocean-lab e no elastic-lab, as funcionalidades da Spot são configuradas pelas variáveis do `variables.tf` e pelos cenários em `scenarios/`.
- Credenciais nunca são commitadas: ficam em arquivos `.env` (ignorados pelo git), carregados pelo mise como variáveis `TF_VAR_*`. Cada projeto que precisa de credenciais tem um `.env.example`, e o seu `mise.toml` precisa ser marcado como confiável uma vez com `mise trust`.
- Arquivos `.tfvars` são ignorados pelo git, exceto os cenários do [ocean-lab](./ocean-lab/scenarios/) e do [elastic-lab](./elastic-lab/scenarios/), que não contêm segredos.

### Executando um projeto

```bash
cd <projeto>
terraform init
terraform plan -out plan
terraform apply plan
```

O plano é sempre gerado com `plan -out` e aplicado a partir do arquivo salvo. No ocean-lab e no elastic-lab, o `terraform plan` recebe também o arquivo do cenário (`-var-file=scenarios/<cenário>.tfvars`).

> Os recursos destes projetos (EKS, ALB, NAT Gateway, instâncias EC2) geram custos enquanto estiverem ligados. Ao terminar os testes, destrua cada projeto, do último para o primeiro, gerando o plano de remoção com `terraform plan -destroy -out plan` e aplicando com `terraform apply plan`.
