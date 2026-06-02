import random
import os
from datetime import datetime, timedelta

# Quantità richieste (ridotte leggermente per densità di dati utile alle query)
NUM_COMPAGNIA = 20
NUM_IMBARCAZIONE = 100
NUM_CITTA = 50
NUM_COLLEGAMENTO = 400
NUM_PROPRIETA = 150

PATH_OUTPUT = '02_dati.sql'

def cambia_nome_tipo(T):
    tipi = {'T': "traghetto", 'C': "cargo", 'A': "aliscafi", 'K': "catamarani", 'M': "motonavi"}
    return tipi.get(T, "altro")

def genera_tutto():
    sql = ["/* ========================================================\n"
           "   DATI GENERATI PER RISPETTARE TRIGGER E QUERY (NON VUOTE)\n"
           "   ======================================================== */\n"]
    
    # 1. GENERAZIONE CITTA
    citta_piccole = []
    citta_grandi = []
    sql.append("-- POPOLAMENTO CITTA")
    for i in range(NUM_CITTA):
        nome = f"Citta_{i}"
        # SOLO 3 CITTA SOPRA I 70.000 ABITANTI
        if i < 3:
            abitanti = random.randint(75000, 500000)
            citta_grandi.append(nome)
        else:
            abitanti = random.randint(5000, 65000)
            citta_piccole.append(nome)
        
        sql.append(f"INSERT INTO CITTA (Nome, Regione, Provincia, NumAbitanti) VALUES ('{nome}', 'Regione_{i%5}', 'P{i%9}', {abitanti});")

    # 2. GENERAZIONE COMPAGNIA
    compagnie = []
    sql.append("\n-- POPOLAMENTO COMPAGNIA")
    for i in range(NUM_COMPAGNIA):
        nome = f"Compagnia_{i}"
        if i == 0: nome = "SmallTown_Nav" # Per Query 3
        if i == 1: nome = "Rare_Voyages"  # Per Query 4
        compagnie.append(nome)
        sql.append(f"INSERT INTO COMPAGNIA (Nome, Amministratore, Capitale) VALUES ('{nome}', 'Admin_{i}', {random.randint(100000, 5000000)});")

    # 3. GENERAZIONE IMBARCAZIONE
    barche = []
    sql.append("\n-- POPOLAMENTO IMBARCAZIONE")
    for i in range(NUM_IMBARCAZIONE):
        codice = f"B{10000 + i}"
        tipo = cambia_nome_tipo(random.choice(['T', 'C', 'A', 'K', 'M']))
        barche.append({'codice': codice, 'tipo': tipo})
        sql.append(f"INSERT INTO IMBARCAZIONE (CodiceRegistrazione, AnnoCostruzione, Peso, Tipo) VALUES ('{codice}', 2020, 1000, '{tipo}');")

    # 4. GENERAZIONE PROPRIETA
    # Inseriamo tutte le proprietà prima dei collegamenti (Trigger 5 safe)
    sql.append("\n-- POPOLAMENTO PROPRIETA")
    owner_attuale = {}
    
    # Assegniamo barche specifiche alle compagnie target
    # Barca 0 a SmallTown_Nav, Barca 1 a Rare_Voyages
    speciali = {"SmallTown_Nav": barche[0]['codice'], "Rare_Voyages": barche[1]['codice']}
    for comp_nome, b_cod in speciali.items():
        sql.append(f"INSERT INTO PROPRIETA (NomeComp, CodiceRegistrazione, DataInizio) VALUES ('{comp_nome}', '{b_cod}', '2024-01-01');")
        owner_attuale[b_cod] = comp_nome

    # Altre barche random alle altre compagnie
    for i in range(2, NUM_IMBARCAZIONE):
        b_cod = barche[i]['codice']
        comp_nome = random.choice(compagnie[2:])
        sql.append(f"INSERT INTO PROPRIETA (NomeComp, CodiceRegistrazione, DataInizio) VALUES ('{comp_nome}', '{b_cod}', '2024-01-01');")
        owner_attuale[b_cod] = comp_nome

    # 5. GENERAZIONE COLLEGAMENTO
    sql.append("\n-- POPOLAMENTO COLLEGAMENTO")
    disponibilita = {b['codice']: datetime.strptime("06:00:00", "%H:%M:%S") for b in barche}
    num_coll = 1

    # --- QUERY 3: SmallTown_Nav (Solo città piccole) ---
    b_st = speciali["SmallTown_Nav"]
    for _ in range(5):
        p, a = random.sample(citta_piccole, 2)
        ora_p = disponibilita[b_st] + timedelta(minutes=30)
        ora_a = ora_p + timedelta(minutes=60)
        sql.append(f"INSERT INTO COLLEGAMENTO VALUES ({num_coll}, '{p}', '{ora_p.time()}', '{a}', '{ora_a.time()}', 'SmallTown_Nav', '{b_st}');")
        disponibilita[b_st] = ora_a
        num_coll += 1

    # --- QUERY 4: Rare_Voyages (Esattamente 2 collegamenti) ---
    b_rv = speciali["Rare_Voyages"]
    for _ in range(2):
        p, a = random.sample(citta_piccole + citta_grandi, 2)
        ora_p = disponibilita[b_rv] + timedelta(minutes=30)
        ora_a = ora_p + timedelta(minutes=60)
        sql.append(f"INSERT INTO COLLEGAMENTO VALUES ({num_coll}, '{p}', '{ora_p.time()}', '{a}', '{ora_a.time()}', 'Rare_Voyages', '{b_rv}');")
        disponibilita[b_rv] = ora_a
        num_coll += 1

    # --- RESTO DEI COLLEGAMENTI (Forziamo l'uso di città grandi per le altre compagnie) ---
    # Questo serve a far sì che l'EXCEPT della Query 3 lasci "SmallTown_Nav" come unica riga
    barche_normali = [b['codice'] for b in barche if b['codice'] not in speciali.values()]
    
    while num_coll <= NUM_COLLEGAMENTO:
        b_cod = random.choice(barche_normali)
        comp = owner_attuale[b_cod]
        
        # Per escludere queste compagnie dalla Query 3, devono toccare almeno una città grande
        p = random.choice(citta_grandi)
        a = random.choice(citta_piccole)
        
        ora_p = disponibilita[b_cod] + timedelta(minutes=random.randint(20, 60))
        ora_a = ora_p + timedelta(minutes=random.randint(40, 150))
        
        if ora_a.hour < 23 and ora_a.day == 1:
            sql.append(f"INSERT INTO COLLEGAMENTO VALUES ({num_coll}, '{p}', '{ora_p.time()}', '{a}', '{ora_a.time()}', '{comp}', '{b_cod}');")
            disponibilita[b_cod] = ora_a
            num_coll += 1
        else:
            # Fine giornata per questa barca
            disponibilita[b_cod] = datetime.strptime("06:00:00", "%H:%M:%S")

    # Scrittura finale
    with open(PATH_OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(sql))
    
    print(f"Generazione completata: {PATH_OUTPUT}")
    print(f"Città Grandi (>70k): {citta_grandi}")

if __name__ == "__main__":
    genera_tutto()