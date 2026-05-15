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
    Tipo VARCHAR(50)
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

-- ridondanza NumCompagnieColleganti
CREATE OR REPLACE FUNCTION aggiorno_NumCompagnieColleganti()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Aggiorniamo le Città coinvolte (sia quella di partenza che quella di arrivo)
    UPDATE Citta
    SET NumCompagnieColleganti = (
        -- Conta le compagnie UNICHE (senza duplicati)
        SELECT COUNT(DISTINCT NomeComp)
        FROM COLLEGAMENTO
        -- ...che partono o arrivano in QUESTA specifica città che stiamo aggiornando
        WHERE NomePartenza = Citta.Nome OR NomeArrivo = Citta.Nome
    )
    -- Applica questo aggiornamento solo alle due città toccate dal nuovo inserimento
    WHERE Nome IN (NEW.NomePartenza, NEW.NomeArrivo);

    RETURN NEW;
END;
$$;

CREATE TRIGGER aggiorno_NumCompagnieColleganti
AFTER INSERT OR UPDATE ON Collegamento
FOR EACH ROW
EXECUTE FUNCTION aggiorno_NumCompagnieColleganti();


-- ridondanza NumCittaServite
CREATE OR REPLACE FUNCTION aggiorno_NumCittaServite()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Aggiorniamo il numero di città servite per la compagnia coinvolta
    UPDATE COMPAGNIA
    SET NumCittaServite = (
        SELECT COUNT(*) AS Totale_Citta
        FROM (
            SELECT NomePartenza AS NomePorto 
            FROM COLLEGAMENTO
            WHERE NomeComp = NEW.NomeComp
            UNION
            SELECT NomeArrivo AS NomePorto FROM COLLEGAMENTO
            WHERE NomeComp = NEW.NomeComp
        ) AS ListaCitta
    )
    WHERE Nome = NEW.NomeComp;

    RETURN NEW;
END;
$$ ;

CREATE TRIGGER aggiorno_NumCittaServite
AFTER INSERT OR UPDATE ON Collegamento
FOR EACH ROW
EXECUTE FUNCTION aggiorno_NumCittaServite();

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


-- 2 COLLEGAMENTO deve usare una barca che appartiene alla compagnia che offre il COLLEGAMENTO attualmente
CREATE OR REPLACE FUNCTION controlla_validazione_barca_collegamento()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    ValidProprietario RECORD;
BEGIN
    SELECT * INTO ValidProprietario 
    FROM Proprieta P
    WHERE NEW.CodiceRegistrazione = P.CodiceRegistrazione -- Stessa barca
    ORDER BY P.DataInizio DESC
    LIMIT 1;

    -- controllo che la barca abbia un proprietario
    IF ValidProprietario.NomeComp IS NULL THEN
        RAISE EXCEPTION 'Errore: La barca % non risulta registrata a nessuna compagnia.', NEW.CodiceRegistrazione;
    END IF;

    -- controllo che il collegamento sia offerto dal proprietario della barca
    IF ValidProprietario.NomeComp != NEW.NomeComp THEN
        RAISE EXCEPTION 'Errore: La barca % non appartiene alla compagnia %.', NEW.CodiceRegistrazione, NEW.NomeComp;
    END IF;

    -- Se non ci sono conflitti, diamo il via libera
    RETURN NEW;
END;
$$ ;

CREATE TRIGGER check_validazione_barca_collegamento
BEFORE INSERT OR UPDATE ON Collegamento
FOR EACH ROW
EXECUTE FUNCTION controlla_validazione_barca_collegamento();

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

