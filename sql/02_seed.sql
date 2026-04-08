\connect clinica

INSERT INTO paciente (id_paciente, nome, cpf, data_nascimento, telefone, email) VALUES
  (1, 'João Silva', '111.111.111-11', '1985-03-10', '(27)99999-1111', 'joao@email.com'),
  (2, 'Maria Oliveira', '222.222.222-22', '1990-07-21', '(27)99999-2222', 'maria@email.com'),
  (3, 'Carlos Souza', '333.333.333-33', '1978-11-05', '(27)99999-3333', 'carlos@email.com')
ON CONFLICT (id_paciente) DO NOTHING;

INSERT INTO medico (id_medico, nome, crm, especialidade) VALUES
  (1, 'Dr. Pedro Santos', 'CRM12345', 'Clínico Geral'),
  (2, 'Dra. Ana Costa', 'CRM67890', 'Cardiologia')
ON CONFLICT (id_medico) DO NOTHING;

INSERT INTO convenio (id_convenio, nome, cnpj, telefone) VALUES
  (1, 'Unimed', '00.000.000/0001-00', '(27)3333-0000'),
  (2, 'Amil', '11.111.111/0001-11', '(27)3333-1111')
ON CONFLICT (id_convenio) DO NOTHING;

INSERT INTO paciente_convenio (id_paciente_convenio, id_paciente, id_convenio, numero_carteira, validade) VALUES
  (1, 1, 1, 'UNI123', '2026-12-31'),
  (2, 2, 1, 'UNI456', '2026-12-31'),
  (3, 3, 2, 'AMI789', '2026-06-30')
ON CONFLICT (id_paciente_convenio) DO NOTHING;

INSERT INTO consulta (id_consulta, id_paciente, id_medico, data_hora, status, observacao) VALUES
  (1, 1, 1, '2026-03-25 08:00:00', 'REALIZADA', 'Consulta de rotina'),
  (2, 2, 2, '2026-03-25 09:00:00', 'AGENDADA', 'Avaliação cardíaca'),
  (3, 3, 1, '2026-03-25 10:00:00', 'AGENDADA', 'Dor abdominal')
ON CONFLICT (id_consulta) DO NOTHING;

INSERT INTO procedimento (id_procedimento, descricao, valor) VALUES
  (1, 'Consulta Clínica', 100.00),
  (2, 'Eletrocardiograma', 200.00),
  (3, 'Exame de Sangue', 80.00)
ON CONFLICT (id_procedimento) DO NOTHING;

INSERT INTO consulta_procedimento (id_consulta, id_procedimento, quantidade) VALUES
  (1, 1, 1),
  (1, 3, 1)
ON CONFLICT (id_consulta, id_procedimento) DO NOTHING;

INSERT INTO fatura (id_fatura, id_convenio, data_emissao, valor_total, status) VALUES
  (1, 1, CURRENT_DATE, 0.00, 'PENDENTE'),
  (2, 2, CURRENT_DATE, 0.00, 'PENDENTE')
ON CONFLICT (id_fatura) DO NOTHING;

INSERT INTO fatura_item (id_fatura_item, id_fatura, id_consulta, valor) VALUES
  (1, 1, 1, 180.00)
ON CONFLICT (id_fatura_item) DO NOTHING;

SELECT setval('paciente_id_paciente_seq', COALESCE((SELECT MAX(id_paciente) FROM paciente), 1));
SELECT setval('medico_id_medico_seq', COALESCE((SELECT MAX(id_medico) FROM medico), 1));
SELECT setval('convenio_id_convenio_seq', COALESCE((SELECT MAX(id_convenio) FROM convenio), 1));
SELECT setval('paciente_convenio_id_paciente_convenio_seq', COALESCE((SELECT MAX(id_paciente_convenio) FROM paciente_convenio), 1));
SELECT setval('consulta_id_consulta_seq', COALESCE((SELECT MAX(id_consulta) FROM consulta), 1));
SELECT setval('procedimento_id_procedimento_seq', COALESCE((SELECT MAX(id_procedimento) FROM procedimento), 1));
SELECT setval('fatura_id_fatura_seq', COALESCE((SELECT MAX(id_fatura) FROM fatura), 1));
SELECT setval('fatura_item_id_fatura_item_seq', COALESCE((SELECT MAX(id_fatura_item) FROM fatura_item), 1));
