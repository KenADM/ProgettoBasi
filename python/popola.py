import random
import os
from datetime import datetime, timedelta

# Quantità richieste
NUM_COMPAGNIA = 20
NUM_IMBARCAZIONE = 450
NUM_CITTA = 100
NUM_COLLEGAMENTO = 5000
NUM_PROPRIETA = 700
NUM_CODICE_REGISTRAZIONE = 9999

IN_DOCKER = os.path.exists('/data')

PATH_COMPAGNIE = '/data/compagnie.txt' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../data/compagnie.txt')
PATH_CITTA = '/data/citta.txt' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../data/citta.txt')
PATH_BARCHE = '/data/barche.txt' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../data/barche.txt')
PATH_OUTPUT = '/output/02_dati.sql' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../sql/02_dati.sql')

def cambia_nome_tipo(T):
    match T:
        case 'T': return "traghetto"
        case 'C': return "cargo"
        case 'A': return "aliscafo"
        case 'K': return "catamarano"
        case 'M': return "motonave"
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
        return [{'nome': 'Milano', 'regione': 'Lombardia', 'provincia': 'MI', 'abitanti': 960000}]

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
        imb_gen.append({'codice': cod, 'tipo': tipo, 'anno': int(info['anno'])})
    sql.append(",\n".join(vals) + ";\n")
    return sql, imb_gen

def genera_sql_citta(lista):
    sql = ["-- POPOLAMENTO CITTA\nINSERT INTO CITTA (Nome, Regione, Provincia, NumAbitanti, NumCompagnieColleganti) VALUES"]
    info_citta, vals = [], []
    for info in lista:
        nome = info['nome'].replace("'", "''")
        vals.append(f"('{nome}', '{info['regione']}', '{info['provincia']}', {info['abitanti']}, 0)")
        info_citta.append(info)
    sql.append(",\n".join(vals) + ";\n")
    return sql, info_citta

def genera_sql_proprieta(compagnie, imbarcazioni):
    sql = ["-- POPOLAMENTO PROPRIETA\nINSERT INTO PROPRIETA (NomeComp, CodiceRegistrazione, DataInizio) VALUES"]
    prop_list, vals = [], []
    aliscafi = [b for b in imbarcazioni if b['tipo'] == 'aliscafo']
    
    for i in range(NUM_COMPAGNIA):
        c = compagnie[i]
        b = aliscafi[i % len(aliscafi)]
        data = "1995-01-01"
        vals.append(f"('{c}', '{b['codice']}', '{data}')")
        prop_list.append({'compagnia': c, 'codice': b['codice'], 'tipo': 'aliscafo'})

    usate = {p['codice'] for p in prop_list}
    restanti = [b for b in imbarcazioni if b['codice'] not in usate]
    
    for b in restanti:
        if len(vals) >= NUM_PROPRIETA: break
        c = random.choice(compagnie)
        data = "1995-01-01"
        vals.append(f"('{c}', '{b['codice']}', '{data}')")
        prop_list.append({'compagnia': c, 'codice': b['codice'], 'tipo': b['tipo']})

    sql.append(",\n".join(vals) + ";\n")
    return sql, prop_list

def genera_sql_collegamento(citta_info, imbarcazioni, proprieta, nomi_comp):
    sql = ["-- POPOLAMENTO COLLEGAMENTO"]
    ora_libera_barca = {b['codice']: datetime.strptime("00:00:00", "%H:%M:%S") for b in imbarcazioni}
    
    citta_lombardia = [c['nome'] for c in citta_info if c['regione'] == 'Lombardia']
    target_city_lombardia = citta_lombardia[0] if citta_lombardia else "Milano"
    
    citta_piccole = [c['nome'] for c in citta_info if c['abitanti'] < 70000]
    citta_grandi = [c['nome'] for c in citta_info if c['abitanti'] >= 70000]
    
    # Pilotaggio Query 3: La compagnia nomi_comp[1] sarà l'unica (o una delle poche)
    # a collegare SOLO città piccole.
    comp_solo_piccole = nomi_comp[1]

    count = 0
    # 1. PILOTAGGIO QUERY 4 (Aliscafi Lombardia):
    # Facciamo in modo che comp[0] e comp[2..19] abbiano 3 viaggi (Excl da Query 4)
    # e comp[19] ne abbia 1 (Incl in Query 4)
    # Saltiamo nomi_comp[1] per ora per dedicarla alla Query 3
    for i in range(NUM_COMPAGNIA):
        if i == 1: continue # Gestiamo comp[1] separatamente dopo
        comp_attuale = nomi_comp[i]
        aliscafo = [p['codice'] for p in proprieta if p['compagnia'] == comp_attuale and p['tipo'] == 'aliscafo'][0]
        num_viaggi = 3 if i != 19 else 1
        for _ in range(num_viaggi):
            partenza = random.choice(citta_grandi) # Usiamo città grandi per assicurarci di escluderle da Q3
            ora_p = ora_libera_barca[aliscafo] + timedelta(minutes=15)
            ora_a = ora_p + timedelta(minutes=45)
            sql.append(f"INSERT INTO COLLEGAMENTO (Num, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) VALUES ({count+1}, '{partenza}', '{ora_p.time()}', '{target_city_lombardia}', '{ora_a.time()}', '{comp_attuale}', '{aliscafo}');")
            ora_libera_barca[aliscafo] = ora_a
            count += 1

    # 2. PILOTAGGIO QUERY 3 (Solo città < 70.000):
    # Diamo alla comp_solo_piccole (nomi_comp[1]) alcuni viaggi solo tra città piccole.
    barca_piccola = [p['codice'] for p in proprieta if p['compagnia'] == comp_solo_piccole][0]
    for _ in range(5):
        p, a = random.sample(citta_piccole, 2)
        ora_p = ora_libera_barca[barca_piccola] + timedelta(minutes=20)
        ora_a = ora_p + timedelta(minutes=40)
        sql.append(f"INSERT INTO COLLEGAMENTO (Num, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) VALUES ({count+1}, '{p}', '{ora_p.time()}', '{a}', '{ora_a.time()}', '{comp_solo_piccole}', '{barca_piccola}');")
        ora_libera_barca[barca_piccola] = ora_a
        count += 1

    # 3. RIEMPIMENTO FINO A 5000
    barca_to_comp = {p['codice']: p['compagnia'] for p in proprieta}
    barca_to_tipo = {b['codice']: b['tipo'] for b in imbarcazioni}

    while count < NUM_COLLEGAMENTO:
        cod = random.choice(list(barca_to_comp.keys()))
        comp = barca_to_comp[cod]
        
        # Se è la compagnia "piccola", deve continuare a viaggiare solo in città piccole
        if comp == comp_solo_piccole:
            p, a = random.sample(citta_piccole, 2)
        else:
            # Per tutte le altre, forziamo almeno un viaggio verso una città grande se non l'hanno già fatto
            # ma per semplicità qui usiamo un mix casuale
            p, a = random.sample([c['nome'] for c in citta_info], 2)
            
        # Manutenzione vincoli Query 4 (niente altri aliscafi in Lombardia)
        if barca_to_tipo[cod] == 'aliscafo' and any(c['nome'] == a and c['regione'] == 'Lombardia' for c in citta_info):
            continue

        ora_p_dt = ora_libera_barca[cod] + timedelta(minutes=random.randint(5, 30))
        if ora_p_dt.hour >= 22:
            ora_libera_barca[cod] = datetime.strptime("00:00:00", "%H:%M:%S")
            continue
        ora_a_dt = ora_p_dt + timedelta(minutes=random.randint(30, 90))
        
        sql.append(f"INSERT INTO COLLEGAMENTO (Num, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) VALUES ({count+1}, '{p.replace(chr(39),chr(39)*2)}', '{ora_p_dt.time()}', '{a.replace(chr(39),chr(39)*2)}', '{ora_a_dt.time()}', '{comp.replace(chr(39),chr(39)*2)}', '{cod}');")
        ora_libera_barca[cod] = ora_a_dt
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

if __name__ == "__main__":
    genera_tutto()