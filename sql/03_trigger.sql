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

-- collegamenti deve usare una barca che appartiene alla compagnia che offre il COLLEGAMENTO

-- impedire che due compagnie diverse abbiano acquistato la stessa barca nello stesso momento

-- stessa barca utilizzata in tratte contemporanee

-- trigger relativi alle chiavi esterne