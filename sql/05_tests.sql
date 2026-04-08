\connect clinica

-- Script de testes manuais para validação dos requisitos.

-- [2] Consultas realizadas por convênio.
SELECT * FROM fn_consultas_realizadas_por_convenio(1);

-- [3] Consultas agendadas por data.
SELECT * FROM fn_consultas_a_realizar_por_data('2026-03-25');

-- [4] Marcação de consulta (deve funcionar).
CALL sp_marcar_consulta(
  1,
  2,
  '2026-12-01 10:30:00',
  'Retorno com cardiologista'
);

-- [1] Trigger de faturamento (deve falhar, pois consulta 2 está AGENDADA).
-- Descomente para testar erro:
-- INSERT INTO fatura_item (id_fatura, id_consulta, valor) VALUES (1, 2, 100.00);

-- [7] Realizar e faturar consulta em uma transação.
BEGIN;
  CALL sp_realizar_consulta_e_faturar(
    2,
    '[{"id_procedimento":1,"quantidade":1},{"id_procedimento":2,"quantidade":1}]'::jsonb
  );
COMMIT;

-- Verificações após procedure transacional.
SELECT id_consulta, status FROM consulta WHERE id_consulta = 2;
SELECT * FROM fatura_item WHERE id_consulta = 2;
SELECT * FROM fatura WHERE id_fatura = 1;

-- [5] View comum.
SELECT * FROM vw_agenda_consultas_dia ORDER BY data, horario;

-- [5] View materializada.
REFRESH MATERIALIZED VIEW mv_faturamento_convenio_mensal;
SELECT * FROM mv_faturamento_convenio_mensal ORDER BY convenio, competencia;

-- [8] RULE anti-delete (deve não excluir consulta realizada).
DELETE FROM consulta WHERE id_consulta = 1;
SELECT id_consulta, status FROM consulta WHERE id_consulta = 1;

-- [9] RULE de total da fatura (insira item para ver atualização automática).
-- Exemplo: primeiro marque uma nova consulta como REALIZADA e depois insira item em fatura_item.
