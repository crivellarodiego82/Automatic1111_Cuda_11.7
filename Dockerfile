FROM nvidia/cuda:11.7.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
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

USER 1001
WORKDIR /home/server

ENV PIP_NO_CACHE_DIR=false

RUN COMMANDLINE_ARGS="--skip-torch-cuda-test" bash webui.sh \
    && rm -rf $(find . -name "*.safetensors")

WORKDIR /home/server/stable-diffusion-webui

ENV NVIDIA_VISIBLE_DEVICES=all
EXPOSE 7860

ENV GRADIO_SERVER_NAME=0.0.0.0
ENV GRADIO_SERVER_PORT=7860

# Crea la directory per i modelli
RUN mkdir -p /home/server/stable-diffusion-webui/models/Stable-diffusion/
CMD ["bash", "-c", "source /home/server/stable-diffusion-webui/venv/bin/activate && ls /data && cp /data/weights/* /home/server/stable-diffusion-webui/models/Stable-diffusion/ || echo NOPE && python launch.py --opt-sdp-attention --no-half-vae"]
