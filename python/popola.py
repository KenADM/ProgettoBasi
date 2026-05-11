import random
import os
from datetime import datetime, timedelta

# Quantità richieste dalla Tavola dei Volumi
NUM_COMPAGNIA = 20
NUM_IMBARCAZIONE = 100
NUM_CITTA = 100
NUM_COLLEGAMENTO = 5000
NUM_PROPRIETA = 7000



# DEFINIZIONE PERCORSI INTELLIGENTE
# Se gira dentro Docker userà i percorsi assoluti dei volumi mappati, 
# altrimenti userà i percorsi relativi del tuo PC locale.
IN_DOCKER = os.path.exists('/data')

PATH_COMPAGNIE = '/data/compagnie.txt' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../data/compagnie.txt')
PATH_CITTA = '/data/citta.txt' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../data/citta.txt')
PATH_BARCHE = '/data/barche.txt' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../data/barche.txt')
PATH_OUTPUT = '/output/02_dati.sql' if IN_DOCKER else os.path.join(os.path.dirname(__file__), '../sql/02_dati.sql')


def genera_codice_registrazione():
    return f"NAV-{random.randint(10000, 99999)}"

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
        return [{'nome': 'Napoli', 'regione': 'Campania', 'provincia': 'NA', 'abitanti': 960000}]

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

def genera_tutto():
    sql_lines = []
    
    # Caricamento usando i percorsi intelligenti
    lista_compagnie_txt = carica_compagnie_da_file(PATH_COMPAGNIE)
    lista_citta = carica_citta_da_file(PATH_CITTA)
    lista_imbarcazioni_txt = carica_imbarcazioni_da_file(PATH_BARCHE)
    
    if not lista_compagnie_txt:
        lista_compagnie_txt = [{'nome': f"Compagnia-{i}", 'amministratore': 'Admin', 'capitale': 5000000.00} for i in range(1, 21)]
    if not lista_imbarcazioni_txt:
        lista_imbarcazioni_txt = [{'nome': f"Nave-{i}", 'anno': 2000, 'peso': 5000, 'tipo': 'T'} for i in range(1, 101)]
    
    sql_lines.append("/* ========================================================\n")
    sql_lines.append("   DATI GENERATI AUTOMATICAMENTE VIA PYTHON\n")
    sql_lines.append("   ======================================================== */\n")

    # [Nota: La logica di generazione interna rimane identica a prima]
    # 1. COMPAGNIA
    sql_lines.append("-- POPOLAMENTO COMPAGNIA")
    compagnie_generate = []
    for comp_info in lista_compagnie_txt:
        nome_comp = comp_info['nome'].replace("'", "''")
        amministratore = comp_info['amministratore'].replace("'", "''")
        capitale = comp_info['capitale']
        sql_lines.append(f"INSERT INTO COMPAGNIA (Nome, Amministratore, Capitale, NumCittaServite) VALUES ('{nome_comp}', '{amministratore}', {capitale:.2f}, 0);")
        compagnie_generate.append(nome_comp)
    sql_lines.append("")

    # 2. IMBARCAZIONE
    sql_lines.append("-- POPOLAMENTO IMBARCAZIONE")
    imbarcazioni_generate = []
    for imb_info in lista_imbarcazioni_txt:
        codice = genera_codice_registrazione()
        while codice in [imb['codice'] for imb in imbarcazioni_generate]:
            codice = genera_codice_registrazione()
        nome_nave = imb_info['nome']
        anno = imb_info['anno']
        peso = imb_info['peso']
        tipo = imb_info['tipo']
        sql_lines.append(f"INSERT INTO IMBARCAZIONE (CodiceRegistrazione, AnnoCostruzione, Peso, Tipo) VALUES ('{codice}', {anno}, {peso}, '{tipo}'); -- Nome: {nome_nave}")
        imbarcazioni_generate.append({'codice': codice, 'tipo': tipo, 'anno': anno})
    sql_lines.append("")

    # 3. CITTA
    sql_lines.append("-- POPOLAMENTO CITTA")
    nomi_citta_generati = []
    for c in lista_citta:
        nome_citta = c['nome'].replace("'", "''")
        sql_lines.append(f"INSERT INTO CITTA (Nome, Regione, Provincia, NumAbitanti, NumCompagnieColleganti) VALUES ('{nome_citta}', '{c['regione']}', '{c['provincia']}', {c['abitanti']}, 0);")
        nomi_citta_generati.append(nome_citta)
    sql_lines.append("")

    # 4. PROPRIETA
    sql_lines.append("-- POPOLAMENTO PROPRIETA")
    for imb in imbarcazioni_generate:
        comp_proprietaria = random.choice(compagnie_generate)
        anno_costruzione = imb['anno']
        data_acquisto_anno = random.randint(anno_costruzione, 2026)
        data_acquisto_mese = random.randint(1, 12)
        data_acquisto_giorno = random.randint(1, 28)
        data_inizio = f"{data_acquisto_anno}-{data_acquisto_mese:02d}-{data_acquisto_giorno:02d}"
        sql_lines.append(f"INSERT INTO PROPRIETA (NomeComp, CodiceRegistrazione, DataInizio) VALUES ('{comp_proprietaria}', '{imb['codice']}', '{data_inizio}');")
    sql_lines.append("")

    # 5. COLLEGAMENTO (5000 record)
    sql_lines.append("-- POPOLAMENTO COLLEGAMENTO")
    for num in range(1, NUM_COLLEGAMENTO + 1):
        c_partenza = random.choice(nomi_citta_generati)
        c_arrivo = random.choice(nomi_citta_generati)
        while c_arrivo == c_partenza:
            c_arrivo = random.choice(nomi_citta_generati)
        codice_tratta = str(random.randint(100000, 999999))
        ora_p_dt = datetime.strptime(f"{random.randint(5, 22)}:{random.choice([0, 15, 30, 45])}", "%H:%M")
        ora_partenza = ora_p_dt.strftime("%H:%M:%S")
        durata_viaggio = random.randint(1, 12)
        ora_arrivo = (ora_p_dt + timedelta(hours=durata_viaggio)).strftime("%H:%M:%S")
        compagnia_servizio = random.choice(compagnie_generate)
        imbarcazione_servizio = random.choice(imbarcazioni_generate)['codice']
        sql_lines.append(f"INSERT INTO COLLEGAMENTO (Num, Codice, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) VALUES ({num}, '{codice_tratta}', '{c_partenza}', '{ora_partenza}', '{c_arrivo}', '{ora_arrivo}', '{compagnia_servizio}', '{imbarcazione_servizio}');")

    # Scrittura finale usando il percorso intelligente
    with open(PATH_OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(sql_lines))
        
    print(f"Generazione completata con successo in {PATH_OUTPUT}!")

if __name__ == "__main__":
    genera_tutto()