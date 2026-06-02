--1. Coppie di imbarcazioni appartenute a esattamente le stesse compagnie
SELECT DISTINCT P1.CodiceRegistrazione, P2.CodiceRegistrazione
FROM PROPRIETA P1, PROPRIETA P2
WHERE P1.CodiceRegistrazione < P2.CodiceRegistrazione -- per avere registrazioni diverse ed evitare di esaminare le coppie di acquisto due volte
AND NOT EXISTS ( 
    SELECT NomeComp FROM PROPRIETA PA WHERE PA.CodiceRegistrazione = P1.CodiceRegistrazione -- Compagnie che avevano P1 ...
    EXCEPT 
    SELECT NomeComp FROM PROPRIETA PB WHERE PB.CodiceRegistrazione = P2.CodiceRegistrazione -- ... tranne le Compagnie che avevano P2
)
AND NOT EXISTS ( 
    SELECT NomeComp FROM PROPRIETA PB WHERE PB.CodiceRegistrazione = P2.CodiceRegistrazione -- Compagnie che avevano P2 ...
    EXCEPT
    SELECT NomeComp FROM PROPRIETA PA WHERE PA.CodiceRegistrazione = P1.CodiceRegistrazione -- ... tranne le Compagnie che avevano P1
);

--2. Per ogni tipo, l imbarcazione che vede il maggior numero di città distinte
SELECT I.Tipo, I.CodiceRegistrazione, COUNT(DISTINCT CittaToccata.NomeCitta) AS Totale
FROM IMBARCAZIONE I
JOIN (
    SELECT CodiceRegistrazione, NomePartenza AS NomeCitta FROM COLLEGAMENTO
    UNION
    SELECT CodiceRegistrazione, NomeArrivo AS NomeCitta FROM COLLEGAMENTO
) CittaToccata ON I.CodiceRegistrazione = CittaToccata.CodiceRegistrazione
GROUP BY I.Tipo, I.CodiceRegistrazione
HAVING COUNT(DISTINCT CittaToccata.NomeCitta) = (
    SELECT MAX(Conteggio.Tot)
    FROM (
        SELECT I2.Tipo, COUNT(DISTINCT CT2.NomeCitta) AS Tot
        FROM IMBARCAZIONE I2
        JOIN (
            SELECT CodiceRegistrazione, NomePartenza AS NomeCitta FROM COLLEGAMENTO
            UNION
            SELECT CodiceRegistrazione, NomeArrivo AS NomeCitta FROM COLLEGAMENTO
        ) CT2 ON I2.CodiceRegistrazione = CT2.CodiceRegistrazione
        GROUP BY I2.Tipo, I2.CodiceRegistrazione
    ) Conteggio
    WHERE Conteggio.Tipo = I.Tipo
); 

--3. Compagnie collegate SOLO con città < 70000 abitanti 
SELECT DISTINCT NomeComp 
FROM COLLEGAMENTO
EXCEPT 
SELECT DISTINCT C.NomeComp 
FROM COLLEGAMENTO C 
JOIN CITTA Ci ON C.NomePartenza = Ci.Nome OR C.NomeArrivo = Ci.Nome 
WHERE Ci.NumAbitanti >= 70000;

--4. Compagnie con AL PIÙ due collegamenti (Tipo A e Lombardia) 
SELECT Nome 
FROM COMPAGNIA 
WHERE (
    SELECT COUNT(*) 
    FROM COLLEGAMENTO Co 
    WHERE Co.NomeComp = COMPAGNIA.Nome
) <= 2;

--5. Coppie di imbarcazioni che partono dallo stesso posto ma arrivano in posti diversi
SELECT DISTINCT C1.CodiceRegistrazione, C2.CodiceRegistrazione
FROM COLLEGAMENTO C1, COLLEGAMENTO C2
WHERE C1.CodiceRegistrazione < C2.CodiceRegistrazione
AND C1.NomePartenza = C2.NomePartenza
AND C1.NomeArrivo <> C2.NomeArrivo;