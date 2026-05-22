--1.	Coppie di imbarcazioni appartenute a esattamente le stesse compagnie
SELECT P1.CodiceRegistrazione, P2.CodiceRegistrazione
FROM PROPRIETA P1, PROPRIETA P2
WHERE P1.CodiceRegistrazione < P2.CodiceRegistrazione
AND NOT EXISTS (
    SELECT NomeComp FROM PROPRIETA PA WHERE PA.CodiceRegistrazione = P1.CodiceRegistrazione
    EXCEPT
    SELECT NomeComp FROM PROPRIETA PB WHERE PB.CodiceRegistrazione = P2.CodiceRegistrazione
)
AND NOT EXISTS (
    SELECT NomeComp FROM PROPRIETA PB WHERE PB.CodiceRegistrazione = P2.CodiceRegistrazione
    EXCEPT
    SELECT NomeComp FROM PROPRIETA PA WHERE PA.CodiceRegistrazione = P1.CodiceRegistrazione
);

--2. Per ogni tipo, l imbarcazione che vede il maggior numero di città distinte
SELECT I.Tipo, I.CodiceRegistrazione, COUNT(DISTINCT Citta.NomePartenza) AS Totale
FROM IMBARCAZIONE I
JOIN COLLEGAMENTO Citta ON I.CodiceRegistrazione = Citta.CodiceRegistrazione
GROUP BY I.Tipo, I.CodiceRegistrazione
HAVING COUNT(DISTINCT Citta.NomePartenza) = (
    SELECT MAX(Conteggio.Tot)
    FROM (
        SELECT I2.Tipo, COUNT(DISTINCT C2.NomePartenza) AS Tot
        FROM IMBARCAZIONE I2
        JOIN COLLEGAMENTO C2 ON I2.CodiceRegistrazione = C2.CodiceRegistrazione
        GROUP BY I2.Tipo, I2.CodiceRegistrazione
    ) Conteggio
    WHERE Conteggio.Tipo = I.Tipo
);

--3. Compagnie collegate SOLO con città < 70000 abitanti 
SELECT DISTINCT C.NomeComp 
FROM COLLEGAMENTO C 
JOIN CITTA Ci ON C.NomePartenza = Ci.Nome OR C.NomeArrivo = Ci.Nome 
WHERE Ci.NumAbitanti < 70000;

'Coppie di imbarcazioni che partono dallo stesso posto ma arrivano in posti diversi'
SELECT DISTINCT C1.CodiceRegistrazione, C2.CodiceRegistrazione
FROM COLLEGAMENTO C1, COLLEGAMENTO C2
WHERE C1.CodiceRegistrazione < C2.CodiceRegistrazione
AND C1.NomePartenza = C2.NomePartenza
AND C1.NomeArrivo <> C2.NomeArrivo;

--4. Compagnie con AL PIÙ due collegamenti (Tipo A e Lombardia)
SELECT Nome
FROM COMPAGNIA
WHERE (
    SELECT COUNT(*)
    FROM COLLEGAMENTO Co
    JOIN IMBARCAZIONE I ON Co.CodiceRegistrazione = I.CodiceRegistrazione
    JOIN CITTA Ci ON (Co.NomeArrivo = Ci.Nome OR Co.NomePartenza = Ci.Nome)
    WHERE Co.NomeComp = COMPAGNIA.Nome
    AND I.Tipo = 'A' AND Ci.Regione = 'Lombardia'
) <= 2;