\connect clinica

-- [1] Só consultas REALIZADAS podem ser faturadas.
create or replace function verificar_consulta_realizada()
returns trigger as $$
	begin
		if not exists(
			select 1 from consulta
			where id_consulta = NEW.id_consulta
			and status = 'REALIZADA'
		) then
			raise exception 'A consulta não pode ser faturda';
		end if;

		return new;
	end	
	$$language plpgsql	


create trigger trg_verificar_consulta_realizada
before insert on fatura_item
for each row
execute function verificar_consulta_realizada();

-- [2] Função SQL: consultas realizadas por convênio.
create or replace function consultas_realizadas_por_convenio()
returns table(
	id_consulta INT,
	paciente VARCHAR,
	medico VARCHAR,
	data_hota TIMESTAMP,
	observacao VARCHAR
) as $$
begin
    return query
    select 
        c.id_consulta,
        p.nome as paciente,
        m.nome as medico,
        c.data_hora,
        c.observacao
    from consulta c
    join paciente p on c.id_paciente = p.id_paciente
    join medico m on c.id_medico = m.id_medico
    join paciente_convenio pc on p.id_paciente = pc.id_paciente
    where pc.id_convenio = p_id_convenio
      and c.status = 'REALIZADA';
end;
$$ language plpgsql;

-- [3] Função PL/pgSQL: consultas a serem realizadas em uma data específica.
create or replace function consultas_por_data(p_data DATE)
return table(
    paciente VARCHAR,
    medico VARCHAR,
    data TIMESTAMP
) as $$
begin
    return query
    select p.nome, m.nome, c.data_hora
    from consulta c
    join paciente p on p.id_paciente = c.id_paciente
    join medico m on m.id_medico = c.id_medico
    where DATE(c.data_hora) = p_data;
end;
$$ LANGUAGE plpgsql;

-- [4] Procedure para marcação de consulta com validações.
CREATE OR REPLACE PROCEDURE sp_marcar_consulta(
  p_id_paciente INT,
  p_id_medico INT,
  p_data_hora TIMESTAMP,
  p_observacao TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_id_paciente IS NULL OR p_id_medico IS NULL OR p_data_hora IS NULL THEN
    RAISE EXCEPTION 'id_paciente, id_medico e data_hora são obrigatórios.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM paciente WHERE id_paciente = p_id_paciente) THEN
    RAISE EXCEPTION 'Paciente % não existe.', p_id_paciente;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM medico WHERE id_medico = p_id_medico) THEN
    RAISE EXCEPTION 'Médico % não existe.', p_id_medico;
  END IF;

  IF p_data_hora <= NOW() THEN
    RAISE EXCEPTION 'A consulta deve ser marcada para data/hora futura.';
  END IF;

  IF EXTRACT(ISODOW FROM p_data_hora) IN (6, 7) THEN
    RAISE EXCEPTION 'Consultas só podem ser marcadas de segunda a sexta-feira.';
  END IF;

  IF p_data_hora::TIME < TIME '07:00' OR p_data_hora::TIME >= TIME '19:00' THEN
    RAISE EXCEPTION 'Horário inválido. Faixa permitida: 07:00 até 18:59.';
  END IF;

  IF EXTRACT(MINUTE FROM p_data_hora) NOT IN (0, 30) THEN
    RAISE EXCEPTION 'Horário inválido. Somente horários em ponto ou meia-hora (:00 ou :30).';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM consulta
    WHERE id_medico = p_id_medico
      AND data_hora = p_data_hora
      AND status = 'AGENDADA'
  ) THEN
    RAISE EXCEPTION 'Médico % já possui consulta agendada em %.', p_id_medico, p_data_hora;
  END IF;

  INSERT INTO consulta (id_paciente, id_medico, data_hora, status, observacao)
  VALUES (p_id_paciente, p_id_medico, p_data_hora, 'AGENDADA', p_observacao);
END;
$$;

-- [5] Views: uma normal e uma materializada.
DROP VIEW IF EXISTS vw_agenda_consultas_dia;
CREATE VIEW vw_agenda_consultas_dia AS
SELECT
  c.id_consulta,
  c.data_hora::DATE AS data,
  TO_CHAR(c.data_hora, 'HH24:MI') AS horario,
  m.nome AS medico,
  p.nome AS paciente,
  c.status
FROM consulta c
JOIN medico m ON m.id_medico = c.id_medico
JOIN paciente p ON p.id_paciente = c.id_paciente;

DROP MATERIALIZED VIEW IF EXISTS mv_faturamento_convenio_mensal;
CREATE MATERIALIZED VIEW mv_faturamento_convenio_mensal AS
SELECT
  cv.id_convenio,
  cv.nome AS convenio,
  DATE_TRUNC('month', f.data_emissao)::DATE AS competencia,
  COUNT(DISTINCT fi.id_consulta) AS qtd_consultas_faturadas,
  COALESCE(SUM(fi.valor), 0)::NUMERIC(10,2) AS total_faturado
FROM convenio cv
LEFT JOIN fatura f ON f.id_convenio = cv.id_convenio
LEFT JOIN fatura_item fi ON fi.id_fatura = f.id_fatura
GROUP BY cv.id_convenio, cv.nome, DATE_TRUNC('month', f.data_emissao)
WITH DATA;

-- [7] Procedure transacional para finalizar consulta e faturar.
-- Observação: se ocorrer erro, a execução do CALL falha e nada é persistido.
CREATE OR REPLACE PROCEDURE sp_realizar_consulta_e_faturar(
  p_id_consulta INT,
  p_procedimentos JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_status_consulta VARCHAR(20);
  v_id_paciente INT;
  v_data_consulta DATE;
  v_id_convenio INT;
  v_id_fatura INT;
  v_item JSONB;
  v_id_procedimento INT;
  v_quantidade INT;
  v_valor_unitario NUMERIC(10,2);
  v_valor_total NUMERIC(10,2) := 0;
  v_qtd_procedimentos INT;
BEGIN
  IF p_id_consulta IS NULL THEN
    RAISE EXCEPTION 'id_consulta é obrigatório.';
  END IF;

  SELECT c.status, c.id_paciente, c.data_hora::DATE
  INTO v_status_consulta, v_id_paciente, v_data_consulta
  FROM consulta c
  WHERE c.id_consulta = p_id_consulta
  FOR UPDATE;

  IF v_status_consulta IS NULL THEN
    RAISE EXCEPTION 'Consulta % não encontrada.', p_id_consulta;
  END IF;

  IF v_status_consulta = 'REALIZADA' THEN
    RAISE EXCEPTION 'Consulta % já está REALIZADA.', p_id_consulta;
  END IF;

  IF v_status_consulta = 'CANCELADA' THEN
    RAISE EXCEPTION 'Consulta % está CANCELADA e não pode ser faturada.', p_id_consulta;
  END IF;

  IF EXISTS (SELECT 1 FROM fatura_item WHERE id_consulta = p_id_consulta) THEN
    RAISE EXCEPTION 'Consulta % já possui item de fatura.', p_id_consulta;
  END IF;

  IF p_procedimentos IS NULL OR jsonb_typeof(p_procedimentos) <> 'array' THEN
    RAISE EXCEPTION 'Procedimentos devem ser informados em array JSONB.';
  END IF;

  v_qtd_procedimentos := jsonb_array_length(p_procedimentos);

  IF v_qtd_procedimentos = 0 THEN
    RAISE EXCEPTION 'Informe ao menos 1 procedimento.';
  END IF;

  IF v_qtd_procedimentos > 3 THEN
    RAISE EXCEPTION 'Uma consulta pode conter no máximo 3 procedimentos.';
  END IF;

  SELECT pc.id_convenio
  INTO v_id_convenio
  FROM paciente_convenio pc
  WHERE pc.id_paciente = v_id_paciente
    AND (pc.validade IS NULL OR pc.validade >= v_data_consulta)
  ORDER BY pc.validade DESC NULLS LAST
  LIMIT 1;

  IF v_id_convenio IS NULL THEN
    RAISE EXCEPTION 'Paciente da consulta % não possui convênio válido na data da consulta.', p_id_consulta;
  END IF;

  UPDATE consulta
  SET status = 'REALIZADA'
  WHERE id_consulta = p_id_consulta;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_procedimentos)
  LOOP
    v_id_procedimento := (v_item ->> 'id_procedimento')::INT;
    v_quantidade := COALESCE((v_item ->> 'quantidade')::INT, 1);

    IF v_id_procedimento IS NULL THEN
      RAISE EXCEPTION 'Cada item deve conter id_procedimento.';
    END IF;

    IF v_quantidade <= 0 THEN
      RAISE EXCEPTION 'Quantidade inválida para procedimento %.', v_id_procedimento;
    END IF;

    SELECT valor INTO v_valor_unitario
    FROM procedimento
    WHERE id_procedimento = v_id_procedimento;

    IF v_valor_unitario IS NULL THEN
      RAISE EXCEPTION 'Procedimento % não encontrado.', v_id_procedimento;
    END IF;

    INSERT INTO consulta_procedimento (id_consulta, id_procedimento, quantidade)
    VALUES (p_id_consulta, v_id_procedimento, v_quantidade)
    ON CONFLICT (id_consulta, id_procedimento)
    DO UPDATE SET quantidade = EXCLUDED.quantidade;

    v_valor_total := v_valor_total + (v_valor_unitario * v_quantidade);
  END LOOP;

  SELECT f.id_fatura
  INTO v_id_fatura
  FROM fatura f
  WHERE f.id_convenio = v_id_convenio
    AND f.status = 'PENDENTE'
    AND DATE_TRUNC('month', f.data_emissao) = DATE_TRUNC('month', CURRENT_DATE)
  ORDER BY f.id_fatura DESC
  LIMIT 1;

  IF v_id_fatura IS NULL THEN
    INSERT INTO fatura (id_convenio, data_emissao, valor_total, status)
    VALUES (v_id_convenio, CURRENT_DATE, 0, 'PENDENTE')
    RETURNING id_fatura INTO v_id_fatura;
  END IF;

  INSERT INTO fatura_item (id_fatura, id_consulta, valor)
  VALUES (v_id_fatura, p_id_consulta, v_valor_total);
END;
$$;

-- [8] RULE: impedir exclusão de consulta REALIZADA.
DROP RULE IF EXISTS rl_impedir_delete_consulta_realizada ON consulta;
CREATE RULE rl_impedir_delete_consulta_realizada AS
ON DELETE TO consulta
WHERE OLD.status = 'REALIZADA'
DO INSTEAD NOTHING;

-- [9] RULE: atualizar total da fatura ao inserir item.
DROP RULE IF EXISTS rl_atualizar_total_fatura ON fatura_item;
CREATE RULE rl_atualizar_total_fatura AS
ON INSERT TO fatura_item
DO ALSO
  UPDATE fatura
  SET valor_total = COALESCE((
    SELECT SUM(fi.valor)
    FROM fatura_item fi
    WHERE fi.id_fatura = NEW.id_fatura
  ), 0)
  WHERE id_fatura = NEW.id_fatura;

-- Recalcula totais existentes e atualiza a materialized view.
UPDATE fatura f
SET valor_total = COALESCE((
  SELECT SUM(fi.valor)
  FROM fatura_item fi
  WHERE fi.id_fatura = f.id_fatura
), 0);

REFRESH MATERIALIZED VIEW mv_faturamento_convenio_mensal;
