\connect clinica

-- [6] Política de segurança com grupos e usuários.

-- Grupos (roles sem login)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'grp_admin_clinica') THEN
    CREATE ROLE grp_admin_clinica NOLOGIN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'grp_atendimento') THEN
    CREATE ROLE grp_atendimento NOLOGIN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'grp_faturamento') THEN
    CREATE ROLE grp_faturamento NOLOGIN;
  END IF;
END;
$$;

-- Usuários (5 usuários)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_admin') THEN
    CREATE ROLE usr_admin LOGIN PASSWORD 'admin123';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_recepcao1') THEN
    CREATE ROLE usr_recepcao1 LOGIN PASSWORD 'recepcao123';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_recepcao2') THEN
    CREATE ROLE usr_recepcao2 LOGIN PASSWORD 'recepcao123';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_faturista1') THEN
    CREATE ROLE usr_faturista1 LOGIN PASSWORD 'fatura123';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_faturista2') THEN
    CREATE ROLE usr_faturista2 LOGIN PASSWORD 'fatura123';
  END IF;
END;
$$;

-- Associação dos usuários aos grupos
GRANT grp_admin_clinica TO usr_admin;
GRANT grp_atendimento TO usr_recepcao1, usr_recepcao2;
GRANT grp_faturamento TO usr_faturista1, usr_faturista2;

-- Endurecimento de segurança básico
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- Permissões do grupo admin (acesso total no schema public)
GRANT USAGE, CREATE ON SCHEMA public TO grp_admin_clinica;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO grp_admin_clinica;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO grp_admin_clinica;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO grp_admin_clinica;

-- Permissões do atendimento
GRANT USAGE ON SCHEMA public TO grp_atendimento;
GRANT SELECT, INSERT, UPDATE ON paciente TO grp_atendimento;
GRANT SELECT ON medico, convenio, procedimento TO grp_atendimento;
GRANT SELECT, INSERT, UPDATE ON paciente_convenio TO grp_atendimento;
GRANT SELECT, INSERT, UPDATE ON consulta TO grp_atendimento;
GRANT SELECT ON vw_agenda_consultas_dia TO grp_atendimento;
GRANT USAGE, SELECT ON SEQUENCE paciente_id_paciente_seq TO grp_atendimento;
GRANT USAGE, SELECT ON SEQUENCE paciente_convenio_id_paciente_convenio_seq TO grp_atendimento;
GRANT USAGE, SELECT ON SEQUENCE consulta_id_consulta_seq TO grp_atendimento;
GRANT EXECUTE ON FUNCTION fn_consultas_a_realizar_por_data(DATE) TO grp_atendimento;
GRANT EXECUTE ON PROCEDURE sp_marcar_consulta(INT, INT, TIMESTAMP, TEXT) TO grp_atendimento;

-- Permissões do faturamento
GRANT USAGE ON SCHEMA public TO grp_faturamento;
GRANT SELECT ON paciente, medico, convenio, consulta, procedimento TO grp_faturamento;
GRANT SELECT, INSERT, UPDATE ON consulta_procedimento TO grp_faturamento;
GRANT SELECT, INSERT, UPDATE ON fatura, fatura_item TO grp_faturamento;
GRANT SELECT ON mv_faturamento_convenio_mensal TO grp_faturamento;
GRANT USAGE, SELECT ON SEQUENCE fatura_id_fatura_seq TO grp_faturamento;
GRANT USAGE, SELECT ON SEQUENCE fatura_item_id_fatura_item_seq TO grp_faturamento;
GRANT EXECUTE ON FUNCTION fn_consultas_realizadas_por_convenio(INT) TO grp_faturamento;
GRANT EXECUTE ON PROCEDURE sp_realizar_consulta_e_faturar(INT, JSONB) TO grp_faturamento;

-- Privilégios padrão para novos objetos criados pelo dono atual
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL PRIVILEGES ON TABLES TO grp_admin_clinica;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL PRIVILEGES ON SEQUENCES TO grp_admin_clinica;
