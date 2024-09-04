#!/bin/bash
set -e

# Log file
LOG_FILE="/var/log/cloud-init-script.log"

# Comprobación de permisos
if [[ $EUID -ne 0 ]]; then
    echo "Debes ejecutar este script como root o con permisos de sudo." | tee -a $LOG_FILE
    exit 1
fi

# Variables de configuración
SSH_CONFIG="/etc/ssh/sshd_config"
CPANEL_URL="https://securedownloads.cpanel.net/latest"
RK_VERSION="1.4.6"
RK_FILE="rkhunter-${RK_VERSION}.tar.gz"
RK_URL="http://downloads.sourceforge.net/project/rkhunter/rkhunter/${RK_VERSION}/${RK_FILE}"
RK_DIR="/home/rootkithun"
CSF_FILE="https://gitlab.kiubix.com/giovannicordova/config-files/-/raw/main/CSF%20config%20files/csf.conf"
CPANEL_CONFIG="/var/cpanel/cpanel.config"

# Función para calcular el tamaño de la swap recomendada
calculate_swap_size() {
    local ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local ram_gb=$((ram_kb / 1024 / 1024))

    if [ $ram_gb -le 2 ]; then
        swap_size=$((ram_gb * 2))G
    elif [ $ram_gb -gt 2 ] && [ $ram_gb -lt 8 ]; then
        swap_size=${ram_gb}G
    else
        swap_size="4G"
    fi

    echo $swap_size
}

# Crear swap
create_swap() {
    if ! swapon --show | grep -q "file"; then
        swap_size=$(calculate_swap_size)
        echo "Creando swap de tamaño: $swap_size" | tee -a $LOG_FILE
        /usr/local/cpanel/bin/create-swap --size $swap_size || { echo "Error al crear la swap." | tee -a $LOG_FILE; exit 1; }
        echo "Swap creada exitosamente." | tee -a $LOG_FILE
    else
        echo "Swap ya está creada, omitiendo." | tee -a $LOG_FILE
    fi
}

# Actualización del sistema
dnf update -y || { echo "La actualización del sistema falló." | tee -a $LOG_FILE; exit 1; }
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux || true
dnf clean all || true
dnf update -y || true

# Configuración del puerto SSH a 2244
if grep -q "#Port 22" $SSH_CONFIG; then
    sed -i "s/#Port 22/Port 2244/" $SSH_CONFIG
    systemctl restart sshd
    echo "Puerto SSH cambiado a 2244." | tee -a $LOG_FILE
else
    echo "Puerto SSH ya está configurado, omitiendo." | tee -a $LOG_FILE
fi

# Verificar e instalar cPanel
if ! command -v whmapi1 &> /dev/null; then
    echo "cPanel no está instalado. Procediendo con la instalación." | tee -a $LOG_FILE
    cd /home && { curl -o latest -L $CPANEL_URL || { echo "Descarga de cPanel fallida." | tee -a $LOG_FILE; exit 1; }; }
    sh latest || { echo "Instalación de cPanel fallida." | tee -a $LOG_FILE; exit 1; }
else
    echo "cPanel ya está instalado. Omitiendo la instalación." | tee -a $LOG_FILE
fi

# Función para instalar los paquetes de ConfigServer
install_configserver_package() {
    local package_name=$1
    local package_url="https://download.configserver.com/${package_name}.tgz"

    if [ ! -d "/etc/$package_name" ]; then
        echo "Instalando $package_name..." | tee -a $LOG_FILE
        cd /usr/src || { echo "No se pudo cambiar al directorio /usr/src." | tee -a $LOG_FILE; exit 1; }
        rm -fv ${package_name}.tgz
        wget ${package_url} || { echo "Descarga de $package_name fallida." | tee -a $LOG_FILE; exit 1; }
        tar -xzf ${package_name}.tgz || { echo "Extracción de $package_name fallida." | tee -a $LOG_FILE; exit 1; }
        cd ${package_name} || { echo "No se pudo cambiar al directorio ${package_name}." | tee -a $LOG_FILE; exit 1; }
        sh install.sh || { echo "Instalación de $package_name fallida." | tee -a $LOG_FILE; exit 1; }
        cd /usr/src && rm -Rfv ${package_name}*
        echo "$package_name instalado." | tee -a $LOG_FILE
    else
        echo "$package_name ya está instalado. Omitiendo la instalación." | tee -a $LOG_FILE
    fi
}

# Instalación de paquetes de ConfigServer
packages=("csf" "cmc" "cse" "cmq" "cmm")
for package in "${packages[@]}"; do
    install_configserver_package "$package"
done

# Instalación de rkhunter
if ! command -v rkhunter &> /dev/null; then
    echo "Instalando rkhunter..." | tee -a $LOG_FILE
    wget "${RK_URL}" -O "${RK_FILE}" || { echo "Error: Descarga de Rootkit Hunter fallida." | tee -a $LOG_FILE; exit 1; }
    mkdir -p "${RK_DIR}"
    tar -xvf "${RK_FILE}" -C "${RK_DIR}" || { echo "Error: Extracción de rkhunter fallida." | tee -a $LOG_FILE; exit 1; }
    cd "${RK_DIR}/rkhunter-${RK_VERSION}" || { echo "Error: No se pudo cambiar al directorio ${RK_DIR}/rkhunter-${RK_VERSION}." | tee -a $LOG_FILE; exit 1; }
    ./installer.sh --layout default --install || { echo "Error: Instalación de rkhunter fallida." | tee -a $LOG_FILE; exit 1; }
    echo "rkhunter instalado en ${RK_DIR}." | tee -a $LOG_FILE
    rm -f "../${RK_FILE}"
else
    echo "rkhunter ya está instalado. Omitiendo la instalación." | tee -a $LOG_FILE
fi

# Crear swap
create_swap

# Modificación de la configuración de cPanel
if [ -f "$CPANEL_CONFIG" ]; then
    echo "Modificando configuración de cPanel..." | tee -a $LOG_FILE
    sed -i 's/^referrerblanksafety=.*/referrerblanksafety=1/' "$CPANEL_CONFIG"
    sed -i 's/^referrersafety=.*/referrersafety=1/' "$CPANEL_CONFIG"
    sed -i 's/^resetpass=.*/resetpass=0/' "$CPANEL_CONFIG"
    sed -i 's/^resetpass_sub=.*/resetpass_sub=0/' "$CPANEL_CONFIG"
    sed -i 's/^maxemailsperhour=.*/maxemailsperhour=100/' "$CPANEL_CONFIG"
    /usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings
    echo "Configuración de cPanel modificada." | tee -a $LOG_FILE
else
    echo "No se encontró el archivo de configuración de cPanel." | tee -a $LOG_FILE
fi

# Desactivar servicios innecesarios
echo "Desactivando servicios innecesarios..." | tee -a $LOG_FILE
/bin/systemctl stop bluetooth
/bin/systemctl stop rpcbind
/bin/systemctl disable bluetooth
/bin/systemctl disable rpcbind
echo "Servicios innecesarios desactivados." | tee -a $LOG_FILE

# Configuración de firewall con CSF
directorio_destino="/etc/csf"
mkdir -p "$directorio_destino"
wget -O "$directorio_destino/csf.conf" "$CSF_FILE" || { echo "Error: La descarga del archivo de configuración falló." | tee -a $LOG_FILE; exit 1; }
echo "Descarga exitosa. Archivo de configuración descargado en '$directorio_destino/csf.conf'." | tee -a $LOG_FILE

# Modificación de la configuración de CSF
echo "Modificando configuración de CSF..." | tee -a $LOG_FILE
sed -i 's/^LF_POP3D =.*/LF_POP3D = "10"/' /etc/csf/csf.conf
sed -i 's/^LF_POP3D_PERM =.*/LF_POP3D_PERM = "1"/' /etc/csf/csf.conf
sed -i 's/^LF_IMAPD =.*/LF_IMAPD = "10"/' /etc/csf/csf.conf
sed -i 's/^LF_IMAPD_PERM =.*/LF_IMAPD_PERM = "1"/' /etc/csf/csf.conf
sed -i 's/^LF_SMTPAUTH =.*/LF_SMTPAUTH = "10"/' /etc/csf/csf.conf
sed -i 's/^LF_SMTPAUTH_PERM =.*/LF_SMTPAUTH_PERM = "1"/' /etc/csf/csf.conf
sed -i 's/^DENY_TEMP_IP_LIMIT =.*/DENY_TEMP_IP_LIMIT = "100"/' /etc/csf/csf.conf
echo "Configuración de CSF modificada." | tee -a $LOG_FILE

# Reiniciar CSF para aplicar cambios
systemctl restart csf || { echo "Error: No se pudo reiniciar CSF." | tee -a $LOG_FILE; exit 1; }
echo "CSF reiniciado con éxito." | tee -a $LOG_FILE
