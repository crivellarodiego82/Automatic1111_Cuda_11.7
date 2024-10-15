# Imposta l'interfaccia debian per non chiedere interazioni
export DEBIAN_FRONTEND=noninteractive
apt-get update \
    && apt-get install -y wget git python3 python3-venv libgl1 libglib2.0-0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Crea l'utente 'server' con ID 1001
adduser --uid 1001 --shell /bin/bash server

# Copia i file necessari nella home dell'utente 'server'
cp prepare.py /home/server/prepare.py
cp webui.sh /home/server/webui.sh

# Cambia la proprietà dei file per l'utente 'server'
chown -R 1001:1001 /home/server

# Passa all'utente 'server'
su - server

# Disabilita la cache di pip
export PIP_NO_CACHE_DIR=false

# Esegui lo script 'webui.sh' e rimuovi i file .safetensors
COMMANDLINE_ARGS="--skip-torch-cuda-test" bash webui.sh \
    && rm -rf $(find . -name "*.safetensors")

# Configura le variabili ambientali per Gradio
export GRADIO_SERVER_NAME=0.0.0.0
export GRADIO_SERVER_PORT=7860

# Crea la directory per i modelli e scarica i pesi
mkdir -p /home/server/stable-diffusion-webui/models/Stable-diffusion/
cd stable-diffusion-webui/

# Scarica i pesi dal repository di Hugging Face
wget https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors
wget https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors -P models/Stable-diffusion/
mv sd_xl_*.safetensors ./models/Stable-diffusion/

# Esegui lo script principale per avviare l'applicazione
python launch.py --opt-sdp-attention --no-half-vae
