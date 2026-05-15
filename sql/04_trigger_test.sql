--- Test per ridondanza NumCittaServite: Verifica che il numero di città servite da una compagnia venga aggiornato correttamente quando si inserisce o si aggiorna un collegamento.
CREATE OR REPLACE FUNCTION test_NumCittaServite()
RETURNS BOOLEAN AS $$
DECLARE
    test_superato BOOLEAN := TRUE;
    citta_contate_step1 INT; -- Variabile per il primo controllo
    citta_contate_step2 INT; -- Variabile per il secondo controllo
BEGIN

    -- 1. SETUP DEI DATI
    INSERT INTO COMPAGNIA VALUES ('CompagniaProva1', 'Mario Rossi', 999.00, 0), ('CompagniaProva2', 'Mario Rossi', 999.00, 0);
    INSERT INTO IMBARCAZIONE VALUES ('NAV-1', 2001, 24000, 'T');
    INSERT INTO IMBARCAZIONE VALUES ('NAV-2', 2001, 24000, 'T');
    INSERT INTO PROPRIETA VALUES ('CompagniaProva1', 'NAV-1', '2004-03-23'); 
    INSERT INTO PROPRIETA VALUES ('CompagniaProva1', 'NAV-2', '2004-03-23');
    INSERT INTO CITTA VALUES ('A', 'AA', 'NA', 960000, 0), ('B', 'BB', 'PA', 630000, 0), ('C', 'CC', 'CA', 450000, 0);

    -- ==========================================
    -- FASE 1: PRIMO INSERIMENTO (Tocca città A e B)
    -- ==========================================
    INSERT INTO COLLEGAMENTO VALUES (1, '15', 'A', '8:00:00', 'B', '9:00:00', 'CompagniaProva1', 'NAV-1');

    -- Leggo il valore aggiornato dal Trigger
    SELECT NumCittaServite INTO citta_contate_step1 
    FROM COMPAGNIA 
    WHERE Nome = 'CompagniaProva1';

    -- Stampo a video il risultato intermedio
    RAISE NOTICE '--- DOPO IL PRIMO COLLEGAMENTO ---';
    RAISE NOTICE 'Città attese: 2 | Città trovate: %', citta_contate_step1;
    
    IF citta_contate_step1 != 2 THEN
        test_superato := FALSE;
    END IF;


    -- ==========================================
    -- FASE 2: SECONDO INSERIMENTO (Aggiunge città C)
    -- ==========================================
    INSERT INTO COLLEGAMENTO VALUES (2, '16', 'B', '17:00:00', 'C', '22:00:00', 'CompagniaProva1', 'NAV-2');

    -- Leggo di nuovo il valore aggiornato dal Trigger
    SELECT NumCittaServite INTO citta_contate_step2 
    FROM COMPAGNIA 
    WHERE Nome = 'CompagniaProva1';

    -- Stampo a video il risultato finale
    RAISE NOTICE '--- DOPO IL SECONDO COLLEGAMENTO ---';
    RAISE NOTICE 'Città attese: 3 | Città trovate: %', citta_contate_step2;

    IF citta_contate_step2 != 3 THEN
        test_superato := FALSE;
    END IF;


    -- ==========================================
    -- ESITO FINALE
    -- ==========================================
    IF test_superato THEN
        RAISE NOTICE '>>> TEST SUPERATO CON SUCCESSO! <<<';
    ELSE
        RAISE NOTICE '>>> TEST FALLITO! Controlla la logica del trigger. <<<';
    END IF;

    -- 2. PULIZIA DATI
    DELETE FROM COMPAGNIA WHERE Nome IN ('CompagniaProva1', 'CompagniaProva2');
    DELETE FROM IMBARCAZIONE WHERE CodiceRegistrazione IN ('NAV-1', 'NAV-2');
    DELETE FROM PROPRIETA WHERE NomeComp = 'CompagniaProva1' AND CodiceRegistrazione IN ('NAV-1', 'NAV-2');
    DELETE FROM CITTA WHERE Nome IN ('A', 'B', 'C');
    
    RETURN test_superato;
END; 
$$ LANGUAGE plpgsql;

--- Test per ridondanza NumCompagnieColleganti: Verifica che il numero di compagnie colleganti per una città venga aggiornato correttamente quando si inserisce o si aggiorna un collegamento.
CREATE OR REPLACE FUNCTION test_NumCompagnieColleganti()
RETURNS BOOLEAN AS $$
DECLARE
    test_superato BOOLEAN := TRUE;
    compagnie_citta_A_step1 INT; 
    compagnie_citta_B_step2 INT; 
    compagnie_citta_A_step3 INT; 
BEGIN

    -- 1. SETUP DEI DATI
    -- Creiamo due compagnie diverse
    INSERT INTO COMPAGNIA VALUES ('CompagniaProva1', 'Mario Rossi', 999.00, 0), ('CompagniaProva2', 'Luigi Verdi', 999.00, 0);
    
    -- Creiamo due barche e assegniamole alle due compagnie
    INSERT INTO IMBARCAZIONE VALUES ('NAV-1', 2001, 24000, 'T'), ('NAV-2', 2001, 24000, 'T');
    INSERT INTO PROPRIETA VALUES ('CompagniaProva1', 'NAV-1', '2004-03-23'), ('CompagniaProva2', 'NAV-2', '2004-03-23');
    
    -- Creiamo tre città (l'ultimo parametro a 0 è NumCompagnieColleganti)
    INSERT INTO CITTA VALUES ('A', 'AA', 'NA', 960000, 0), ('B', 'BB', 'PA', 630000, 0), ('C', 'CC', 'CA', 450000, 0);

    -- ==========================================
    -- FASE 1: La Compagnia 1 collega A e B
    -- ==========================================
    INSERT INTO COLLEGAMENTO VALUES (1, '15', 'A', '8:00:00', 'B', '9:00:00', 'CompagniaProva1', 'NAV-1');

    -- Verifichiamo la Città A
    SELECT NumCompagnieColleganti INTO compagnie_citta_A_step1 
    FROM CITTA WHERE Nome = 'A';

    RAISE NOTICE '--- FASE 1: Inserita Compagnia 1 su A-B ---';
    RAISE NOTICE 'Compagnie in Città A -> Attese: 1 | Trovate: %', compagnie_citta_A_step1;
    IF compagnie_citta_A_step1 != 1 THEN test_superato := FALSE; END IF;


    -- ==========================================
    -- FASE 2: La Compagnia 2 collega B e C
    -- ==========================================
    INSERT INTO COLLEGAMENTO VALUES (2, '16', 'B', '17:00:00', 'C', '22:00:00', 'CompagniaProva2', 'NAV-2');

    -- Verifichiamo la Città B (dovrebbe avere sia Compagnia 1 che Compagnia 2)
    SELECT NumCompagnieColleganti INTO compagnie_citta_B_step2 
    FROM CITTA WHERE Nome = 'B';

    RAISE NOTICE '--- FASE 2: Inserita Compagnia 2 su B-C ---';
    RAISE NOTICE 'Compagnie in Città B -> Attese: 2 | Trovate: %', compagnie_citta_B_step2;
    IF compagnie_citta_B_step2 != 2 THEN test_superato := FALSE; END IF;


    -- ==========================================
    -- FASE 3: Test duplicati! La Compagnia 1 crea una nuova tratta da A a C
    -- ==========================================
    INSERT INTO COLLEGAMENTO VALUES (3, '17', 'A', '12:00:00', 'C', '15:00:00', 'CompagniaProva1', 'NAV-1');

    -- Verifichiamo la Città A (dovrebbe restare 1, il trigger non deve contare due volte la CompagniaProva1)
    SELECT NumCompagnieColleganti INTO compagnie_citta_A_step3 
    FROM CITTA WHERE Nome = 'A';

    RAISE NOTICE '--- FASE 3: Compagnia 1 aggiunge un nuovo viaggio per A-C ---';
    RAISE NOTICE 'Compagnie in Città A -> Attese: 1 (Test DISTINCT) | Trovate: %', compagnie_citta_A_step3;
    IF compagnie_citta_A_step3 != 1 THEN test_superato := FALSE; END IF;


    -- ==========================================
    -- ESITO FINALE
    -- ==========================================
    IF test_superato THEN
        RAISE NOTICE '>>> TEST SUPERATO CON SUCCESSO! Il conteggio delle compagnie funziona perfettamente. <<<';
    ELSE
        RAISE NOTICE '>>> TEST FALLITO! Controlla la logica del trigger. <<<';
    END IF;

    -- 2. PULIZIA DATI
    DELETE FROM COMPAGNIA WHERE Nome IN ('CompagniaProva1', 'CompagniaProva2');
    DELETE FROM IMBARCAZIONE WHERE CodiceRegistrazione IN ('NAV-1', 'NAV-2');
    DELETE FROM PROPRIETA WHERE CodiceRegistrazione IN ('NAV-1', 'NAV-2');
    DELETE FROM CITTA WHERE Nome IN ('A', 'B', 'C');
    
    RETURN test_superato;
END; 
$$ LANGUAGE plpgsql;

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

--- Test per il Trigger 2: Verifica che un collegamento utilizzi una barca che appartiene alla compagnia che offre il collegamento.
CREATE OR REPLACE FUNCTION test_trigger_2_collegamento()
RETURNS BOOLEAN AS $$
DECLARE
    test_superato BOOLEAN := TRUE;
BEGIN

    -- SETUP
    INSERT INTO COMPAGNIA VALUES ('CompagniaProva1', 'Mario Rossi', 999.00, 0), ('CompagniaProva2', 'Mario Rossi', 999.00, 0);
    INSERT INTO IMBARCAZIONE VALUES ('NAV-3', 2001, 24000, 'T');
    INSERT INTO IMBARCAZIONE VALUES ('NAV-4', 2001, 24000, 'T');
    INSERT INTO PROPRIETA VALUES ('CompagniaProva1', 'NAV-3', '2004-03-23'); 
    INSERT INTO PROPRIETA VALUES ('CompagniaProva2', 'NAV-3', '2004-02-23');
    INSERT INTO CITTA VALUES ('A', 'AA', 'NA', 960000, 0), ('B', 'BB', 'PA', 630000, 0);


    -- TEST POSITIVO: Prima assegnazione
    BEGIN
        INSERT INTO COLLEGAMENTO VALUES (1, '15', 'A', '8:00:00', 'B', '9:00:00', 'CompagniaProva1', 'NAV-3');
        RAISE NOTICE 'Trigger 2 - Test Positivo: OK';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 2 - Test Positivo FALLITO: %', SQLERRM;
        test_superato := FALSE;
    END;

    -- TEST NEGATIVO: Seconda assegnazione (Se vietata, deve dare errore)
    -- TEST UNO: la barca che voglio assegnare al collegamento non è di proprietà della compagnia che offre il collegamento
    BEGIN
        INSERT INTO COLLEGAMENTO VALUES (2, '16', 'A', '17:00:00', 'B', '22:00:00', 'CompagniaProva2', 'NAV-3');        
        RAISE NOTICE 'Trigger 2 - Test Negativo FALLITO (Il trigger non ha bloccato)';
        test_superato := FALSE;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 2  - Test Negativo SUPERATO (Errore intercettato: %)', SQLERRM;
    END;
    
    -- TEST DUE: la barca che voglio assegnare al collegamento non è di proprieta di nessuno
    BEGIN
        INSERT INTO COLLEGAMENTO VALUES (2, '16', 'A', '17:00:00', 'B', '22:00:00', 'CompagniaProva2', 'NAV-4');        
        RAISE NOTICE 'Trigger 2 - Test Negativo FALLITO (Il trigger non ha bloccato)';
        test_superato := FALSE;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Trigger 2  - Test Negativo SUPERATO (Errore intercettato: %)', SQLERRM;
    END;

    -- PULIZIA DATI
    DELETE FROM COLLEGAMENTO WHERE Num = 1 AND Codice = '15' AND NomePartenza = 'A' AND NomeArrivo = 'B' AND CodiceRegistrazione = 'NAV-3';
    DELETE FROM COLLEGAMENTO WHERE Num = 2 AND Codice = '16' AND NomePartenza = 'A' AND NomeArrivo = 'B' AND CodiceRegistrazione = 'NAV-3';
    DELETE FROM PROPRIETA WHERE NomeComp = 'CompagniaProva1' AND CodiceRegistrazione = 'NAV-3' AND DataInizio = '2004-03-23';
    DELETE FROM PROPRIETA WHERE NomeComp = 'CompagniaProva2' AND CodiceRegistrazione = 'NAV-3' AND DataInizio = '2004-02-23';
    DELETE FROM IMBARCAZIONE WHERE CodiceRegistrazione = 'NAV-3';
    DELETE FROM COMPAGNIA WHERE Nome IN ('CompagniaProva1', 'CompagniaProva2');
    DELETE FROM CITTA WHERE Nome IN ('A', 'B');
    
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

SELECT test_NumCittaServite();

SeLECT test_NumCompagnieColleganti();

SELECT test_trigger_1_orari();

SELECT test_trigger_2_collegamento();

SELECT test_trigger_3_proprieta();

SELECT test_trigger_4_collegamenti();