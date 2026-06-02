import random
import os
from datetime import datetime, timedelta

# Quantità richieste dalla Tavola dei Volumi
NUM_COMPAGNIA = 20
NUM_IMBARCAZIONE = 450
NUM_CITTA = 100
NUM_COLLEGAMENTO = 5000
NUM_PROPRIETA = 700
NUM_CODICE_REGISTRAZIONE = 9999

index_barche = 0
IN_DOCKER = os.path.exists('/data')

PATH_COMPAGNIE = '/data/compagnie.txt' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../data/compagnie.txt')
PATH_CITTA = '/data/citta.txt' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../data/citta.txt')
PATH_BARCHE = '/data/barche.txt' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../data/barche.txt')
PATH_OUTPUT = '/output/02_dati.sql' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../sql/02_dati.sql')

def cambia_nome_tipo(T):
    match T:
        case 'T': return "traghetto"
        case 'C': return "cargo"
        case 'A': return "aliscafi"
        case 'K': return "catamarani"
        case 'M': return "motonavi"
        case _: return "altro"

def genera_codice_registrazione():
    global NUM_CODICE_REGISTRAZIONE
    NUM_CODICE_REGISTRAZIONE += 1
    return str(NUM_CODICE_REGISTRAZIONE)

def carica_citta_da_file(path):
    citta_list = []
    try:
        with open(path, 'r', encoding='utf-8') as f:
            for linea in f:
                if linea.strip():
                    parti = linea.strip().split(',')
                    citta_list.append({
                        'nome': parti[0].strip(),
                        'regione': parti[1].strip(),
                        'provincia': parti[2].strip(),
                        'abitanti': int(parti[3].strip())
                    })
        return citta_list
    except:
        return [{'nome': 'Napoli', 'regione': 'Campania', 'provincia': 'NA', 'abitanti': 960000}]

def carica_compagnie_da_file(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return [{'nome': l.split(',')[0].strip(), 'amministratore': l.split(',')[1].strip(), 'capitale': float(l.split(',')[2].strip())} for l in f if l.strip()]
    except: return []

def carica_imbarcazioni_da_file(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return [{'nome': l.split(',')[0].strip(), 'anno': l.split(',')[1].strip(), 'peso': l.split(',')[2].strip(), 'tipo': l.split(',')[3].strip()} for l in f if l.strip()]
    except: return []

def prepara_liste_base():
    l_comp, l_cit, l_imb = carica_compagnie_da_file(PATH_COMPAGNIE)[:NUM_COMPAGNIA], carica_citta_da_file(PATH_CITTA)[:NUM_CITTA], carica_imbarcazioni_da_file(PATH_BARCHE)[:NUM_IMBARCAZIONE]
    if not l_comp: l_comp = [{'nome': f"Compagnia-{i}", 'amministratore': 'Admin', 'capitale': 5000000.0} for i in range(1, NUM_COMPAGNIA+1)]
    if not l_imb: l_imb = [{'nome': f"Nave-{i}", 'anno': 2010, 'peso': 5000, 'tipo': 'T'} for i in range(1, NUM_IMBARCAZIONE+1)]
    return l_comp, l_cit, l_imb

def genera_sql_compagnia(lista):
    sql = ["-- POPOLAMENTO COMPAGNIA\nINSERT INTO COMPAGNIA (Nome, Amministratore, Capitale, NumCittaServite) VALUES"]
    nomi, vals = [], []
    for i in range(NUM_COMPAGNIA):
        info = lista[i % len(lista)]
        nome = info['nome'].replace("'", "''")
        nomi.append(nome)
        vals.append(f"('{nome}', '{info['amministratore'].replace(chr(39), chr(39)*2)}', {info['capitale']:.2f}, 0)")
    sql.append(",\n".join(vals) + ";\n")
    return sql, nomi

def genera_sql_imbarcazione(lista):
    sql = ["-- POPOLAMENTO IMBARCAZIONE\nINSERT INTO IMBARCAZIONE (CodiceRegistrazione, AnnoCostruzione, Peso, Tipo) VALUES"]
    imb_gen, vals = [], []
    for i in range(NUM_IMBARCAZIONE):
        info = lista[i % len(lista)]
        cod = genera_codice_registrazione()
        tipo = cambia_nome_tipo(info['tipo'].strip())
        vals.append(f"('{cod}', {info['anno']}, {info['peso']}, '{tipo}')")
        imb_gen.append({'codice': cod, 'anno': int(info['anno'])})
    sql.append(",\n".join(vals) + ";\n")
    return sql, imb_gen

def genera_sql_citta(lista):
    sql = ["-- POPOLAMENTO CITTA\nINSERT INTO CITTA (Nome, Regione, Provincia, NumAbitanti, NumCompagnieColleganti) VALUES"]
    nomi, vals = [], []
    for i in range(NUM_CITTA):
        info = lista[i % len(lista)]; nome = info['nome'].replace("'", "''")
        vals.append(f"('{nome}', '{info['regione'].replace(chr(39), chr(39)*2)}', '{info['provincia']}', {info['abitanti']}, 0)")
        nomi.append({'nome': nome, 'abitanti': info['abitanti']})
    sql.append(",\n".join(vals) + ";\n")
    return sql, nomi

def genera_sql_proprieta(compagnie, imbarcazioni):
    sql = ["-- POPOLAMENTO PROPRIETA\nINSERT INTO PROPRIETA (NomeComp, CodiceRegistrazione, DataInizio) VALUES"]
    prop_unici, vals, lista_p = set(), [], []
    # Assicuriamo che le prime due compagnie (speciali) abbiano barche
    for i in range(NUM_IMBARCAZIONE):
        c, b = compagnie[i % len(compagnie)], imbarcazioni[i]
        data = f"{max(1995, b['anno'])}-01-01"
        if (c, b['codice'], data) not in prop_unici:
            prop_unici.add((c, b['codice'], data))
            vals.append(f"('{c}', '{b['codice']}', '{data}')")
            lista_p.append({'codice': b['codice'], 'compagnia': c, 'data': data})
    while len(vals) < NUM_PROPRIETA:
        c, b = random.choice(compagnie), random.choice(imbarcazioni)
        data = f"{random.randint(2023, 2025)}-06-01"
        if (c, b['codice'], data) not in prop_unici:
            prop_unici.add((c, b['codice'], data))
            vals.append(f"('{c}', '{b['codice']}', '{data}')")
            lista_p.append({'codice': b['codice'], 'compagnia': c, 'data': data})
    sql.append(",\n".join(vals[:NUM_PROPRIETA]) + ";\n")
    return sql, lista_p

def genera_sql_collegamento(citta_info, imbarcazioni, proprieta, nomi_comp):
    sql = ["-- POPOLAMENTO COLLEGAMENTO"]
    # Mappe per Triggers
    barca_to_comp = {p['codice']: p['compagnia'] for p in proprieta}
    barca_libera = {b['codice']: datetime.strptime("00:00:00", "%H:%M:%S") for b in imbarcazioni}
    
    nomi_citta_tutte = [c['nome'] for c in citta_info]
    nomi_citta_piccole = [c['nome'] for c in citta_info if c['abitanti'] < 70000]
    
    count = 0
    # 1. PILOTAGGIO QUERY 4: Prima compagnia = 2 collegamenti totali
    c_rara = nomi_comp[0]
    b_rara = next(cod for cod, comp in barca_to_comp.items() if comp == c_rara)
    for _ in range(2):
        p, a = random.sample(nomi_citta_tutte, 2)
        ora_p = barca_libera[b_rara] + timedelta(minutes=30)
        ora_a = ora_p + timedelta(hours=1)
        sql.append(f"INSERT INTO COLLEGAMENTO (Num, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) VALUES ({count+1}, '{p}', '{ora_p.time()}', '{a}', '{ora_a.time()}', '{c_rara}', '{b_rara}');")
        barca_libera[b_rara] = ora_a
        count += 1

    # 2. PILOTAGGIO QUERY 3: Seconda compagnia = SOLO città piccole
    c_piccola = nomi_comp[1]
    b_piccola = next(cod for cod, comp in barca_to_comp.items() if comp == c_piccola)
    for _ in range(5): # Facciamo 5 collegamenti tutti "piccoli"
        p, a = random.sample(nomi_citta_piccole, 2)
        ora_p = barca_libera[b_piccola] + timedelta(minutes=30)
        ora_a = ora_p + timedelta(hours=1)
        sql.append(f"INSERT INTO COLLEGAMENTO (Num, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) VALUES ({count+1}, '{p}', '{ora_p.time()}', '{a}', '{ora_a.time()}', '{c_piccola}', '{b_piccola}');")
        barca_libera[b_piccola] = ora_a
        count += 1

    # 3. GENERAZIONE RESTANTE (4993 record)
    # Escludiamo comp[0] e comp[1] per non rompere le query
    comp_disponibili = nomi_comp[2:]
    # Filtriamo le barche che appartengono alle compagnie disponibili
    barche_disponibili = [b['codice'] for b in imbarcazioni if barca_to_comp.get(b['codice']) in comp_disponibili]

    while count < NUM_COLLEGAMENTO:
        cod = random.choice(barche_disponibili)
        comp = barca_to_comp[cod]
        p, a = random.sample(nomi_citta_tutte, 2)
        
        ora_p = barca_libera[cod] + timedelta(minutes=random.randint(15, 60))
        if ora_p.hour >= 23:
            barca_libera[cod] = datetime.strptime("00:00:00", "%H:%M:%S")
            continue
        ora_a = ora_p + timedelta(minutes=random.randint(30, 90))
        
        sql.append(f"INSERT INTO COLLEGAMENTO (Num, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) VALUES ({count+1}, '{p}', '{ora_p.time()}', '{a}', '{ora_a.time()}', '{comp}', '{cod}');")
        barca_libera[cod] = ora_a
        count += 1
        
    return sql

def genera_tutto():
    l_comp, l_cit, l_imb = prepara_liste_base()
    sql_final = ["-- GENERAZIONE POSTGRESQL", "SET session_replication_role = 'replica';"]
    
    res_c, n_comp = genera_sql_compagnia(l_comp); sql_final.extend(res_c)
    res_i, n_imb = genera_sql_imbarcazione(l_imb); sql_final.extend(res_i)
    res_ct, info_cit = genera_sql_citta(l_cit); sql_final.extend(res_ct)
    res_p, l_prop = genera_sql_proprieta(n_comp, n_imb); sql_final.extend(res_p)
    sql_final.extend(genera_sql_collegamento(info_cit, n_imb, l_prop, n_comp))
    
    sql_final.append("SET session_replication_role = 'origin';")
    os.makedirs(os.path.dirname(PATH_OUTPUT), exist_ok=True)
    with open(PATH_OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(sql_final))
    print(f"File creato: {PATH_OUTPUT}")

if __name__ == "__main__":
    genera_tutto()