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

index_barche = 0;
# DEFINIZIONE PERCORSI INTELLIGENTE
IN_DOCKER = os.path.exists('/data')

PATH_COMPAGNIE = '/data/compagnie.txt' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../data/compagnie.txt')
PATH_CITTA = '/data/citta.txt' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../data/citta.txt')
PATH_BARCHE = '/data/barche.txt' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../data/barche.txt')
PATH_OUTPUT = '/output/02_dati.sql' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../sql/02_dati.sql')

def cambia_nome_tipo(T):
    match T:
        case 'T':
            return "traghetto"
        case 'C':
            return "cargo"
        case 'A':
            return "aliscafi"
        case 'K':
            return "catamarani"
        case 'M':
            return "motonavi"
        case _:  
            return "altro"

def genera_codice_registrazione(): # !! faccio incrementale
    global NUM_CODICE_REGISTRAZIONE
    NUM_CODICE_REGISTRAZIONE += 1
    return NUM_CODICE_REGISTRAZIONE 

def carica_citta_da_file(nome_file_path):
    citta_list = []
    try:
        with open(nome_file_path, 'r', encoding='utf-8') as f:
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
    except FileNotFoundError:
        print(f"File {nome_file_path} non trovato.")
        return [{'nome': 'Napoli', 'regione': 'Campania', 'provincia': 'NA', 'abitanti': 960000}] # evitare errori nell'inserimento dei successivi

def carica_compagnie_da_file(nome_file_path):
    compagnie = []
    try:
        with open(nome_file_path, 'r', encoding='utf-8') as f:
            for linea in f:
                if linea.strip():
                    parti = linea.strip().split(',')
                    compagnie.append({
                        'nome': parti[0].strip(),
                        'amministratore': parti[1].strip(),
                        'capitale': float(parti[2].strip())
                    })
        return compagnie
    except FileNotFoundError:
        print(f"File {nome_file_path} non trovato.")
        return []

def carica_imbarcazioni_da_file(nome_file_path):
    imbarcazioni = []
    try:
        with open(nome_file_path, 'r', encoding='utf-8') as f:
            for linea in f:
                if linea.strip():
                    parti = linea.strip().split(',')
                    imbarcazioni.append({
                        'nome': parti[0].strip(),
                        'anno': int(parti[1].strip()),
                        'peso': int(parti[2].strip()),
                        'tipo': parti[3].strip()
                    })
        return imbarcazioni
    except FileNotFoundError:
        print(f"File {nome_file_path} non trovato.")
        return []
    
def scegli_barca_per_collegamento(barche, associazioni_proprieta):
    global index_barche
    scelta_barca = barche[index_barche]
    scelta_associazione = None
    
    for associazione in associazioni_proprieta:
        if associazione['codice'] == scelta_barca['codice'] and (scelta_associazione is None or associazione['data'] > scelta_associazione['data']):
            scelta_associazione = associazione

    if scelta_associazione:
        return scelta_associazione
    else:
        index_barche += 1
        return scegli_barca_per_collegamento(barche, associazioni_proprieta)

# =========================================================
# FUNZIONI DI GENERAZIONE SUDDIVISE
# =========================================================

def prepara_liste_base():
    """Carica i file di testo, applica i limiti e gestisce i fallback fittizi."""
    lista_compagnie_txt = carica_compagnie_da_file(PATH_COMPAGNIE)[:NUM_COMPAGNIA]
    lista_citta = carica_citta_da_file(PATH_CITTA)[:NUM_CITTA]
    lista_imbarcazioni_txt = carica_imbarcazioni_da_file(PATH_BARCHE)[:NUM_IMBARCAZIONE]
    
    # riempio le liste anche se non ci sono i file
    if not lista_compagnie_txt:
        lista_compagnie_txt = [{'nome': f"Compagnia-{i}", 'amministratore': 'Admin', 'capitale': 5000000.00} for i in range(1, NUM_COMPAGNIA + 1)]
    if not lista_imbarcazioni_txt:
        lista_imbarcazioni_txt = [{'nome': f"Nave-{i}", 'anno': 2000, 'peso': 5000, 'tipo': 'T'} for i in range(1, NUM_IMBARCAZIONE + 1)]
        
    return lista_compagnie_txt, lista_citta, lista_imbarcazioni_txt

def genera_sql_compagnia(lista_compagnie_txt):
    sql_lines = ["-- POPOLAMENTO COMPAGNIA", "INSERT INTO COMPAGNIA (Nome, Amministratore, Capitale, NumCittaServite) VALUES"]
    compagnie_generate = []
    valori_compagnia = [] 
    
    for i in range(NUM_COMPAGNIA):
        comp_info = lista_compagnie_txt[i % len(lista_compagnie_txt)]

        # per gestire il fatto che i nomi non potrebbero bastare accontentare il numero di compagnie richieste, calcolo cosi + aggiungo suffisso 
        giri_di_lista = i // len(lista_compagnie_txt)
        suffisso = f" {giri_di_lista + 1}" if giri_di_lista > 0 else ""
        
        nome_comp = (comp_info['nome'] + suffisso).replace("'", "''")
        amministratore = comp_info['amministratore'].replace("'", "''")
        capitale = comp_info['capitale']
        
        riga_valori = f"('{nome_comp}', '{amministratore}', {capitale:.2f}, 0)"
        valori_compagnia.append(riga_valori)
        compagnie_generate.append(nome_comp)
    
    sql_lines.append(",\n".join(valori_compagnia) + ";\n")
    return sql_lines, compagnie_generate

def genera_sql_imbarcazione(lista_imbarcazioni_txt):
    sql_lines = ["-- POPOLAMENTO IMBARCAZIONE", "INSERT INTO IMBARCAZIONE (CodiceRegistrazione, AnnoCostruzione, Peso, Tipo) VALUES"]
    imbarcazioni_generate = []
    valori_imbarcazione = [] 
    
    for i in range(NUM_IMBARCAZIONE):
        imb_info = lista_imbarcazioni_txt[i % len(lista_imbarcazioni_txt)]
        
        codice = genera_codice_registrazione()

        # while codice in [imb['codice'] for imb in imbarcazioni_generate]:
        #    codice = genera_codice_registrazione()
            
        anno = imb_info['anno']
        peso = imb_info['peso']
        tipo = cambia_nome_tipo(imb_info['tipo'])
        
        riga_valori = f"('{codice}', {anno}, {peso}, '{tipo}')"
        valori_imbarcazione.append(riga_valori)
        imbarcazioni_generate.append({'codice': codice, 'tipo': tipo, 'anno': anno})
        
    sql_lines.append(",\n".join(valori_imbarcazione) + ";\n")
    return sql_lines, imbarcazioni_generate

def genera_sql_citta(lista_citta):
    sql_lines = ["-- POPOLAMENTO CITTA", "INSERT INTO CITTA (Nome, Regione, Provincia, NumAbitanti, NumCompagnieColleganti) VALUES"]
    nomi_citta_generati = []
    valori_citta = [] 
    
    for i in range(NUM_CITTA):
        c = lista_citta[i % len(lista_citta)]
        giri_di_lista = i // len(lista_citta)
        suffisso = f" {giri_di_lista + 1}" if giri_di_lista > 0 else ""
        
        nome_citta = (c['nome'] + suffisso).replace("'", "''")
        regione = c['regione'].replace("'", "''")
        provincia = c['provincia'].replace("'", "''")
        abitanti = c['abitanti']
        
        riga_valori = f"('{nome_citta}', '{regione}', '{provincia}', {abitanti}, 0)"
        valori_citta.append(riga_valori)
        nomi_citta_generati.append(nome_citta)
        
    sql_lines.append(",\n".join(valori_citta) + ";\n")
    return sql_lines, nomi_citta_generati

def genera_sql_proprieta(compagnie_generate, imbarcazioni_generate):
    sql_lines = [f"-- POPOLAMENTO PROPRIETA ({NUM_PROPRIETA} record)", "INSERT INTO PROPRIETA (NomeComp, CodiceRegistrazione, DataInizio) VALUES"]
    proprieta_generate_set = set()
    valori_proprieta = []
    valori_proprieta_generati = []
    
    for _ in range(NUM_PROPRIETA):
        comp_proprietaria = random.choice(compagnie_generate)
        imb = random.choice(imbarcazioni_generate)
        codice_barca = imb['codice']
        anno_costruzione = imb['anno']
        
        while True:
            data_acquisto_anno = random.randint(anno_costruzione, 2026)
            data_acquisto_mese = random.randint(1, 12)
            data_acquisto_giorno = random.randint(1, 28)
            data_inizio = f"{data_acquisto_anno}-{data_acquisto_mese:02d}-{data_acquisto_giorno:02d}"
            
            chiave_univoca = (comp_proprietaria, codice_barca, data_inizio)
            if chiave_univoca not in proprieta_generate_set:
                proprieta_generate_set.add(chiave_univoca)
                break
                
        riga_valori = f"('{comp_proprietaria}', '{codice_barca}', '{data_inizio}')"
        valori_proprieta.append(riga_valori)
        valori_proprieta_generati.append({'codice': codice_barca, 'compagnia': comp_proprietaria, 'data': data_inizio})
        
    sql_lines.append(",\n".join(valori_proprieta) + ";\n")
    return sql_lines, valori_proprieta_generati

def genera_sql_collegamento(nomi_citta_generati, imbarcazioni_generate, valori_proprieta_generati):
    global index_barche
    sql_lines = [f"-- POPOLAMENTO COLLEGAMENTO ({NUM_COLLEGAMENTO} record)"]
    valori_collegamento_generati = []
    
    # Inizializziamo l'ora a mezzanotte
    counter = 0;
    ora = datetime.strptime("00:00:00", "%H:%M:%S")
    ora_partenza = datetime.strptime("00:00:00", "%H:%M:%S")
    
    # Dichiariamo le variabili fuori dal ciclo per evitare errori di scope
    compagnia_servizio = ""
    imbarcazione_servizio = ""

    for num in range(1, NUM_COLLEGAMENTO + 1):
        c_partenza = random.choice(nomi_citta_generati)
        c_arrivo = random.choice(nomi_citta_generati)
        
        
        if counter == 0 or counter > 22:
            counter = 0
            ora_partenza = ora
            scelta_barca = scegli_barca_per_collegamento(imbarcazioni_generate, valori_proprieta_generati)
            compagnia_servizio = scelta_barca['compagnia']
            imbarcazione_servizio = scelta_barca['codice']
            index_barche += 1

        if ora_partenza == ora:
            ora_partenza = (ora + timedelta(hours=counter)).time()

        ora_in_piu = random.randint(0,1);
        ora_arrivo = (ora + timedelta(hours=counter + ora_in_piu) + timedelta(minutes=random.randint(1, 59))).time()
        
        query_insert = f"INSERT INTO COLLEGAMENTO (Num, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) VALUES ({num}, '{c_partenza}', '{ora_partenza}', '{c_arrivo}', '{ora_arrivo}', '{compagnia_servizio}', '{imbarcazione_servizio}');"
        sql_lines.append(query_insert)

        valori_collegamento_generati.append({
            'num': num,
            'partenza': c_partenza,
            'ora_partenza': ora_partenza,
            'arrivo': c_arrivo,
            'ora_arrivo': ora_arrivo,
            'compagnia': compagnia_servizio,
            'imbarcazione': imbarcazione_servizio
        })
        
        ora_partenza = ora_arrivo
        counter = counter + 1 + ora_in_piu

    sql_lines.append("\n")
    return sql_lines, valori_collegamento_generati

# =========================================================
# FUNZIONE PRINCIPALE (ORCHESTRATORE)
# =========================================================

def genera_tutto():
    sql_lines = []
    sql_lines.append("/* ========================================================\n")
    sql_lines.append("   DATI GENERATI AUTOMATICAMENTE VIA PYTHON\n")
    sql_lines.append("   ======================================================== */\n")

    # 0. Setup Dati Base
    lista_compagnie_txt, lista_citta, lista_imbarcazioni_txt = prepara_liste_base()

    # 1. COMPAGNIA
    linee, compagnie_generate = genera_sql_compagnia(lista_compagnie_txt)
    sql_lines.extend(linee)

    # 2. IMBARCAZIONE
    linee, imbarcazioni_generate = genera_sql_imbarcazione(lista_imbarcazioni_txt)
    sql_lines.extend(linee)

    # 3. CITTA
    linee, nomi_citta_generati = genera_sql_citta(lista_citta)
    sql_lines.extend(linee)

    # 4. PROPRIETA
    linee, valori_proprieta_generati = genera_sql_proprieta(compagnie_generate, imbarcazioni_generate)
    sql_lines.extend(linee)

    # 5. COLLEGAMENTO
    linee, valori_collegamento_generati = genera_sql_collegamento(nomi_citta_generati, imbarcazioni_generate, valori_proprieta_generati)
    sql_lines.extend(linee)

    # Scrittura finale
    with open(PATH_OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(sql_lines))
        
    print(f"Generazione completata con successo in {PATH_OUTPUT}!")

if __name__ == "__main__":
    genera_tutto()