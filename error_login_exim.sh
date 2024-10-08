#!/bin/bash

# Función para validar la IP
validar_ip() {
    if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Función para validar el dominio
validar_dominio() {
    if [[ $1 =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Variables para las opciones
ip=""
dominio=""
logfile="/var/log/exim_mainlog"
output=""

# Mostrar ayuda
mostrar_ayuda() {
    echo "Uso: $0 [-i <IP>] [-d <dominio>] [-l <logfile>] [-o <archivo_salida>]"
    echo
    echo "Opciones:"
    echo "  -i    IP que se va a buscar (opcional)"
    echo "  -d    Dominio que se va a buscar (opcional)"
    echo "  -l    Archivo de log de Exim (opcional, por defecto es /var/log/exim_mainlog)"
    echo "  -o    Archivo de salida para guardar los resultados (opcional)"
    echo "  -h    Mostrar esta ayuda"
    exit 1
}

# Parsear los argumentos
while getopts "i:d:l:o:h" opt; do
    case $opt in
        i) ip="$OPTARG" ;;
        d) dominio="$OPTARG" ;;
        l) logfile="$OPTARG" ;;
        o) output="$OPTARG" ;;
        h) mostrar_ayuda ;;
        *) mostrar_ayuda ;;
    esac
done

# Verificar que al menos uno de los dos (IP o dominio) se ingresó
if [[ -z "$ip" && -z "$dominio" ]]; then
    echo "Error: Debes ingresar al menos una IP o un dominio."
    mostrar_ayuda
fi

# Validar IP si fue proporcionada
if [[ -n "$ip" ]]; then
    if ! validar_ip "$ip"; then
        echo "Error: La IP '$ip' no es válida."
        exit 1
    fi
fi

# Validar dominio si fue proporcionado
if [[ -n "$dominio" ]]; then
    if ! validar_dominio "$dominio"; then
        echo "Error: El dominio '$dominio' no es válido."
        exit 1
    fi
fi

# Verificar si el archivo de log existe
if [ ! -f "$logfile" ]; then
    echo "Error: El archivo de log $logfile no existe."
    exit 1
fi

# Buscar errores de autenticación según lo que se haya proporcionado (IP, dominio o ambos)
echo "Buscando fallos de autenticación..."

if [[ -n "$ip" && -n "$dominio" ]]; then
    resultado=$(grep 'authenticator failed' "$logfile" | grep "$ip" | grep "$dominio")
elif [[ -n "$ip" ]]; then
    resultado=$(grep 'authenticator failed' "$logfile" | grep "$ip")
elif [[ -n "$dominio" ]]; then
    resultado=$(grep 'authenticator failed' "$logfile" | grep "$dominio")
fi

# Si hay resultados, mostrar la fecha, hora, dirección IP y correo electrónico en formato más legible
if [ -n "$resultado" ]; then
    echo "Se encontraron los siguientes intentos fallidos:"
    echo "$resultado" | while read -r line; do
        fecha=$(echo "$line" | awk '{print $1, $2, $3}')
        ip=$(echo "$line" | grep -oP '\d+\.\d+\.\d+\.\d+')
        correo=$(echo "$line" | grep -oP '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}')
        
        # Formatear la salida en bloques más claros
        echo "-----------------------------"
        echo "Fecha:     $fecha"
        echo "IP:        ${ip:-No encontrada}"
        echo "Correo:    ${correo:-No encontrado}"
        echo "-----------------------------"
    done
    
    # Guardar en archivo si se especifica
    if [ -n "$output" ]; then
        echo "$resultado" | while read -r line; do
            fecha=$(echo "$line" | awk '{print $1, $2, $3}')
            ip=$(echo "$line" | grep -oP '\d+\.\d+\.\d+\.\d+')
            correo=$(echo "$line" | grep -oP '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}')
            
            # Guardar salida formateada en archivo
            echo "-----------------------------" >> "$output"
            echo "Fecha:     $fecha" >> "$output"
            echo "IP:        ${ip:-No encontrada}" >> "$output"
            echo "Correo:    ${correo:-No encontrado}" >> "$output"
            echo "-----------------------------" >> "$output"
        done
        echo "Resultados guardados en $output."
    fi
else
    echo "No se encontraron errores de autenticación."
fi
