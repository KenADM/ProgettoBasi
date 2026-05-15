--- Test per il Trigger 1: Verifica che l'ora di arrivo sia sempre successiva all'ora di partenza nei collegamenti.
CREATE OR REPLACE FUNCTION test_trigger_1_orari()
RETURNS BOOLEAN AS $$
DECLARE
    test_superato BOOLEAN := TRUE;
BEGIN

    -- SETUP DATI DI BASE
    INSERT INTO COMPAGNIA VALUES ('CompagniaProva1', 'Mario Rossi', 999.00, 0);
    INSERT INTO IMBARCAZIONE VALUES ('NAV-1', 2001, 24000, 'T');
    INSERT INTO CITTA VALUES ('A', 'AA', 'NA', 960000, 0), ('B', 'BB', 'PA', 630000, 0);
    INSERT INTO PROPRIETA VALUES ('CompagniaProva1', 'NAV-1', '2004-03-23');

    -- TEST POSITIVO: Arrivo > Partenza
    BEGIN
        INSERT INTO COLLEGAMENTO (Num, Codice, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) 
        VALUES (1, '13', 'A', '16:30:00', 'B', '21:45:00', 'CompagniaProva1', 'NAV-1');
        RAISE NOTICE 'Trigger 1 - Test Positivo: OK';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 1 - Test Positivo FALLITO: %', SQLERRM;
        test_superato := FALSE;
    END;

    -- TEST NEGATIVO: Arrivo < Partenza (Deve dare errore)
    BEGIN
        INSERT INTO COLLEGAMENTO (Num, Codice, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) 
        VALUES (2, '14', 'A', '16:30:00', 'B', '15:00:00', 'CompagniaProva1', 'NAV-1');
        
        RAISE NOTICE 'Trigger 1 - Test Negativo FALLITO (Il trigger non ha bloccato)';
        test_superato := FALSE;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 1 - Test Negativo SUPERATO (Errore intercettato: %)', SQLERRM;
    END;

    -- PULIZIA DATI
    DELETE FROM COLLEGAMENTO WHERE Num = 1 AND Codice = '13' AND NomePartenza = 'A' AND NomeArrivo = 'B' AND CodiceRegistrazione = 'NAV-1';
    DELETE FROM PROPRIETA WHERE NomeComp = 'CompagniaProva1' AND CodiceRegistrazione = 'NAV-1' AND DataInizio = '2004-03-23';
    DELETE FROM CITTA WHERE Nome IN ('A', 'B');
    DELETE FROM IMBARCAZIONE WHERE CodiceRegistrazione = 'NAV-1';
    DELETE FROM COMPAGNIA WHERE Nome = 'CompagniaProva1';

    RETURN test_superato;
END; $$ LANGUAGE plpgsql;



--- Test per il Trigger 3: Verifica che una barca non possa essere acquistata da due compagnie diverse nello stesso giorno.
CREATE OR REPLACE FUNCTION test_trigger_3_proprieta()
RETURNS BOOLEAN AS $$
DECLARE
    test_superato BOOLEAN := TRUE;
BEGIN

    -- SETUP
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

    -- PULIZIA DATI
    DELETE FROM PROPRIETA WHERE NomeComp = 'CompagniaProva2' AND CodiceRegistrazione = 'NAV-3' AND DataInizio = '2004-03-23';
    DELETE FROM IMBARCAZIONE WHERE CodiceRegistrazione = 'NAV-3';
    DELETE FROM COMPAGNIA WHERE Nome IN ('CompagniaProva2', 'CompagniaProva3');

    RETURN test_superato;
END; $$ LANGUAGE plpgsql;

--- Test per il Trigger 4: Verifica che la stessa barca non possa essere utilizzata in collegamenti contemporanei.
CREATE OR REPLACE FUNCTION test_trigger_4_collegamenti()
RETURNS BOOLEAN AS $$
DECLARE
    test_superato BOOLEAN := TRUE;
BEGIN

    -- SETUP
    INSERT INTO COMPAGNIA VALUES ('CompagniaProva', 'Mario Rossi', 999.00, 0);
    INSERT INTO IMBARCAZIONE VALUES ('NAV-3', 2001, 24000, 'T');
    INSERT INTO PROPRIETA VALUES ('CompagniaProva', 'NAV-3', '2004-03-23');
    INSERT INTO CITTA VALUES ('A', 'AA', 'NA', 960000, 0), ('B', 'BB', 'PA', 630000, 0);

    -- TEST POSITIVO: Prima assegnazione
    BEGIN
        INSERT INTO COLLEGAMENTO VALUES (1, '15', 'A', '16:30:00', 'B', '21:45:00', 'CompagniaProva', 'NAV-3');
        RAISE NOTICE 'Trigger 4 - Test Positivo: OK';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 4 - Test Positivo FALLITO: %', SQLERRM;
        test_superato := FALSE;
    END;

    -- TEST NEGATIVO: Seconda assegnazione (Se vietata, deve dare errore)

    -- TEST UNO: nuovo collegamento inizia mentre la barca è utilizzata
    BEGIN
        INSERT INTO COLLEGAMENTO VALUES (2, '16', 'A', '17:00:00', 'B', '22:00:00', 'CompagniaProva', 'NAV-3');
        RAISE NOTICE 'Trigger 4 - Test Negativo FALLITO (Il trigger non ha bloccato)';
        test_superato := FALSE;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 4 - Test Negativo SUPERATO (Errore intercettato: %)', SQLERRM;
    END;
    -- TEST DUE: nuovo collegamento usa la barca, ma in mezzo è utilizzata da un altro collegamento
    BEGIN
        INSERT INTO COLLEGAMENTO VALUES (3, '17', 'A', '15:00:00', 'B', '23:00:00', 'CompagniaProva', 'NAV-3');
        RAISE NOTICE 'Trigger 4 - Test Negativo FALLITO (Il trigger non ha bloccato)';
        test_superato := FALSE;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 4 - Test Negativo SUPERATO (Errore intercettato: %)', SQLERRM;
    END;
    -- TEST TRE: nuovo collegamento usa barca ,ma prima di tornare è utilizzata da un altro collegamento
    BEGIN
        INSERT INTO COLLEGAMENTO VALUES (4, '18', 'A', '16:00:00', 'B', '18:00:00', 'CompagniaProva', 'NAV-3');
        RAISE NOTICE 'Trigger 4 - Test Negativo FALLITO (Il trigger non ha bloccato)';
        test_superato := FALSE;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 4 - Test Negativo SUPERATO (Errore intercettato: %)', SQLERRM;
    END;
    -- TEST QUATTRO: nuovo collegamento inizia e termina mentre la barca è utilizzata
    BEGIN
        INSERT INTO COLLEGAMENTO VALUES (4, '18', 'A', '17:00:00', 'B', '18:00:00', 'CompagniaProva', 'NAV-3');
        RAISE NOTICE 'Trigger 4 - Test Negativo FALLITO (Il trigger non ha bloccato)';
        test_superato := FALSE;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 4 - Test Negativo SUPERATO (Errore intercettato: %)', SQLERRM;
    END;

    -- PULIZIA DATI
    DELETE FROM COLLEGAMENTO WHERE Num = 1 AND Codice = '15' AND NomePartenza = 'A' AND NomeArrivo = 'B' AND CodiceRegistrazione = 'NAV-3';
    DELETE FROM CITTA WHERE Nome IN ('A', 'B');
    DELETE FROM PROPRIETA WHERE NomeComp = 'CompagniaProva' AND CodiceRegistrazione = 'NAV-3' AND DataInizio = '2004-03-23';
    DELETE FROM IMBARCAZIONE WHERE CodiceRegistrazione = 'NAV-3';
    DELETE FROM COMPAGNIA WHERE Nome = 'CompagniaProva';

    RETURN test_superato;
END; $$ LANGUAGE plpgsql;

SELECT test_trigger_1_orari();

SELECT test_trigger_3_proprieta();

SELECT test_trigger_4_collegamenti();