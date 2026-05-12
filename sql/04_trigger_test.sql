--- Test per il Trigger 1: Verifica che l'ora di arrivo sia sempre successiva all'ora di partenza nei collegamenti.
CREATE OR REPLACE FUNCTION test_trigger_1_orari()
RETURNS BOOLEAN AS $$
DECLARE
    test_superato BOOLEAN := TRUE;
BEGIN

    -- 1. SETUP DATI DI BASE
    INSERT INTO COMPAGNIA VALUES ('CompagniaProva1', 'Mario Rossi', 999.00, 0);
    INSERT INTO IMBARCAZIONE VALUES ('NAV-1', 2001, 24000, 'T');
    INSERT INTO CITTA VALUES ('A', 'AA', 'NA', 960000, 0), ('B', 'BB', 'PA', 630000, 0);
    INSERT INTO PROPRIETA VALUES ('CompagniaProva1', 'NAV-1', '2004-03-23');

    -- TEST POSITIVO: Arrivo > Partenza
    BEGIN
        INSERT INTO COLLEGAMENTO (Num, Codice, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) 
        VALUES (1, '13', 'A', '1900-01-01 16:30:00', 'B', '1900-01-01 21:45:00', 'CompagniaProva1', 'NAV-1');
        RAISE NOTICE 'Trigger 1 - Test Positivo: OK';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 1 - Test Positivo FALLITO: %', SQLERRM;
        test_superato := FALSE;
    END;

    -- TEST NEGATIVO: Arrivo < Partenza (Deve dare errore)
    BEGIN
        INSERT INTO COLLEGAMENTO (Num, Codice, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) 
        VALUES (2, '14', 'A', '1900-01-01 16:30:00', 'B', '1900-01-01 15:00:00', 'CompagniaProva1', 'NAV-1');
        
        RAISE NOTICE 'Trigger 1 - Test Negativo FALLITO (Il trigger non ha bloccato)';
        test_superato := FALSE;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 1 - Test Negativo SUPERATO (Errore intercettato: %)', SQLERRM;
    END;

    RETURN test_superato;
END; $$ LANGUAGE plpgsql;



--- Test per il Trigger 3: Verifica che una barca non possa essere acquistata da due compagnie diverse nello stesso giorno.
CREATE OR REPLACE FUNCTION test_trigger_3_proprieta()
RETURNS BOOLEAN AS $$
DECLARE
    test_superato BOOLEAN := TRUE;
BEGIN

    -- 1. SETUP
    INSERT INTO COMPAGNIA VALUES ('CompagniaProva2', 'Mario Rossi', 999.00, 0), ('CompagniaProva3', 'Mario Rossi', 999.00, 0);
    INSERT INTO IMBARCAZIONE VALUES ('NAV-3', 2001, 24000, 'T');

    -- TEST POSITIVO: Prima assegnazione
    BEGIN
        INSERT INTO PROPRIETA VALUES ('CompagniaProva2', 'NAV-3', '2004-03-23');
        RAISE NOTICE 'Trigger 3 - Test Positivo: OK';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 3 - Test Positivo FALLITO: %', SQLERRM;
        test_superato := FALSE;
    END;

    -- TEST NEGATIVO: Seconda assegnazione (Se vietata, deve dare errore)
    BEGIN
        INSERT INTO PROPRIETA VALUES ('CompagniaProva3', 'NAV-3', '2004-03-23');
        
        RAISE NOTICE 'Trigger 3 - Test Negativo FALLITO (Il trigger non ha bloccato)';
        test_superato := FALSE;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 3 - Test Negativo SUPERATO (Errore intercettato: %)', SQLERRM;
    END;

    RETURN test_superato;
END; $$ LANGUAGE plpgsql;


-- Aggiungi queste righe in fondo al file 04_trigger_test.sql
SELECT test_trigger_1_orari();
SELECT test_trigger_3_proprieta();