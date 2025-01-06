#!/bin/bash

# ---------------------------
# Configuración inicial
# ---------------------------
LOG_EXIM="${LOG_EXIM:-/var/log/exim_mainlog}" # Archivo de log de Exim (personalizable por variable de entorno)
LOG_DOVECOT="${LOG_DOVECOT:-/var/log/maillog}" # Archivo de log de Dovecot
LINES="${LINES:-20}" # Número de líneas a mostrar por defecto
REPORT_FILE="${REPORT_FILE:-/tmp/mail_log_report.txt}" # Ruta del reporte
SHOW_STATS="${SHOW_STATS:-true}" # Activar/desactivar estadísticas básicas
DATE=$(date "+%Y-%m-%d %H:%M:%S")

# Limpia el reporte anterior
echo "=== Reporte de análisis de logs de correo ===" > $REPORT_FILE
echo "Generado el: $DATE" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# ---------------------------
# Función: Mostrar encabezado
# ---------------------------
mostrar_encabezado() {
  echo "" >> $REPORT_FILE
  echo "=== $1 ===" >> $REPORT_FILE
  echo "" >> $REPORT_FILE
}

# ---------------------------
# Función: Analizar errores de inicio de sesión en Dovecot
# ---------------------------
analizar_intentos_fallidos_dovecot() {
  mostrar_encabezado "Errores de inicio de sesión en Dovecot"

  if [ -f "$LOG_DOVECOT" ]; then
    grep "auth.*failed" $LOG_DOVECOT | tail -n $LINES >> $REPORT_FILE
  else
    echo "[ERROR] No se encontró el archivo de log de Dovecot: $LOG_DOVECOT" >> $REPORT_FILE
  fi
}

# ---------------------------
# Función: Detectar ataques de fuerza bruta
# ---------------------------
detectar_ataques_fuerza_bruta_exim() {
  mostrar_encabezado "Posibles ataques de fuerza bruta en Exim"

  if [ -f "$LOG_EXIM" ]; then
    grep "auth.*failed" $LOG_EXIM | awk '{print $NF}' | sort | uniq -c | sort -nr | head -n 10 >> $REPORT_FILE
  else
    echo "[ERROR] No se encontró el archivo de log de Exim: $LOG_EXIM" >> $REPORT_FILE
  fi
}

# ---------------------------
# Función: Analizar errores en envíos y recepción (Exim)
# ---------------------------
analizar_envios_exim() {
  mostrar_encabezado "Errores de envío/recepción en Exim"

  if [ -f "$LOG_EXIM" ]; then
    # Correos rechazados
    echo "Correos rechazados:" >> $REPORT_FILE
    grep "rejected" $LOG_EXIM | tail -n $LINES >> $REPORT_FILE
    echo "" >> $REPORT_FILE

    # Correos pendientes en cola
    echo "Correos en cola:" >> $REPORT_FILE
    exim -bp | awk '{ print $1, $2, $3, $4 }' | column -t >> $REPORT_FILE 2>/dev/null
  else
    echo "[ERROR] No se encontró el archivo de log de Exim: $LOG_EXIM" >> $REPORT_FILE
  fi
}

# ---------------------------
# Función: Mostrar estadísticas básicas (opcional)
# ---------------------------
mostrar_estadisticas() {
  if [ "$SHOW_STATS" = "true" ]; then
    mostrar_encabezado "Estadísticas básicas de Exim"

    if [ -f "$LOG_EXIM" ]; then
      echo "Total de correos enviados: $(grep "=>" $LOG_EXIM | wc -l)" >> $REPORT_FILE
      echo "Total de correos fallidos: $(grep "==" $LOG_EXIM | wc -l)" >> $REPORT_FILE
    else
      echo "[ERROR] No se encontró el archivo de log de Exim: $LOG_EXIM" >> $REPORT_FILE
    fi
  fi
}

# ---------------------------
# Función: Validación de open relay (posible abuso)
# ---------------------------
detectar_open_relay() {
  mostrar_encabezado "Validación de Open Relay"

  if [ -f "$LOG_EXIM" ]; then
    grep "relay not permitted" $LOG_EXIM | tail -n $LINES >> $REPORT_FILE
  else
    echo "[ERROR] No se encontró el archivo de log de Exim: $LOG_EXIM" >> $REPORT_FILE
  fi
}

# ---------------------------
# Función: Generar reporte claro
# ---------------------------
generar_reporte() {
  echo "=== Generación del reporte ==="
  echo "El reporte ha sido guardado en: $REPORT_FILE"
  echo "Contenido del reporte:"
  cat $REPORT_FILE
}

# ---------------------------
# Ejecución del script
# ---------------------------
analizar_intentos_fallidos_dovecot
detectar_ataques_fuerza_bruta_exim
analizar_envios_exim
mostrar_estadisticas
detectar_open_relay
generar_reporte
