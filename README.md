
Este repositorio contiene una colección de scripts útiles para la administración y el monitoreo de servidores, particularmente aquellos que utilizan cPanel y Exim. Cada script está diseñado para realizar tareas específicas que ayudan a mejorar la seguridad, el rendimiento y la supervisión del servidor.

## Archivos en el Repositorio

### 1. InstallAndHardening.sh

**Descripción**: Script de configuración y endurecimiento para servidores.

**Funciones Principales**:
- Verifica permisos de usuario.
- Crea un archivo de registro para la actividad del script.
- Calcula y crea un tamaño de swap recomendado.
- Actualiza el sistema y configura el puerto SSH.
- Instala cPanel y varios paquetes de ConfigServer.
- Instala y configura `rkhunter` para la detección de rootkits.
- Modifica la configuración de cPanel para aumentar la seguridad.
- Desactiva servicios innecesarios y configura el firewall (CSF).

### 2. smart_test.sh

**Descripción**: Script para realizar pruebas de estado en discos duros utilizando S.M.A.R.T. y badblocks.

**Funciones Principales**:
- Verifica si los paquetes necesarios (`smartmontools`, `e2fsprogs`) están instalados.
- Recopila información sobre cada disco, incluyendo modelo, capacidad y horas de encendido.
- Ejecuta pruebas S.M.A.R.T. y badblocks.
- Monitorea la temperatura del disco y sectores reasignados, generando alertas si es necesario.
- Guarda los resultados en logs para su revisión posterior.

### 3. error_login_exim.sh

**Descripción**: Script para buscar errores de autenticación en el log de Exim.

**Funciones Principales**:
- Valida IPs y dominios ingresados como argumentos.
- Busca errores de autenticación en el archivo de log de Exim.
- Muestra resultados estructurados, incluyendo fecha, IP y correo electrónico asociados.
- Permite guardar los resultados en un archivo de salida especificado.

### 4. cPanelVerify.yml

**Descripción**: Playbook de Ansible para verificar el estado del servidor cPanel.

**Funciones Principales**:
- Recupera información sobre uptime del servidor.
- Calcula la carga de CPU en relación con el número de núcleos.
- Monitorea el uso de disco, RAM y swap.
- Verifica el estado de servicios críticos como CSF y cPHulk.
- Cuenta los correos en cola gestionados por Exim.
- Imprime un reporte detallado con la información recopilada.

