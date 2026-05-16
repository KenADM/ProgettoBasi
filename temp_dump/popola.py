import random
import os
from datetime import datetime, timedelta

# Quantità richieste dalla Tavola dei Volumi
NUM_COMPAGNIA = 20
NUM_IMBARCAZIONE = 100
NUM_CITTA = 100
NUM_COLLEGAMENTO = 500
NUM_PROPRIETA = 700

#NUM_COMPAGNIA = 0
#NUM_IMBARCAZIONE = 0
#NUM_CITTA = 0
#NUM_COLLEGAMENTO = 0
#NUM_PROPRIETA = 0

# DEFINIZIONE PERCORSI INTELLIGENTE
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
    
    # APPLICHIAMO LE VARIABILI GLOBALI: Tagliamo le liste se sono più lunghe del richiesto
    lista_compagnie_txt = lista_compagnie_txt[:NUM_COMPAGNIA]
    lista_citta = lista_citta[:NUM_CITTA]
    lista_imbarcazioni_txt = lista_imbarcazioni_txt[:NUM_IMBARCAZIONE]
    
    # Fallback fittizi basati strettamente sulle variabili globali
    if not lista_compagnie_txt:
        lista_compagnie_txt = [{'nome': f"Compagnia-{i}", 'amministratore': 'Admin', 'capitale': 5000000.00} for i in range(1, NUM_COMPAGNIA + 1)]
    if not lista_imbarcazioni_txt:
        lista_imbarcazioni_txt = [{'nome': f"Nave-{i}", 'anno': 2000, 'peso': 5000, 'tipo': 'T'} for i in range(1, NUM_IMBARCAZIONE + 1)]
    
    sql_lines.append("/* ========================================================\n")
    sql_lines.append("   DATI GENERATI AUTOMATICAMENTE VIA PYTHON\n")
    sql_lines.append("   ======================================================== */\n")

    # 1. COMPAGNIA ---------------------------------------
    sql_lines.append("-- POPOLAMENTO COMPAGNIA")
    sql_lines.append("INSERT INTO COMPAGNIA (Nome, Amministratore, Capitale, NumCittaServite) VALUES")
    
    compagnie_generate = []
    valori_compagnia = []  # Lista temporanea per il bulk insert
    
    # Il ciclo gira ESATTAMENTE il numero di volte richiesto dalla variabile
    for i in range(NUM_COMPAGNIA):
        # L'operatore % (modulo) fa ricominciare la lista da capo se i < len
        comp_info = lista_compagnie_txt[i % len(lista_compagnie_txt)]
        
        # Se stiamo ricominciando la lista, aggiungiamo un numero per evitare nomi duplicati nel DB
        giri_di_lista = i // len(lista_compagnie_txt) # quanti giri abbiamo fatto della lista per arrivare al numero richiesto di compagnie nel db
        suffisso = f" {giri_di_lista + 1}" if giri_di_lista > 0 else ""
        
        # NB - Sostituiamo eventuali apostrofi con due apostrofi per evitare errori SQL
        nome_comp = (comp_info['nome'] + suffisso).replace("'", "''")
        amministratore = comp_info['amministratore'].replace("'", "''")
        capitale = comp_info['capitale']
        
        # Accumuliamo la tupla, il numero di città servite parte da 0 e sarà aggiornato in seguito
        riga_valori = f"('{nome_comp}', '{amministratore}', {capitale:.2f}, 0)"
        valori_compagnia.append(riga_valori)
        
        # Utile per i cicli successivi (PROPRIETA)
        compagnie_generate.append(nome_comp)
    
    # Uniamo tutte le tuple con la virgola e chiudiamo con il punto e virgola
    sql_lines.append(",\n".join(valori_compagnia) + ";")
    sql_lines.append("")

    # 2. IMBARCAZIONE ---------------------------------------
    sql_lines.append("-- POPOLAMENTO IMBARCAZIONE")
    sql_lines.append("INSERT INTO IMBARCAZIONE (CodiceRegistrazione, AnnoCostruzione, Peso, Tipo) VALUES")
    
    imbarcazioni_generate = []
    valori_imbarcazione = []  # Lista temporanea per il bulk insert
    
    # Il ciclo gira ESATTAMENTE il numero di volte richiesto da NUM_IMBARCAZIONE (es. 100)
    for i in range(NUM_IMBARCAZIONE):
        # L'operatore % fa ricominciare la lista da capo se i dati nel txt sono meno di 100
        imb_info = lista_imbarcazioni_txt[i % len(lista_imbarcazioni_txt)]
        
        # Generiamo un codice di registrazione univoco
        codice = genera_codice_registrazione()
        while codice in [imb['codice'] for imb in imbarcazioni_generate]:
            codice = genera_codice_registrazione()
            
        nome_nave = imb_info['nome']
        anno = imb_info['anno']
        peso = imb_info['peso']
        tipo = imb_info['tipo']
        
        # Se stiamo riciclando i dati oltre la lunghezza del file, cambiamo leggermente il nome nel commento
        giri_di_lista = i // len(lista_imbarcazioni_txt)
        suffisso = f" Bis" if giri_di_lista > 0 else ""
        
        # Accumuliamo la tupla senza punteggiatura finale (lasciamo il nome come commento SQL a lato)
        riga_valori = f"('{codice}', {anno}, {peso}, '{tipo}')"
        valori_imbarcazione.append(riga_valori)
        
        # Salviamo in memoria per i cicli successivi (PROPRIETA)
        imbarcazioni_generate.append({'codice': codice, 'tipo': tipo, 'anno': anno})
        
    # Uniamo tutte le tuple con la virgola e chiudiamo l'INSERT con il punto e virgola
    sql_lines.append(",\n".join(valori_imbarcazione) + ";")
    sql_lines.append("")

    # 3. CITTA ---------------------------------------
    sql_lines.append("-- POPOLAMENTO CITTA")
    sql_lines.append("INSERT INTO CITTA (Nome, Regione, Provincia, NumAbitanti, NumCompagnieColleganti) VALUES")
    
    nomi_citta_generati = []
    valori_citta = []  # Lista temporanea per il bulk insert
    
    # Il ciclo gira ESATTAMENTE il numero di volte richiesto da NUM_CITTA (es. 100)
    for i in range(NUM_CITTA):
        # L'operatore % fa ricominciare la lista da capo se i dati nel txt sono meno di 100
        c = lista_citta[i % len(lista_citta)]
        
        # Se stiamo facendo più giri sulla lista, aggiungiamo un numero per rendere il nome univoco
        giri_di_lista = i // len(lista_citta)
        suffisso = f" {giri_di_lista + 1}" if giri_di_lista > 0 else ""
        
        nome_citta = (c['nome'] + suffisso).replace("'", "''")
        regione = c['regione'].replace("'", "''")
        provincia = c['provincia'].replace("'", "''")
        abitanti = c['abitanti']
        
        # Accumuliamo la tupla senza punteggiatura finale
        riga_valori = f"('{nome_citta}', '{regione}', '{provincia}', {abitanti}, 0)"
        valori_citta.append(riga_valori)
        
        # Salviamo il nome esatto in memoria per usarlo nei collegamenti successivi
        nomi_citta_generati.append(nome_citta)
        
    # Uniamo tutte le tuple con la virgola e chiudiamo con il punto e virgola finale
    sql_lines.append(",\n".join(valori_citta) + ";")
    sql_lines.append("")

    # 4. PROPRIETA ---------------------------------------
    sql_lines.append(f"-- POPOLAMENTO PROPRIETA ({NUM_PROPRIETA} record)")
    sql_lines.append("INSERT INTO PROPRIETA (NomeComp, CodiceRegistrazione, DataInizio) VALUES")
    
    proprieta_generate_set = set() # Usato per evitare duplicati esatti
    valori_proprieta = []          # Lista temporanea per il bulk insert
    valori_proprieta_generati = []
    
    for _ in range(NUM_PROPRIETA):
        # Peschiamo casualmente dalle barche e dalle compagnie già create
        comp_proprietaria = random.choice(compagnie_generate)
        imb = random.choice(imbarcazioni_generate)
        codice_barca = imb['codice']
        anno_costruzione = imb['anno']
        
        # Generiamo una data che non sia mai stata usata esattamente per questa compagnia e barca
        while True:
            data_acquisto_anno = random.randint(anno_costruzione, 2026)
            data_acquisto_mese = random.randint(1, 12)
            data_acquisto_giorno = random.randint(1, 28)
            data_inizio = f"{data_acquisto_anno}-{data_acquisto_mese:02d}-{data_acquisto_giorno:02d}"
            
            chiave_univoca = (comp_proprietaria, codice_barca, data_inizio)
            if chiave_univoca not in proprieta_generate_set:
                proprieta_generate_set.add(chiave_univoca)
                break
                
        # Accumuliamo la singola tupla nella lista temporanea (senza INSERT INTO ripetuti)
        riga_valori = f"('{comp_proprietaria}', '{codice_barca}', '{data_inizio}')"
        valori_proprieta.append(riga_valori)

        # Salviamo in memoria per i cicli successivi (COLLEGAMENTO)
        valori_proprieta_generati.append({'codice': codice_barca, 'compagnia': comp_proprietaria, 'data': data_inizio})
        
    # Uniamo tutte le 7.000 tuple con la virgola e chiudiamo con il punto e virgola
    sql_lines.append(",\n".join(valori_proprieta) + ";")
    sql_lines.append("")

    # 5. COLLEGAMENTO ---------------------------------------
    sql_lines.append(f"-- POPOLAMENTO COLLEGAMENTO ({NUM_COLLEGAMENTO} record)")
    sql_lines.append("INSERT INTO COLLEGAMENTO (Num, Codice, NomePartenza, OraPartenza, NomeArrivo, OraArrivo, NomeComp, CodiceRegistrazione) VALUES")
    
    valori_collegamento = [] # Lista temporanea per il bulk insert
    for num in range(1, NUM_COLLEGAMENTO + 1):
        c_partenza = random.choice(nomi_citta_generati)
        c_arrivo = random.choice(nomi_citta_generati)
            
        codice_tratta = str(random.randint(100000, 999999))

        ora1 = datetime.strptime(f"{random.randint(5, 22)}:{random.choice([0, 15, 30, 45])}", "%H:%M")
        ora2 = datetime.strptime(f"{random.randint(5, 22)}:{random.choice([0, 15, 30, 45])}", "%H:%M")

        if ora2 < ora1:
            ora_partenza = ora2
            ora_arrivo = ora1
        else:
            ora_partenza = ora1
            ora_arrivo = ora2
        
        # Scelgo una barca casuale tra quelle generate in PROPRIETA per assegnarla al collegamento
        # La scelgo da proprietà in modo da garantire che la barca sia effettivamente in servizio per una compagnia
        scelta_barca = random.choice(valori_proprieta_generati)
        compagnia_servizio = scelta_barca['compagnia']
        imbarcazione_servizio = scelta_barca['codice']
        
        # Accumuliamo la singola tupla nella lista temporanea
        riga_valori = f"({num}, '{codice_tratta}', '{c_partenza}', '{ora_partenza}', '{c_arrivo}', '{ora_arrivo}', '{compagnia_servizio}', '{imbarcazione_servizio}')"
        valori_collegamento.append(riga_valori)

    # Uniamo tutte le 5.000 tuple con la virgola e chiudiamo con il punto e virgola
    sql_lines.append(",\n".join(valori_collegamento) + ";")
    sql_lines.append("")

    # Scrittura finale usando il percorso intelligente
    with open(PATH_OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(sql_lines))
        
    print(f"Generazione completata con successo in {PATH_OUTPUT}!")

if __name__ == "__main__":
    genera_tutto()