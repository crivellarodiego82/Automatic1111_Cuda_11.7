FROM nvidia/cuda:11.7.1-cudnn8-runtime-ubuntu22.04

# Imposta la variabile di ambiente per l'installazione senza interazione
ENV DEBIAN_FRONTEND=noninteractive

# Aggiorna il sistema e installa i pacchetti necessari
RUN apt-get update \
    && apt-get install -y wget git python3 python3-venv libgl1 libglib2.0-0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Crea l'utente server
RUN adduser --uid 1001 --shell /bin/bash server

# Copia gli script nella home dell'utente server
COPY prepare.py /home/server/prepare.py
COPY webui.sh /home/server/webui.sh
RUN chown -R 1001:1001 /home/server

# Cambia utente
USER 1001
WORKDIR /home/server

# Variabile per pip
ENV PIP_NO_CACHE_DIR=false

# Esegui lo script webui.sh
RUN COMMANDLINE_ARGS="--skip-torch-cuda-test" bash webui.sh \
    && rm -rf $(find . -name "*.safetensors")

# Crea la directory per i modelli
RUN mkdir -p /home/server/stable-diffusion-webui/models/Stable-diffusion/

# Copia i pesi nella directory appropriata
COPY /home/nextserver/automatic1111-minimal/weights/* /home/server/stable-diffusion-webui/models/Stable-diffusion/

# Imposta la directory di lavoro
WORKDIR /home/server/stable-diffusion-webui

# Variabili ambientali per NVIDIA e Gradio
ENV NVIDIA_VISIBLE_DEVICES=all
EXPOSE 7860
ENV GRADIO_SERVER_NAME=0.0.0.0
ENV GRADIO_SERVER_PORT=7860

# Comando di avvio
CMD ["bash", "-c", "source venv/bin/activate && python launch.py --opt-sdp-attention --no-half-vae"]
