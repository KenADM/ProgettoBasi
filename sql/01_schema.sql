CREATE TABLE COMPAGNIA (
    Nome VARCHAR(50) PRIMARY KEY,
    Amministratore VARCHAR(50) NOT NULL,
    Capitale DECIMAL(15, 2) DEFAULT 0 CHECK (Capitale >= 0),
    NumCittaServite INT DEFAULT 0 
);

CREATE TABLE IMBARCAZIONE (
    CodiceRegistrazione CHAR(10) PRIMARY KEY,
    AnnoCostruzione INT CHECK (AnnoCostruzione > 1900),
    Peso INT,
    Tipo CHAR(1) 
);

CREATE TABLE CITTA (
    Nome VARCHAR(50) PRIMARY KEY,
    Regione VARCHAR(50),
    Provincia CHAR(2),
    NumAbitanti INT CHECK (NumAbitanti >= 0),
    NumCompagnieColleganti INT DEFAULT 0 
);

CREATE TABLE COLLEGAMENTO (
    Num INT PRIMARY KEY,
    Codice VARCHAR(10) NOT NULL,
    NomePartenza VARCHAR(50),
    OraPartenza TIME,
    NomeArrivo VARCHAR(50),
    OraArrivo TIME,
    NomeComp VARCHAR(50),
    CodiceRegistrazione CHAR(10),
    FOREIGN KEY (NomePartenza) REFERENCES CITTA(Nome) ON UPDATE CASCADE,
    FOREIGN KEY (NomeArrivo) REFERENCES CITTA(Nome) ON UPDATE CASCADE,
    FOREIGN KEY (NomeComp) REFERENCES COMPAGNIA(Nome) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (CodiceRegistrazione) REFERENCES IMBARCAZIONE(CodiceRegistrazione)
);

CREATE TABLE PROPRIETA (
    NomeComp VARCHAR(50),
    CodiceRegistrazione CHAR(10),
    DataInizio DATE,
    PRIMARY KEY (NomeComp, CodiceRegistrazione, DataInizio),
    FOREIGN KEY (NomeComp) REFERENCES COMPAGNIA(Nome) ON DELETE CASCADE,
    FOREIGN KEY (CodiceRegistrazione) REFERENCES IMBARCAZIONE(CodiceRegistrazione)
);

