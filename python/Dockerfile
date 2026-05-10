FROM python:3.10-slim

WORKDIR /app

# Copiamo lo script
COPY popola.py .

# Nota: per leggere i file .txt useremo i volumi condivisi di Docker Compose,
# così se modifichi i .txt non dovrai ricostruire l'immagine ogni volta!
CMD ["python", "popola.py"]