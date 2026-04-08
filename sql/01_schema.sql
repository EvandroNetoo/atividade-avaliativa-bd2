\connect clinica

CREATE TABLE IF NOT EXISTS paciente (
  id_paciente SERIAL PRIMARY KEY,
  nome VARCHAR(100) NOT NULL,
  cpf VARCHAR(14) UNIQUE NOT NULL,
  data_nascimento DATE,
  telefone VARCHAR(20),
  email VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS medico (
  id_medico SERIAL PRIMARY KEY,
  nome VARCHAR(100) NOT NULL,
  crm VARCHAR(20) UNIQUE NOT NULL,
  especialidade VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS convenio (
  id_convenio SERIAL PRIMARY KEY,
  nome VARCHAR(100) NOT NULL,
  cnpj VARCHAR(18) UNIQUE,
  telefone VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS paciente_convenio (
  id_paciente_convenio SERIAL PRIMARY KEY,
  id_paciente INT NOT NULL,
  id_convenio INT NOT NULL,
  numero_carteira VARCHAR(50),
  validade DATE,
  FOREIGN KEY (id_paciente) REFERENCES paciente(id_paciente),
  FOREIGN KEY (id_convenio) REFERENCES convenio(id_convenio)
);

CREATE TABLE IF NOT EXISTS consulta (
  id_consulta SERIAL PRIMARY KEY,
  id_paciente INT NOT NULL,
  id_medico INT NOT NULL,
  data_hora TIMESTAMP NOT NULL,
  status VARCHAR(20) DEFAULT 'AGENDADA'
    CHECK (status IN ('AGENDADA', 'REALIZADA', 'CANCELADA')),
  observacao TEXT,
  FOREIGN KEY (id_paciente) REFERENCES paciente(id_paciente),
  FOREIGN KEY (id_medico) REFERENCES medico(id_medico)
);

CREATE TABLE IF NOT EXISTS procedimento (
  id_procedimento SERIAL PRIMARY KEY,
  descricao VARCHAR(100) NOT NULL,
  valor NUMERIC(10,2) NOT NULL CHECK (valor >= 0)
);

CREATE TABLE IF NOT EXISTS consulta_procedimento (
  id_consulta INT,
  id_procedimento INT,
  quantidade INT DEFAULT 1 CHECK (quantidade > 0),
  PRIMARY KEY (id_consulta, id_procedimento),
  FOREIGN KEY (id_consulta) REFERENCES consulta(id_consulta),
  FOREIGN KEY (id_procedimento) REFERENCES procedimento(id_procedimento)
);

CREATE TABLE IF NOT EXISTS fatura (
  id_fatura SERIAL PRIMARY KEY,
  id_convenio INT NOT NULL,
  data_emissao DATE DEFAULT CURRENT_DATE,
  valor_total NUMERIC(10,2) DEFAULT 0,
  status VARCHAR(20) DEFAULT 'PENDENTE'
    CHECK (status IN ('PENDENTE', 'PAGA', 'CANCELADA')),
  FOREIGN KEY (id_convenio) REFERENCES convenio(id_convenio)
);

CREATE TABLE IF NOT EXISTS fatura_item (
  id_fatura_item SERIAL PRIMARY KEY,
  id_fatura INT NOT NULL,
  id_consulta INT NOT NULL,
  valor NUMERIC(10,2) NOT NULL CHECK (valor >= 0),
  FOREIGN KEY (id_fatura) REFERENCES fatura(id_fatura),
  FOREIGN KEY (id_consulta) REFERENCES consulta(id_consulta),
  UNIQUE (id_consulta)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_medico_horario
  ON consulta (id_medico, data_hora)
  WHERE status = 'AGENDADA';
