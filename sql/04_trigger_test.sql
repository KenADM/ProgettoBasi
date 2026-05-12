-- test trigger 1
-- 1. CREIAMO I DATI DI BASE (I "Mattoni")
INSERT INTO COMPAGNIA (Nome, Amministratore, Capitale, NumCittaServite) VALUES
('CompagniaProva1', 'Mario Rossi', 999.00, 0);

INSERT INTO IMBARCAZIONE (CodiceRegistrazione, AnnoCostruzione, Peso, Tipo) VALUES
('NAV-1', 2001, 24000, 'T');

INSERT INTO CITTA (Nome, Regione, Provincia, NumAbitanti, NumCompagnieColleganti) VALUES
('A', 'AA', 'NA', 960000, 0),
('B', 'BB', 'PA', 630000, 0);

INSERT INTO PROPRIETA (NomeComp, CodiceRegistrazione, DataInizio) VALUES
('CompagniaProva1', 'NAV-1', '2004-03-23');

-- TEST POSITIVO: Arrivo (21:45) > Partenza (16:30)
-- Risultato atteso: Query eseguita con successo. Il dato entra nel DB.
INSERT INTO COLLEGAMENTO (Num, Codice, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) VALUES
(1, '13', 'A', '1900-01-01 16:30:00', 'B', '1900-01-01 21:45:00', 'CompagniaProva1', 'NAV-1');

SELECT * FROM COLLEGAMENTO WHERE Num=1; 

-- TEST NEGATIVO: Arrivo (15:00) è MINORE della Partenza (16:30)
-- Risultato atteso: ERRORE ROSSO! Il trigger deve scattare e bloccare tutto.
--INSERT INTO COLLEGAMENTO (Num, Codice, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) VALUES
--(2, '14', 'A', '1900-01-01 16:30:00', 'B', '1900-01-01 15:00:00', 'CompagniaProva1', 'NAV-1');

SELECT * FROM COLLEGAMENTO WHERE Num=2;



-- test trigger 3
INSERT INTO COMPAGNIA (Nome, Amministratore, Capitale, NumCittaServite) VALUES
('CompagniaProva2', 'Mario Rossi', 999.00, 0);

INSERT INTO IMBARCAZIONE (CodiceRegistrazione, AnnoCostruzione, Peso, Tipo) VALUES
('NAV-3', 2001, 24000, 'T');

INSERT INTO PROPRIETA (NomeComp, CodiceRegistrazione, DataInizio) VALUES
('CompagniaProva1', 'NAV-3', '2004-03-23');

INSERT INTO PROPRIETA (NomeComp, CodiceRegistrazione, DataInizio) VALUES
('CompagniaProva2', 'NAV-3', '2004-03-23');
