# [10] Crítica do modelo proposto

## Pontos positivos
- Modelo separado por entidades centrais (`paciente`, `medico`, `consulta`, `procedimento`, `fatura`) e tabelas de relacionamento.
- Índice único parcial (`idx_medico_horario`) resolve conflito de agenda para consultas agendadas.
- Uso de `consulta_procedimento` para permitir múltiplos procedimentos por consulta.

## Limitações e riscos
- `paciente_convenio` não impede múltiplas carteiras válidas simultâneas para o mesmo paciente e convênio.
- Falta controle de vigência histórica (data início/fim) do convênio do paciente, o que pode causar ambiguidades de faturamento retroativo.
- Regras de negócio dependem de `status` textual; ideal usar domínio/enum para consistência.
- `fatura_item` não guarda detalhamento dos procedimentos cobrados (apenas total da consulta), dificultando auditoria.
- `consulta` não possui duração/sala/unidade, limitando evolução para agenda real.
- Uso de `RULE` em PostgreSQL é legado para muitas situações; em produção normalmente preferimos `TRIGGER` para previsibilidade.

## Melhorias sugeridas
- Adicionar `data_inicio` e `data_fim` em `paciente_convenio` + restrição para evitar sobreposição.
- Criar enum/domínios para status de consulta e fatura.
- Criar `fatura_item_procedimento` para rastrear procedimentos faturados por item.
- Padronizar identificadores sensíveis com validações (`CHECK` para formato de CPF/CNPJ/CRM).
- Adotar auditoria (ex.: tabela de log de alterações de status).
- Avaliar substituição das `RULES` por `TRIGGERS` em cenários críticos de integridade.

## Conclusão
O modelo é bom para um cenário acadêmico inicial e atende o fluxo principal de agendamento e cobrança. Para ambiente real, o principal ajuste é fortalecer histórico de convênio, rastreabilidade de faturamento e governança de status.
