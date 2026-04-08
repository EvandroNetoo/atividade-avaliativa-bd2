-- 00_bootstrap.sql
-- Cria o banco clinica (equivalente a: CREATE DATABASE clinica;)

SELECT 'CREATE DATABASE clinica'
WHERE NOT EXISTS (
  SELECT 1 FROM pg_database WHERE datname = 'clinica'
)\gexec
