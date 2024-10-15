#!/usr/bin/env bash

# Utilizza l'ambiente virtuale
use_venv=1
if [[ $venv_dir == "-" ]]; then
  use_venv=0
fi

# Imposta la directory dello script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Se eseguito da macOS, carica le impostazioni predefinite da webui-macos-env.sh
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ -f "$SCRIPT_DIR"/webui-macos-env.sh ]]
        then
        source "$SCRIPT_DIR"/webui-macos-env.sh
    fi
fi

# Leggi le variabili da webui-user.sh
# shellcheck source=/dev/null
if [[ -f "$SCRIPT_DIR"/webui-user.sh ]]
then
    source "$SCRIPT_DIR"/webui-user.sh
fi

# Imposta le variabili predefinite
# Directory di installazione senza barra finale
if [[ -z "${install_dir}" ]]
then
    install_dir="$SCRIPT_DIR"
fi

# Nome della sottodirectory (predefinita su stable-diffusion-webui)
if [[ -z "${clone_dir}" ]]
then
    clone_dir="stable-diffusion-webui"
fi

# Eseguibile di python3
if [[ -z "${python_cmd}" ]]
then
    python_cmd="python3"
fi

# Eseguibile di git
if [[ -z "${GIT}" ]]
then
    export GIT="git"
fi

# Ambiente virtuale di python3 senza barra finale (predefinito su ${install_dir}/${clone_dir}/venv)
if [[ -z "${venv_dir}" ]] && [[ $use_venv -eq 1 ]]
then
    venv_dir="venv"
fi

# Se non specificato, lo script da lanciare è prepare.py
if [[ -z "${LAUNCH_SCRIPT}" ]]
then
    LAUNCH_SCRIPT="prepare.py"
fi

# Questo script non può essere eseguito come root per impostazione predefinita
can_run_as_root=0

# Leggi eventuali flag dalla riga di comando allo script webui.sh
while getopts "f" flag > /dev/null 2>&1
do
    case ${flag} in
        f) can_run_as_root=1;;
        *) break;;
    esac
done

# Disabilita il logging di Sentry
export ERROR_REPORTING=FALSE

# Non reinstallare pacchetti pip esistenti su Debian/Ubuntu
export PIP_IGNORE_INSTALLED=0

# Stampa formattata
delimiter="################################################################"

printf "\n%s\n" "${delimiter}"
printf "\e[1m\e[32mScript di installazione per stable-diffusion + Web UI\n"
printf "\e[1m\e[34mTestato su Debian 11 (Bullseye)\e[0m"
printf "\n%s\n" "${delimiter}"

# Non eseguire come root
if [[ $(id -u) -eq 0 && can_run_as_root -eq 0 ]]
then
    printf "\n%s\n" "${delimiter}"
    printf "\e[1m\e[31mERRORE: Questo script non deve essere avviato come root, abortendo...\e[0m"
    printf "\n%s\n" "${delimiter}"
    exit 1
else
    printf "\n%s\n" "${delimiter}"
    printf "Eseguendo come utente \e[1m\e[32m%s\e[0m" "$(whoami)"
    printf "\n%s\n" "${delimiter}"
fi

# Controllo se si sta eseguendo su un sistema operativo a 32 bit
if [[ $(getconf LONG_BIT) = 32 ]]
then
    printf "\n%s\n" "${delimiter}"
    printf "\e[1m\e[31mERRORE: Esecuzione su un sistema operativo a 32 bit non supportata\e[0m"
    printf "\n%s\n" "${delimiter}"
    exit 1
fi

# Controlla se il repository è già stato clonato
if [[ -d .git ]]
then
    printf "\n%s\n" "${delimiter}"
    printf "Repository già clonato, usando come directory di installazione"
    printf "\n%s\n" "${delimiter}"
    install_dir="${PWD}/../"
    clone_dir="${PWD##*/}"
fi

# Controlla i prerequisiti
gpu_info=$(lspci 2>/dev/null | grep -E "VGA|Display")
case "$gpu_info" in
    *"Navi 1"*)
        export HSA_OVERRIDE_GFX_VERSION=10.3.0
        if [[ -z "${TORCH_COMMAND}" ]]
        then
            pyv="$(${python_cmd} -c 'import sys; print(".".join(map(str, sys.version_info[0:2])))')"
            if [[ $(bc <<< "$pyv <= 3.10") -eq 1 ]] 
            then
                # Gli utenti Navi utilizzeranno ancora torch 1.13 perché 2.0 non sembra funzionare.
                export TORCH_COMMAND="pip install torch==1.13.1+rocm5.2 torchvision==0.14.1+rocm5.2 --index-url https://download.pytorch.org/whl/rocm5.2"
            else
                printf "\e[1m\e[31mERRORE: Le GPU della serie RX 5000 devono utilizzare al massimo python 3.10, abortendo...\e[0m"
                exit 1
            fi
        fi
    ;;
    *"Navi 2"*) export HSA_OVERRIDE_GFX_VERSION=10.3.0
    ;;
    *"Navi 3"*) [[ -z "${TORCH_COMMAND}" ]] && \
         export TORCH_COMMAND="pip install --pre torch torchvision --index-url https://download.pytorch.org/whl/nightly/rocm5.6"
    ;;
    *"Renoir"*) export HSA_OVERRIDE_GFX_VERSION=9.0.0
        printf "\n%s\n" "${delimiter}"
        printf "Supporto sperimentale per Renoir: assicurati di avere almeno 4GB di VRAM e 10GB di RAM oppure abilita la modalità CPU: --use-cpu all --no-half"
        printf "\n%s\n" "${delimiter}"
    ;;
    *)
    ;;
esac
if ! echo "$gpu_info" | grep -q "NVIDIA";
then
    if echo "$gpu_info" | grep -q "AMD" && [[ -z "${TORCH_COMMAND}" ]]
    then
        export TORCH_COMMAND="pip install torch==2.0.1+rocm5.4.2 torchvision==0.15.2+rocm5.4.2 --index-url https://download.pytorch.org/whl/rocm5.4.2"
    fi
fi

# Controlla se i prerequisiti sono installati
for preq in "${GIT}" "${python_cmd}"
do
    if ! hash "${preq}" &>/dev/null
    then
        printf "\n%s\n" "${delimiter}"
        printf "\e[1m\e[31mERRORE: %s non è installato, abortendo...\e[0m" "${preq}"
        printf "\n%s\n" "${delimiter}"
        exit 1
    fi
done

# Controlla se l'ambiente virtuale è disponibile
if [[ $use_venv -eq 1 ]] && ! "${python_cmd}" -c "import venv" &>/dev/null
then
    printf "\n%s\n" "${delimiter}"
    printf "\e[1m\e[31mERRORE: python3-venv non è installato, abortendo...\e[0m"
    printf "\n%s\n" "${delimiter}"
    exit 1
fi

# Cambia directory di lavoro
cd "${install_dir}"/ || { printf "\e[1m\e[31mERRORE: Impossibile accedere a %s/, abortendo...\e[0m" "${install_dir}"; exit 1; }
if [[ -d "${clone_dir}" ]]
then
    cd "${clone_dir}"/ || { printf "\e[1m\e[31mERRORE: Impossibile accedere a %s/%s/, abortando...\e[0m" "${install_dir}" "${clone_dir}"; exit 1; }
else
    printf "\n%s\n" "${delimiter}"
    printf "Clonare stable-diffusion-webui"
    printf "\n%s\n" "${delimiter}"
    "${GIT}" clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git "${clone_dir}"
    cd "${clone_dir}"/ || { printf "\e[1m\e[31mERRORE: Impossibile accedere a %s/%s/, abortando...\e[0m" "${install_dir}" "${clone_dir}"; exit 1; }
    cp ../prepare.py .
fi

# Creare e attivare un ambiente virtuale python
if [[ $use_venv -eq 1 ]] && [[ -z "${VIRTUAL_ENV}" ]];
then
    printf "\n%s\n" "${delimiter}"
    printf "Creando un ambiente virtuale python in %s" "${venv_dir}"
    printf "\n%s\n" "${delimiter}"
    "${python_cmd}" -m venv "${venv_dir}"
    source "${venv_dir}"/bin/activate
else
    printf "\n%s\n" "${delimiter}"
    printf "Ambiente virtuale %s già attivato" "${venv_dir}"
    printf "\n%s\n" "${delimiter}"
fi

# Installa le dipendenze
printf "\n%s\n" "${delimiter}"
printf "Installazione delle dipendenze"
printf "\n%s\n" "${delimiter}"

# Se TORCH_COMMAND è definito, installa torch
if [[ -n "${TORCH_COMMAND}" ]]
then
    printf "Esecuzione di %s\n" "${TORCH_COMMAND}"
    eval "${TORCH_COMMAND}"
fi

# Installa il resto delle dipendenze
pip install -r requirements.txt

# Installazione completata
printf "\n%s\n" "${delimiter}"
printf "Installazione completata, puoi avviare l'interfaccia web eseguendo:\n"
printf "cd %s && bash webui.sh\n" "${clone_dir}"
printf "\n%s\n" "${delimiter}"

# Esegui lo script di lancio
if [[ ! -z "${LAUNCH_SCRIPT}" ]]; then
    printf "\nEsecuzione di %s\n" "${LAUNCH_SCRIPT}"
    exec "${python_cmd}" "${LAUNCH_SCRIPT}"
fi
