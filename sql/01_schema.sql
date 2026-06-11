CREATE TABLE COMPAGNIA (
    Nome VARCHAR(50) PRIMARY KEY,
    Amministratore VARCHAR(50) NOT NULL,
    Capitale DECIMAL(15, 2) DEFAULT 0 CHECK (Capitale >= 0),
    NumCittaServite INT DEFAULT 0 
);

CREATE TABLE IMBARCAZIONE (
    CodiceRegistrazione VARCHAR(10) PRIMARY KEY,
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
    Num INT NOT NULL, 
    NomePartenza VARCHAR(50),
    OraPartenza TIME, 
    NomeArrivo VARCHAR(50), 
    OraArrivo TIME CHECK (OraArrivo > OraPartenza), 
    NomeComp VARCHAR(50), 
    CodiceRegistrazione CHAR(10), 
    PRIMARY KEY (Num, NomePartenza, NomeArrivo, CodiceRegistrazione),
    FOREIGN KEY (NomePartenza) REFERENCES CITTA(Nome) ON UPDATE CASCADE,
    FOREIGN KEY (NomeArrivo) REFERENCES CITTA(Nome) ON UPDATE CASCADE,
    FOREIGN KEY (NomeComp) REFERENCES COMPAGNIA(Nome) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (CodiceRegistrazione) REFERENCES IMBARCAZIONE(CodiceRegistrazione) ON UPDATE CASCADE ON DELETE CASCADE

);

CREATE TABLE PROPRIETA (
    NomeComp VARCHAR(50),
    CodiceRegistrazione CHAR(10),
    DataInizio DATE,
    PRIMARY KEY (NomeComp, CodiceRegistrazione, DataInizio),
    FOREIGN KEY (NomeComp) REFERENCES COMPAGNIA(Nome) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (CodiceRegistrazione) REFERENCES IMBARCAZIONE(CodiceRegistrazione) ON UPDATE CASCADE ON DELETE CASCADE
);


--TRIGGER--

-- 1 ridondanza NumCompagnieColleganti

CREATE OR REPLACE FUNCTION Aggiorno_NumCompagnieColleganti()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
    DECLARE
        citta_coinvolte VARCHAR[];
    BEGIN
        -- troviamo tutte le città coinvolte nell'operazione 
        IF TG_OP = 'INSERT' THEN
            citta_coinvolte := ARRAY[NEW.NomePartenza, NEW.NomeArrivo];
            
        ELSIF TG_OP = 'DELETE' THEN
            citta_coinvolte := ARRAY[OLD.NomePartenza, OLD.NomeArrivo];
            
        ELSIF TG_OP = 'UPDATE' THEN
            citta_coinvolte := ARRAY[OLD.NomePartenza, OLD.NomeArrivo, NEW.NomePartenza, NEW.NomeArrivo];
        END IF;

        -- Aggiorniamo tutte le città coinvolte
        UPDATE CITTA
        SET NumCompagnieColleganti = (
            SELECT COUNT(DISTINCT NomeComp)
            FROM COLLEGAMENTO
            WHERE NomePartenza = CITTA.Nome OR NomeArrivo = CITTA.Nome
        )
        WHERE Nome = ANY(citta_coinvolte);

        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        ELSE
            RETURN NEW;
        END IF;
    END;
$$;


CREATE TRIGGER Aggiorno_NumCompagnieColleganti
AFTER INSERT OR UPDATE OR DELETE ON Collegamento
FOR EACH ROW 
EXECUTE FUNCTION Aggiorno_NumCompagnieColleganti();

-- 2 ridondanza NumCittaServite 
CREATE OR REPLACE FUNCTION Aggiorno_NumCittaServite()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
    DECLARE
        compagnie_coinvolte VARCHAR[];
    BEGIN
        -- troviamo tutte le compagnie coinvolte nell'operazione
        IF TG_OP = 'INSERT' THEN
            compagnie_coinvolte := ARRAY[NEW.NomeComp];
        ELSIF TG_OP = 'DELETE' THEN
            compagnie_coinvolte := ARRAY[OLD.NomeComp];
        ELSIF TG_OP = 'UPDATE' THEN
            -- Includiamo sia la vecchia che la nuova (se uguali, l'UPDATE agirà una volta sola)
            compagnie_coinvolte := ARRAY[OLD.NomeComp, NEW.NomeComp];
        END IF;

        -- Aggiorniamo tutte le compagnie coinvolte
        UPDATE COMPAGNIA
        SET NumCittaServite = (
            SELECT COUNT(DISTINCT porto)
            FROM COLLEGAMENTO, UNNEST(ARRAY[NomePartenza, NomeArrivo]) AS porto
            WHERE NomeComp = COMPAGNIA.Nome 
        )
        WHERE Nome = ANY(compagnie_coinvolte);


        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        ELSE
            RETURN NEW;
        END IF;
    END;
$$;

CREATE TRIGGER Aggiorno_NumCittaServite
AFTER INSERT OR UPDATE OR DELETE ON Collegamento
FOR EACH ROW
EXECUTE FUNCTION Aggiorno_NumCittaServite();

-- 3 COLLEGAMENTO deve usare una barca che appartiene alla compagnia che offre il COLLEGAMENTO attualmente

CREATE OR REPLACE FUNCTION Controlla_validazione_barca_collegamento()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
    DECLARE
        ValidProprietario RECORD;
    BEGIN

        -- controllo che la barca abbia un proprietario
        SELECT * INTO ValidProprietario 
        FROM Proprieta P
        WHERE NEW.CodiceRegistrazione = P.CodiceRegistrazione 
        AND P.DataInizio <= CURRENT_DATE -- Il proprietario deve essere attivo
        ORDER BY P.DataInizio DESC
        LIMIT 1; -- una barca può avere più proprietari nel tempo, ma solo una attuale (quella con la data di inizio più recente)

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Errore: La barca % non risulta registrata a nessuna compagnia.', NEW.CodiceRegistrazione;
        END IF;

        -- controllo che il collegamento sia offerto dal proprietario della barca
        IF ValidProprietario.NomeComp != NEW.NomeComp THEN
            RAISE EXCEPTION 'Errore: La barca % non appartiene alla compagnia %.', NEW.CodiceRegistrazione, NEW.NomeComp;
        END IF;

        RETURN NEW;
    END;
$$ ;

CREATE TRIGGER Controlla_validazione_barca_collegamento
BEFORE INSERT OR UPDATE ON Collegamento
FOR EACH ROW
EXECUTE FUNCTION Controlla_validazione_barca_collegamento();

-- 4 impedire che due compagnie diverse abbiano acquistato la stessa barca nello stesso momento
--   impedire che la data di acquisto di una barca sia successiva alla data di produzione di produzione
CREATE OR REPLACE FUNCTION Controlla_data_acquisto_barca() 
RETURNS TRIGGER LANGUAGE plpgsql AS $$
    DECLARE
        anno_costruzione_barca INT;
    BEGIN
        -- Cerchiamo SE ESISTE GIÀ un acquisto per la stessa barca nello stesso giorno, ma con una compagnia diversa

        IF TG_OP = 'INSERT' THEN
            PERFORM * FROM Proprieta P
            WHERE P.CodiceRegistrazione = NEW.CodiceRegistrazione 
            AND P.DataInizio = NEW.DataInizio                    
            AND P.NomeComp != NEW.NomeComp;
        ELSIF TG_OP = 'UPDATE' THEN
            PERFORM * FROM Proprieta P
            WHERE P.CodiceRegistrazione = NEW.CodiceRegistrazione 
            AND P.DataInizio = NEW.DataInizio                    
            AND P.NomeComp != NEW.NomeComp
            -- ESCLUDIAMO la riga stessa identificata dai vecchi valori
            AND NOT (P.NomeComp = OLD.NomeComp AND P.CodiceRegistrazione = OLD.CodiceRegistrazione AND P.DataInizio = OLD.DataInizio);
        END IF;
        
        IF FOUND THEN
            RAISE EXCEPTION 'Errore: La barca % è già stata acquistata da un''altra compagnia in data %.', NEW.CodiceRegistrazione, NEW.DataInizio;
        END IF;

        SELECT AnnoCostruzione INTO anno_costruzione_barca 
        FROM IMBARCAZIONE 
        WHERE CodiceRegistrazione = NEW.CodiceRegistrazione;

        IF NEW.DataInizio < make_date(anno_costruzione_barca, 1, 1) THEN
            RAISE EXCEPTION 'Errore: La data di acquisto (%) non può essere precedente all''anno di costruzione (%) della barca %.', NEW.DataInizio, anno_costruzione_barca, NEW.CodiceRegistrazione;
        END IF;
        
        RETURN NEW;
    END;
$$;

CREATE TRIGGER Controlla_data_acquisto_barca
BEFORE INSERT OR UPDATE ON Proprieta
FOR EACH ROW
EXECUTE FUNCTION Controlla_data_acquisto_barca();

-- 5 stessa barca utilizzata in tratte contemporanee
CREATE OR REPLACE FUNCTION Controlla_barche_contemporanee()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
    BEGIN
        IF TG_OP = 'INSERT' THEN

            PERFORM 1 FROM Collegamento C
            WHERE C.CodiceRegistrazione = NEW.CodiceRegistrazione 
            AND C.OraPartenza < NEW.OraArrivo 
            AND C.OraArrivo > NEW.OraPartenza;

            IF FOUND THEN
                RAISE EXCEPTION 'Errore: La barca % è già assegnata a un collegamento esistente in questo orario.', NEW.CodiceRegistrazione;
            END IF;

        ELSIF TG_OP = 'UPDATE' THEN

            PERFORM 1 FROM Collegamento C
            WHERE C.CodiceRegistrazione = NEW.CodiceRegistrazione 
            -- Escludiamo la VECCHIA versione di questo specifico collegamento
            AND NOT (C.Num = OLD.Num AND C.NomePartenza = OLD.NomePartenza AND C.NomeArrivo = OLD.NomeArrivo AND C.CodiceRegistrazione = OLD.CodiceRegistrazione)
            AND C.OraPartenza < NEW.OraArrivo 
            AND C.OraArrivo > NEW.OraPartenza;

            IF FOUND THEN
                RAISE EXCEPTION 'Errore: La barca % è già assegnata a un collegamento esistente in questo orario.', NEW.CodiceRegistrazione;
            END IF;
        END IF;

        RETURN NEW;
    END;
$$;


CREATE TRIGGER Controlla_barche_contemporanee
BEFORE INSERT OR UPDATE ON Collegamento
FOR EACH ROW
EXECUTE FUNCTION Controlla_barche_contemporanee();

-- 6 Impedire l'acquisto o il trasferimento di una barca se è attiva in dei collegamenti
CREATE OR REPLACE FUNCTION Controlla_barca_libera_per_acquisto()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
    BEGIN
        -- Controlliamo se stiamo inserendo un nuovo acquisto, 
        -- oppure se stiamo modificando il proprietario (UPDATE della chiave)
        IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.NomeComp != NEW.NomeComp) THEN

            -- Andiamo a cercare se la barca è utilizzata in qualche collegamento attivo
            PERFORM 1 FROM COLLEGAMENTO C
            WHERE C.CodiceRegistrazione = NEW.CodiceRegistrazione;

            IF FOUND THEN
                RAISE EXCEPTION 'Errore: La barca % non può essere acquistata/trasferita perché è attualmente in uso in uno o più collegamenti. Rimuovere prima i collegamenti.', NEW.CodiceRegistrazione;
            END IF;
            
        END IF;

        RETURN NEW;
    END;
$$;


CREATE TRIGGER Controlla_barca_libera_per_acquisto
BEFORE INSERT OR UPDATE ON PROPRIETA
FOR EACH ROW
EXECUTE FUNCTION Controlla_barca_libera_per_acquisto();
