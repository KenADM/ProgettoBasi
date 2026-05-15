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
    Num INT NOT NULL,
    Codice VARCHAR(10) NOT NULL,
    NomePartenza VARCHAR(50),
    OraPartenza TIME,
    NomeArrivo VARCHAR(50),
    OraArrivo TIME,
    NomeComp VARCHAR(50),
    CodiceRegistrazione CHAR(10),
    PRIMARY KEY (Num, Codice, NomePartenza, NomeArrivo, CodiceRegistrazione),
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


--TRIGGER--

-- 1 orario dei collegamenti, l'arrivo deve essere > della partenza
CREATE OR REPLACE FUNCTION controlla_orario_collegamento()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Controlliamo se l'orario di arrivo è minore o uguale a quello di partenza
    IF NEW.OraArrivo <= NEW.OraPartenza THEN
        -- Blocchiamo l'operazione con un messaggio di errore chiaro
        RAISE EXCEPTION 'Errore orario: L''ora di arrivo (%) deve essere successiva all''ora di partenza (%) per il collegamento numero %.', NEW.OraArrivo, NEW.OraPartenza, NEW.Num;
    END IF;

    -- Se l'orario è corretto (Arrivo > Partenza), lasciamo passare il dato
    RETURN NEW;
END;
$$ ;

CREATE TRIGGER check_orari_collegamento
BEFORE INSERT OR UPDATE ON Collegamento
FOR EACH ROW
EXECUTE FUNCTION controlla_orario_collegamento();

-- ridondanza NumCompagnieColleganti

-- ridondanza NumCittaServite

-- 2 COLLEGAMENTO deve usare una barca che appartiene alla compagnia che offre il COLLEGAMENTO


-- 3 impedire che due compagnie diverse abbiano acquistato la stessa barca nello stesso momento
CREATE OR REPLACE FUNCTION controlla_data_acquisto_barca()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Cerchiamo SE ESISTE GIÀ una riga nel database che va in conflitto con NEW
    IF EXISTS (
        SELECT * FROM Proprieta P
        WHERE P.CodiceRegistrazione = NEW.CodiceRegistrazione -- Stessa barca
        AND P.DataInizio = NEW.DataInizio                     -- Stesso giorno
        AND P.NomeComp != NEW.NomeComp                        -- MA compagnia diversa!
    ) THEN
        -- Se trova un conflitto, blocca tutto
        RAISE EXCEPTION 'Errore: La barca % è già stata acquistata da un''altra compagnia in data %.', NEW.CodiceRegistrazione, NEW.DataInizio;
    END IF;

    -- Se non ci sono conflitti, diamo il via libera
    RETURN NEW;
END;
$$;

CREATE TRIGGER check_data_acquisto_barca
BEFORE INSERT OR UPDATE ON Proprieta
FOR EACH ROW
EXECUTE FUNCTION controlla_data_acquisto_barca();

-- 4 stessa barca utilizzata in tratte contemporanee
CREATE OR REPLACE FUNCTION controlla_barche_contemporanee()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    
    IF EXISTS (
        SELECT 1 FROM Collegamento C
        WHERE C.CodiceRegistrazione = NEW.CodiceRegistrazione -- Stessa barca
        AND (
            C.Codice <> NEW.Codice
            OR C.Num <> NEW.Num
            OR C.NomePartenza <> NEW.NomePartenza
            OR C.NomeArrivo <> NEW.NomeArrivo
            OR C.CodiceRegistrazione <> NEW.CodiceRegistrazione
            ) -- Escludiamo il collegamento stesso (utile per UPDATE)
        AND C.OraPartenza < NEW.OraArrivo 
        AND C.OraArrivo > NEW.OraPartenza
    ) THEN
        -- Se trova un conflitto, blocca tutto
        RAISE EXCEPTION 'Errore: La barca % è già assegnata a collegamento esistente.', NEW.CodiceRegistrazione;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER check_barche_contemporanee
BEFORE INSERT OR UPDATE ON Collegamento
FOR EACH ROW
EXECUTE FUNCTION controlla_barche_contemporanee();


-- trigger relativi alle chiavi esterne