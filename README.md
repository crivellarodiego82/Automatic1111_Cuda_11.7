# Automatic1111_Cuda_11.7
Stable Diffusion Cuda 11.7


Percorso per i pesi:
I pesi devono essere copiati nella cartella /data/weights/ del container o del sistema host, da cui lo script CMD nel Dockerfile li copierà in /home/server/stable-diffusion-webui/models/Stable-diffusion/.

Queste modifiche garantiranno che il setup utilizzi l'utente server e i percorsi /home/server/.


Costruzione dell'immagine Docker:
sudo docker build -t nome_tua_immagine .

Avvio del Container:
docker run -d --gpus all -p 7860:7860 nome_tua_immagine

Verifica (verificare che i pesi siano stati copiati correttamente accedendo al container):
docker exec -it <nome_container> bash
ls /home/server/stable-diffusion-webui/models/Stable-diffusion/


Modifiche:

Copia direttamente dal sistema host al container:
Se vuoi copiare file dal sistema host al container mentre il container è in esecuzione, puoi utilizzare il comando docker cp
docker run -d --name my_container my_image
docker cp /percorso/del/file my_container:/data/weights/
docker exec -it my_container bash
ls /data/weights/

Copia all'interno del Dockerfile
Se desideri che i file vengano copiati direttamente nel tuo container al momento della creazione, puoi farlo nel tuo Dockerfile. Ecco come configurare il tuo Dockerfile per copiare i file da una directory sul tuo sistema host a /data/weights/ nel container:

Copia all'interno del Dockerfile
Se desideri che i file vengano copiati direttamente nel tuo container al momento della creazione, puoi farlo nel tuo Dockerfile. Ecco come configurare il tuo Dockerfile per copiare i file da una directory sul tuo sistema host a /data/weights/ nel container:

sudo nano Dockerfile

# Usa un'immagine base
FROM ubuntu:20.04

# Crea la directory di destinazione nel container
RUN mkdir -p /data/weights/

# Copia i file dalla directory locale all'interno del container
COPY ./local_weights/ /data/weights/

# Copia in un'altra directory se necessario
RUN mkdir -p /home/server/stable-diffusion-webui/models/Stable-diffusion/
COPY /data/weights/ /home/server/stable-diffusion-webui/models/Stable-diffusion/

# Comando da eseguire quando il container parte
CMD ["your_command_here"]
