# Atividade Avaliativa BD2 - Clínica (PostgreSQL + Docker Compose)

Este projeto entrega uma implementação completa do banco `clinica` em PostgreSQL, com scripts organizados para facilitar correção e repetição dos testes.

## Estrutura

- `docker-compose.yml`: sobe PostgreSQL 16.
- `sql/00_bootstrap.sql`: cria o banco `clinica`.
- `sql/01_schema.sql`: cria tabelas, constraints e índice.
- `sql/02_seed.sql`: dados iniciais.
- `sql/03_business_rules.sql`: trigger, funções, procedures, views, rules e recalculo de faturas.
- `sql/04_security.sql`: política de segurança (grupos, usuários e privilégios).
- `sql/05_tests.sql`: roteiro de testes manuais.
- `docs/10_critica_modelo.md`: crítica do modelo proposto (questão 10).

## Como executar

1. Subir o banco:

```bash
docker compose up -d
```

2. Validar se está pronto:

```bash
docker compose ps
```

3. Conectar via `psql`:

```bash
docker exec -it clinica-postgres psql -U postgres -d clinica
```

4. Rodar testes da atividade:

```bash
docker exec -i clinica-postgres psql -U postgres -d clinica < sql/05_tests.sql
```

## Reprocessar tudo do zero

Os scripts de `docker-entrypoint-initdb.d` rodam apenas na primeira criação do volume.
Para recriar tudo:

```bash
docker compose down -v
docker compose up -d
```

## Mapeamento das questões

1. Só consultas REALIZADAS faturam: trigger `trg_validar_fatura_item_realizada` em `sql/03_business_rules.sql`.
2. Função SQL por convênio: `fn_consultas_realizadas_por_convenio`.
3. Função PLpgSQL por data: `fn_consultas_a_realizar_por_data`.
4. Stored procedure de marcação: `sp_marcar_consulta` com validações de entrada e horário.
5. Views:
   - Normal: `vw_agenda_consultas_dia`
   - Materializada: `mv_faturamento_convenio_mensal`
6. Segurança: `sql/04_security.sql` (3 grupos + 5 usuários + grants).
7. Procedure transacional: `sp_realizar_consulta_e_faturar`.
8. Rule anti-exclusão de realizada: `rl_impedir_delete_consulta_realizada`.
9. Rule para atualizar total da fatura no insert: `rl_atualizar_total_fatura`.
10. Crítica do modelo: `docs/10_critica_modelo.md`.

## Usuários criados para teste de segurança

- Grupo `grp_admin_clinica`: `usr_admin` / senha `admin123`
- Grupo `grp_atendimento`: `usr_recepcao1`, `usr_recepcao2` / senha `recepcao123`
- Grupo `grp_faturamento`: `usr_faturista1`, `usr_faturista2` / senha `fatura123`

## Observações de avaliação

- O item [7] está implementado em procedure única, validando limite de 3 procedimentos e impedindo faturamento duplicado por consulta.
- Se qualquer validação falhar no `CALL`, a execução é abortada sem persistir alterações parciais.
- A materialized view pode ser atualizada com:

```sql
REFRESH MATERIALIZED VIEW mv_faturamento_convenio_mensal;
```
