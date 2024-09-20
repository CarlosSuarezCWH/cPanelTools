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
    echo "Uso: $0 -i <IP> -d <dominio> [-l <logfile>] [-o <archivo_salida>]"
    echo
    echo "Opciones:"
    echo "  -i    IP que se va a buscar"
    echo "  -d    Dominio que se va a buscar"
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

# Verificar que se ingresaron los parámetros obligatorios
if [[ -z "$ip" || -z "$dominio" ]]; then
    echo "Error: Debes ingresar tanto una IP como un dominio."
    mostrar_ayuda
fi

# Validar IP y dominio
if ! validar_ip "$ip"; then
    echo "Error: La IP '$ip' no es válida."
    exit 1
fi

if ! validar_dominio "$dominio"; then
    echo "Error: El dominio '$dominio' no es válido."
    exit 1
fi

# Verificar si el archivo de log existe
if [ ! -f "$logfile" ]; then
    echo "Error: El archivo de log $logfile no existe."
    exit 1
fi

# Buscar errores de autenticación
echo "Buscando fallos de autenticación para la IP $ip y el dominio $dominio en $logfile..."

# Construimos el comando de búsqueda
resultado=$(grep 'authenticator failed' "$logfile" | grep "$ip" | egrep -o "[a-zA-Z0-9._%+-]+@$dominio")

# Si hay resultados, mostrar o guardar en archivo
if [ -n "$resultado" ]; then
    if [ -n "$output" ]; then
        echo "$resultado" > "$output"
        echo "Resultados guardados en $output."
    else
        echo "$resultado"
    fi
else
    echo "No se encontraron errores de autenticación para la IP $ip y el dominio $dominio."
fi
