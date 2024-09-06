#!/bin/bash

# Variables configurables
WAIT_TIME=600  # 10 minutos de espera para los resultados preliminares de SMART
LOG_DIR="/var/log"
BB_LOG_PREFIX="$LOG_DIR/badblocks"
SMART_LOG_PREFIX="$LOG_DIR/smartctl"
DISK_INFO_LOG="$LOG_DIR/disk_info.log"

# Función para comprobar si smartmontools y badblocks están instalados
check_dependencies_installed() {
    for package in smartmontools e2fsprogs; do
        if ! rpm -q $package &> /dev/null; then
            echo "$package no está instalado. Instalándolo..."
            yum install $package -y
        fi
    done
}

# Función para obtener información básica del disco
get_disk_info() {
    local disk=$1
    local disk_info="$DISK_INFO_LOG"

    echo "==========================="
    echo "Información básica del disco: /dev/$disk"
    echo "==========================="

    # Obtener el modelo del disco
    local model=$(smartctl -i /dev/$disk | grep "Device Model" | awk -F ': ' '{print $2}')
    echo "Modelo del disco: $model" | tee -a $disk_info

    # Obtener la capacidad total del disco
    local capacity=$(smartctl -i /dev/$disk | grep "User Capacity" | awk -F '[[]' '{print $2}' | awk -F ']' '{print $1}')
    echo "Capacidad del disco: $capacity" | tee -a $disk_info

    # Obtener las horas de encendido del disco
    local power_on_hours=$(smartctl -A /dev/$disk | awk '/Power_On_Hours/ {print $10}')
    echo "Horas de encendido: $power_on_hours" | tee -a $disk_info

    echo "Información básica del disco guardada en $disk_info"
}

# Función para obtener información S.M.A.R.T.
get_smart_info() {
    local disk=$1
    local smart_log="$SMART_LOG_PREFIX_$disk.log"

    echo "==========================="
    echo "Información S.M.A.R.T. del disco: /dev/$disk"
    echo "==========================="

    # Comprobar si el disco es compatible con SMART
    if ! smartctl -i /dev/$disk | grep -q "SMART support is: Enabled"; then
        echo "SMART no está habilitado para /dev/$disk o no es soportado."
        return
    fi

    # Ejecutar el test largo SMART
    echo "Ejecutando prueba larga SMART en /dev/$disk (esto puede tardar varias horas)..."
    smartctl -t long /dev/$disk
    echo "Esperando $((WAIT_TIME / 60)) minutos para mostrar resultados preliminares..."
    sleep $WAIT_TIME

    # Mostrar y guardar el resultado preliminar de la prueba S.M.A.R.T.
    echo "Resultados preliminares de la prueba S.M.A.R.T para /dev/$disk:" | tee -a $smart_log
    smartctl -H /dev/$disk | grep "SMART overall-health self-assessment test result" | tee -a $smart_log
    smartctl -A /dev/$disk | grep -E "Reallocated_Sector_Ct|Temperature_Celsius|Power_On_Hours|Power_Cycle_Count" | tee -a $smart_log

    # Verificar sectores reasignados
    local reallocated_sectors=$(smartctl -A /dev/$disk | awk '/Reallocated_Sector_Ct/ {print $10}')
    if [ "$reallocated_sectors" -gt 0 ]; then
        echo "ALERTA: El disco /dev/$disk tiene sectores reasignados ($reallocated_sectors). Esto puede ser indicativo de problemas." | tee -a $smart_log
    fi

    # Verificar temperatura
    local temperature=$(smartctl -A /dev/$disk | awk '/Temperature_Celsius/ {print $10}')
    if [ "$temperature" -gt 50 ]; then
        echo "ALERTA: La temperatura del disco /dev/$disk es elevada ($temperature°C). Revisa la refrigeración." | tee -a $smart_log
    fi

    echo "Prueba S.M.A.R.T. en curso. Puedes revisar el estado completo más tarde con el comando 'smartctl -l selftest /dev/$disk'."
}

# Función para ejecutar badblocks
run_badblocks_test() {
    local disk=$1
    local badblocks_log="$BB_LOG_PREFIX_$disk.log"

    echo "==========================="
    echo "Ejecutando badblocks en /dev/$disk"
    echo "==========================="

    # Nota: Esto es una prueba de solo lectura (no destructiva)
    badblocks -sv /dev/$disk > $badblocks_log
    echo "Prueba de badblocks completada. Revisa los resultados en $badblocks_log"
}

# Función para ejecutar pruebas en paralelo para un disco
run_tests_for_disk() {
    local disk=$1
    get_disk_info $disk &
    get_smart_info $disk &
    run_badblocks_test $disk &
    wait  # Esperar a que todas las pruebas terminen
}

# Función principal para detectar discos montados y ejecutar pruebas
main() {
    check_dependencies_installed
    for disk in $(lsblk -nd --output NAME); do
        run_tests_for_disk $disk &
    done

    wait  # Esperar a que todas las pruebas de todos los discos terminen
    echo "Todas las pruebas han finalizado."
}

# Ejecutar el script principal
main
