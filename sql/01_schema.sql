CREATE TABLE COMPAGNIA (
    Nome VARCHAR(50) PRIMARY KEY,
    Amministratore VARCHAR(50) NOT NULL,
    Capitale DECIMAL(15, 2) DEFAULT 0 CHECK (Capitale >= 0),
    NumCittaServite INT DEFAULT 0 
);

CREATE TABLE IMBARCAZIONE (
    CodiceRegistrazione CHAR(10) PRIMARY KEY,
    AnnoCostruzione INT CHECK (AnnoCostruzione >= 0 AND AnnoCostruzione <= EXTRACT(YEAR FROM CURRENT_DATE)),
    Peso INT CHECK (Peso >= 0),
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
    Num INT NOT NULL, --numero dell'entita
    NomePartenza VARCHAR(50), --citta
    OraPartenza TIME, --relazione con citta
    NomeArrivo VARCHAR(50), --citta
    OraArrivo TIME, -- relazione con citta
    NomeComp VARCHAR(50), --compagna
    CodiceRegistrazione CHAR(10), --barca
    PRIMARY KEY (Num, NomePartenza, NomeArrivo, CodiceRegistrazione),
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
    FOREIGN KEY (NomeComp) REFERENCES COMPAGNIA(Nome) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (CodiceRegistrazione) REFERENCES IMBARCAZIONE(CodiceRegistrazione)
);


--TRIGGER--

-- ridondanza NumCompagnieColleganti
CREATE OR REPLACE FUNCTION aggiorno_NumCompagnieColleganti()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    citta_partenza VARCHAR;
    citta_arrivo VARCHAR;
BEGIN
    -- 1. Determiniamo quali città aggiornare in base all'operazione
    IF TG_OP = 'DELETE' THEN
        citta_partenza := OLD.NomePartenza;
        citta_arrivo := OLD.NomeArrivo;
    ELSE
        citta_partenza := NEW.NomePartenza;
        citta_arrivo := NEW.NomeArrivo;
    END IF;

    -- 2. Aggiorniamo le città toccate dal nuovo inserimento o dalla cancellazione
    UPDATE CITTA
    SET NumCompagnieColleganti = (
        SELECT COUNT(DISTINCT NomeComp)
        FROM COLLEGAMENTO
        WHERE NomePartenza = CITTA.Nome OR NomeArrivo = CITTA.Nome
    )
    WHERE Nome IN (citta_partenza, citta_arrivo);

    -- 3. In caso di UPDATE, se le città sono cambiate, dobbiamo aggiornare anche i totali delle VECCHIE città
    IF TG_OP = 'UPDATE' AND (OLD.NomePartenza != NEW.NomePartenza OR OLD.NomeArrivo != NEW.NomeArrivo) THEN
        UPDATE CITTA
        SET NumCompagnieColleganti = (
            SELECT COUNT(DISTINCT NomeComp)
            FROM COLLEGAMENTO
            WHERE NomePartenza = CITTA.Nome OR NomeArrivo = CITTA.Nome
        )
        WHERE Nome IN (OLD.NomePartenza, OLD.NomeArrivo);
    END IF;

    -- 4. Ritorno corretto in base all'operazione
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS aggiorno_NumCompagnieColleganti ON Collegamento;

CREATE TRIGGER aggiorno_NumCompagnieColleganti
AFTER INSERT OR UPDATE OR DELETE ON Collegamento
FOR EACH ROW
EXECUTE FUNCTION aggiorno_NumCompagnieColleganti();

-- ridondanza NumCittaServite 
CREATE OR REPLACE FUNCTION aggiorno_NumCittaServite()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    compagnia_coinvolta VARCHAR;
BEGIN
    -- 1. Determiniamo la compagnia in base all'operazione
    IF TG_OP = 'DELETE' THEN
        compagnia_coinvolta := OLD.NomeComp;
    ELSE
        compagnia_coinvolta := NEW.NomeComp;
    END IF;

    -- 2. Aggiorniamo il numero di città servite per la compagnia coinvolta
    UPDATE COMPAGNIA
    SET NumCittaServite = (
        SELECT COUNT(DISTINCT porto)
        FROM COLLEGAMENTO,
             UNNEST(ARRAY[NomePartenza, NomeArrivo]) AS porto
        WHERE NomeComp = compagnia_coinvolta
    )
    WHERE Nome = compagnia_coinvolta;

    -- 3. Se è un UPDATE e la compagnia è cambiata (es. cessione del collegamento), aggiorniamo anche la vecchia compagnia
    IF TG_OP = 'UPDATE' AND OLD.NomeComp != NEW.NomeComp THEN
        UPDATE COMPAGNIA
        SET NumCittaServite = (
            SELECT COUNT(DISTINCT porto)
            FROM COLLEGAMENTO,
                 UNNEST(ARRAY[NomePartenza, NomeArrivo]) AS porto
            WHERE NomeComp = OLD.NomeComp
        )
        WHERE Nome = OLD.NomeComp;
    END IF;

    -- 4. Ritorno corretto
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS aggiorno_NumCittaServite ON Collegamento;

CREATE TRIGGER aggiorno_NumCittaServite
AFTER INSERT OR UPDATE OR DELETE ON Collegamento
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
--  CONTROLLO anche se la compagnia è ancora nel DB
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
--   impedire che la data di acquisto di una barca sia successiva alla data di produzione di produzione
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

    -- Controlliamo che la data di acquisto non sia precedente all'anno di produzione
    IF EXISTS (
        SELECT * FROM IMBARCAZIONE I
        WHERE I.CodiceRegistrazione = NEW.CodiceRegistrazione
        AND NEW.DataInizio < make_date(I.AnnoCostruzione, 1, 1)
    ) THEN
        RAISE EXCEPTION 'Errore: La data di acquisto della barca è precedente alla data di produzione ';
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
            C.Num <> NEW.Num
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
