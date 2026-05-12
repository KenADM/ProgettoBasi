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

'Per ogni tipo, l imbarcazione che vede il maggior numero di città distinte'
WITH VistaCitta AS (
    SELECT I.Tipo, I.CodiceRegistrazione, COUNT(DISTINCT Porto) as TotCitta
    FROM IMBARCAZIONE I
    JOIN (
        SELECT CodiceRegistrazione, NomePartenza as Porto FROM COLLEGAMENTO
        UNION
        SELECT CodiceRegistrazione, NomeArrivo FROM COLLEGAMENTO
    ) AS Movimenti ON I.CodiceRegistrazione = Movimenti.CodiceRegistrazione
    GROUP BY I.Tipo, I.CodiceRegistrazione
)
SELECT Tipo, CodiceRegistrazione, TotCitta
FROM VistaCitta V1
WHERE TotCitta = (
    SELECT MAX(TotCitta) 
    FROM VistaCitta V2 
    WHERE V2.Tipo = V1.Tipo
);

'Compagnie collegate SOLO con città < 5000 abitantiSELECT Nome'
FROM COMPAGNIA
WHERE Nome NOT IN (
    SELECT DISTINCT NomeComp
    FROM COLLEGAMENTO Co
    JOIN CITTA Ci ON Co.NomePartenza = Ci.Nome OR Co.NomeArrivo = Ci.Nome
    WHERE Ci.NumAbitanti >= 5000
);

'Coppie di imbarcazioni che partono dallo stesso porto ma arrivano in posti diversi'
SELECT DISTINCT C1.CodiceRegistrazione, C2.CodiceRegistrazione
FROM COLLEGAMENTO C1, COLLEGAMENTO C2
WHERE C1.CodiceRegistrazione < C2.CodiceRegistrazione
AND C1.NomePartenza = C2.NomePartenza
AND C1.NomeArrivo <> C2.NomeArrivo;

'Compagnie con AL PIÙ due collegamenti (Tipo A e Lombardia)'
SELECT NomeComp
FROM COLLEGAMENTO Co
JOIN IMBARCAZIONE I ON Co.CodiceRegistrazione = I.CodiceRegistrazione
JOIN CITTA Ci ON Co.NomeArrivo = Ci.Nome
WHERE I.Tipo = 'A' AND Ci.Regione = 'Lombardia'
GROUP BY NomeComp
HAVING COUNT(*) <= 2;
