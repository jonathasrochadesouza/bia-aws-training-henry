# BIA - Projeto Formação AWS v4.2.0

Projeto educacional criado por [Henrylle Maia](https://github.com/henrylle) para o evento **Imersão AWS & IA**.

**Período do evento:** 21/03 e 22/03/2026 (Online e ao Vivo das 9h30 às 17h30)

[>> Página de Inscrição](https://org.imersaoaws.com.br/github/readme)

---

## Stack

- **Frontend:** React 17 + Vite
- **Backend:** Node.js + Express 4
- **Banco de Dados:** PostgreSQL 16 (via Sequelize ORM)
- **Containerização:** Docker + Docker Compose

---

## Ambientes

A aplicação está exposta via **Application Load Balancer (ALB)** com dois endpoints, cada um roteando para um Target Group (TG) distinto:

| Endpoint | Target Group | Descrição |
|---|---|---|
| [formacao-dev.jkrocha.com.br](http://formacao-dev.jkrocha.com.br) | `tg-bia-dev` | Ambiente de desenvolvimento — ECS Service com a versão em progresso |
| [formacaojkrocha.com.br](http://formacaojkrocha.com.br) | `tg-bia-prod` | Ambiente de produção — ECS Service com a versão estável |

O ALB utiliza **Listener Rules** baseadas no `Host Header` para direcionar cada domínio ao seu respectivo Target Group, permitindo que ambos os ambientes rodem no mesmo cluster ECS com isolamento de tráfego.

---

## Endpoints da API

| Rota | Descrição |
|---|---|
| `GET /api/versao` | Retorna a versão da aplicação (sem banco) |
| `GET /api/tarefas` | Retorna tarefas do banco PostgreSQL |

---

## Rodando localmente

```bash
docker compose up
```

### Migrations

```bash
docker compose exec server bash -c 'npx sequelize db:migrate'
```

---

## Pipeline CI/CD

O deploy é automatizado via **AWS CodePipeline + CodeBuild**:

1. **Source** — Push no GitHub dispara o pipeline
2. **Build** — CodeBuild executa o `buildspec.yml`, gera a imagem Docker e faz push para o ECR
3. **Deploy** — ECS atualiza o serviço com a nova imagem (rolling update)

## Recriar Infraestrutura

```bash
cd terraform
terraform init
terraform apply
```

---

## Estrutura do Projeto

```
/
├── api/                  # Rotas e controllers do backend
├── client/               # Aplicação React (frontend)
├── config/               # Configurações da aplicação
├── database/             # Migrations e seeds (Sequelize)
├── scripts/              # Scripts auxiliares
├── tests/                # Testes unitários (Jest)
├── docs/                 # Documentação
├── terraform/            # Infraestrutura como código (IaC)
│   ├── main.tf           # Provider AWS
│   ├── variables.tf      # Variáveis (região, VPC, imagens, credenciais)
│   ├── ecr.tf            # Repositório ECR
│   ├── security_groups.tf# Security Groups (bia-alb, bia-ec2, bia-db, bia-web, bia-dev)
│   ├── alb.tf            # ALB + Target Groups + Listeners + Listener Rules
│   ├── ecs.tf            # Cluster ECS + ASG + Task Definitions + Services
│   ├── rds.tf            # RDS PostgreSQL (prod + dev)
│   └── outputs.tf        # Outputs pós-apply
├── compose.yml           # Docker Compose (ambiente local)
├── Dockerfile            # Imagem da aplicação
├── buildspec.yml         # AWS CodeBuild (CI/CD)
└── package.json          # Dependências Node.js
```
