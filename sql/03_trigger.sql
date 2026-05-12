-- orario dei collegamenti, l'arrivo deve essere > della partenza
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

-- 2 Ccollegamenti deve usare una barca che appartiene alla compagnia che offre il COLLEGAMENTO


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

-- stessa barca utilizzata in tratte contemporanee
CREATE OR REPLACE FUNCTION controlla_barche_contemporanee()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- !!! DA FINIRE
    IF EXISTS (
        SELECT * FROM Collegamento C
        WHERE C.CodiceRegistrazione = NEW.CodiceRegistrazione -- Stessa barca
        AND C.DataInizio = NEW.DataInizio                     -- Stesso giorno
        AND C.NomeComp != NEW.NomeComp                        -- MA compagnia diversa!
    ) THEN
        -- Se trova un conflitto, blocca tutto
        RAISE EXCEPTION 'Errore: La barca % è già stata acquistata da un''altra compagnia in data %.', NEW.CodiceRegistrazione, NEW.DataInizio;
    END IF;

    -- Se non ci sono conflitti, diamo il via libera
    RETURN NEW;
END;
$$;

CREATE TRIGGER check_barche_contemporanee
BEFORE INSERT OR UPDATE ON Collegamento
FOR EACH ROW
EXECUTE FUNCTION controlla_barche_contemporanee();


-- trigger relativi alle chiavi esterne