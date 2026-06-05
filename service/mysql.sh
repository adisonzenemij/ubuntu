#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Script: Servicio MySQL
# Objetivo:
#   Administrar el servicio MySQL desde un menú interactivo.
#   Cada bloque está documentado con la opción del menú a la que pertenece.
# ============================================================

SUDO_CMD=""
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  SUDO_CMD="sudo"
fi

SERVICE_NAME="mysql"
PACKAGE_NAME="mysql-server"
DEFAULT_PORT="3306"
CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"

MENU_1="Instalación Servicio"
MENU_2="Consultar Estado"
MENU_3="Iniciar Servicio"
MENU_4="Detener Servicio"
MENU_5="Reiniciar Servicio"
MENU_6="Habilitar Inicio Automático"
MENU_7="Deshabilitar Inicio Automático"
MENU_8="Consultar Versión"
MENU_9="Configurar Puerto"
MENU_10="Configurar Firewall"
MENU_11="Consultar Logs"

run_cmd() {
  echo "+ $*"
  "$@"
}

pause_menu() {
  echo
  read -r -p "Presiona ENTER para continuar..."
}

ask_yes_no() {
  local question="$1"
  local answer

  while true; do
    read -r -p "$question (S/N - Y/N): " answer
    case "${answer,,}" in
      s|si|sí|y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Respuesta no válida." ;;
    esac
  done
}

valid_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" >= 1 && "$1" <= 65535 ))
}

ufw_active() {
  $SUDO_CMD ufw status 2>/dev/null | grep -qi "Status: active\|Estado: activo"
}

allow_firewall_port() {
  local port="$1"

  echo "Configurando reglas UFW para el puerto $port..."
  run_cmd $SUDO_CMD ufw allow "$port"
  run_cmd $SUDO_CMD ufw allow "${port}/tcp"
}

wait_service_ok() {
  local service="$1"

  if $SUDO_CMD systemctl is-active --quiet "$service"; then
    echo "El servicio $service está activo correctamente."
    return 0
  fi

  echo "El servicio $service no está activo. Estado actual:"
  $SUDO_CMD systemctl --no-pager status "$service" || true
  echo
  echo "Últimos logs:"
  $SUDO_CMD journalctl -u "$service" -n 40 --no-pager || true
  return 1
}

print_header() {
  local option_number="$1"
  local option_title="$2"
  echo "----- ${option_number}. ${option_title} -----"
}

# ============================================================
# MENÚ 1: Instalación Servicio
# Instala paquetes, habilita el arranque automático,
# inicia el servicio y muestra una validación básica.
# ============================================================
install_service_flow() {
  print_header "1" "$MENU_1"

  run_cmd $SUDO_CMD apt update -y
  run_cmd $SUDO_CMD apt install "$PACKAGE_NAME" -y

  run_cmd mysql --version || true

  run_cmd $SUDO_CMD systemctl enable --now "$SERVICE_NAME"
  run_cmd $SUDO_CMD systemctl is-enabled "$SERVICE_NAME" || true
  run_cmd $SUDO_CMD systemctl is-active "$SERVICE_NAME" || true
  $SUDO_CMD systemctl --no-pager status "$SERVICE_NAME" || true

  echo
  echo "Instalación del servicio MySQL finalizada."
}

# ============================================================
# MENÚ 2: Consultar Estado
# Consulta si el servicio está activo, habilitado y muestra
# el estado completo con systemctl status.
# ============================================================
check_service_status() {
  print_header "2" "$MENU_2"

  echo "Servicio: $SERVICE_NAME"
  echo

  run_cmd $SUDO_CMD systemctl is-enabled "$SERVICE_NAME" || true
  run_cmd $SUDO_CMD systemctl is-active "$SERVICE_NAME" || true
  echo
  $SUDO_CMD systemctl --no-pager status "$SERVICE_NAME" || true
}

# ============================================================
# MENÚ 3: Iniciar Servicio
# Inicia el servicio y valida que quede activo.
# ============================================================
start_service() {
  print_header "3" "$MENU_3"

  run_cmd $SUDO_CMD systemctl start "$SERVICE_NAME"
  wait_service_ok "$SERVICE_NAME" || true
}

# ============================================================
# MENÚ 4: Detener Servicio
# Detiene el servicio y muestra el estado posterior.
# ============================================================
stop_service() {
  print_header "4" "$MENU_4"

  if ask_yes_no "¿Confirmas detener el servicio $SERVICE_NAME?"; then
    run_cmd $SUDO_CMD systemctl stop "$SERVICE_NAME"
    run_cmd $SUDO_CMD systemctl is-active "$SERVICE_NAME" || true
  else
    echo "Operación cancelada."
  fi
}

# ============================================================
# MENÚ 5: Reiniciar Servicio
# Reinicia el servicio y valida que quede activo.
# ============================================================
restart_service() {
  print_header "5" "$MENU_5"

  run_cmd $SUDO_CMD systemctl restart "$SERVICE_NAME"
  wait_service_ok "$SERVICE_NAME" || true
}

# ============================================================
# MENÚ 6: Habilitar Inicio Automático
# Habilita el servicio para iniciar con el sistema operativo.
# ============================================================
enable_service() {
  print_header "6" "$MENU_6"

  run_cmd $SUDO_CMD systemctl enable "$SERVICE_NAME"
  run_cmd $SUDO_CMD systemctl is-enabled "$SERVICE_NAME" || true
}

# ============================================================
# MENÚ 7: Deshabilitar Inicio Automático
# Deshabilita el arranque automático del servicio.
# No elimina ni detiene el servicio.
# ============================================================
disable_service() {
  print_header "7" "$MENU_7"

  if ask_yes_no "¿Confirmas deshabilitar el inicio automático de $SERVICE_NAME?"; then
    run_cmd $SUDO_CMD systemctl disable "$SERVICE_NAME"
    run_cmd $SUDO_CMD systemctl is-enabled "$SERVICE_NAME" || true
  else
    echo "Operación cancelada."
  fi
}

# ============================================================
# MENÚ 8: Consultar Versión
# Muestra la versión instalada del servicio o herramienta.
# ============================================================
check_service_version() {
  print_header "8" "$MENU_8"

  run_cmd mysql --version || true
}

# ============================================================
# MENÚ 9: Configurar Puerto
# Realiza copia de seguridad del archivo de configuración,
# cambia el puerto del servicio, valida la configuración
# y reinicia el servicio si corresponde.
# ============================================================
configure_service_port() {
  print_header "9" "$MENU_9"

  local new_port
  local backup_file

  echo "Archivo de configuración: $CONFIG_FILE"
  echo "Puerto por defecto: $DEFAULT_PORT"
  echo

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: No existe el archivo de configuración: $CONFIG_FILE"
    echo "Instala primero el servicio desde la opción 1."
    return 1
  fi

  while true; do
    read -r -p "Digite el puerto que desea configurar: " new_port
    if valid_port "$new_port"; then
      break
    fi
    echo "Puerto inválido. Debe estar entre 1 y 65535."
  done

  if ! ask_yes_no "¿Confirmas configurar el puerto $new_port para MySQL?"; then
    echo "Operación cancelada."
    return 0
  fi

  backup_file="${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
  run_cmd $SUDO_CMD cp "$CONFIG_FILE" "$backup_file"
  echo "Copia de seguridad creada en: $backup_file"

  if $SUDO_CMD grep -Eq '^[[:space:]]*port[[:space:]]*=' "$CONFIG_FILE"; then
    run_cmd $SUDO_CMD sed -i "s/^[[:space:]]*port[[:space:]]*=.*/port = ${new_port}/" "$CONFIG_FILE"
  else
    $SUDO_CMD awk -v port="$new_port" '
      BEGIN { done=0 }
      /^\[mysqld\]/ { print; print "port = " port; done=1; next }
      { print }
      END { if (!done) { print "[mysqld]"; print "port = " port } }
    ' "$CONFIG_FILE" | $SUDO_CMD tee "${CONFIG_FILE}.tmp" >/dev/null
    run_cmd $SUDO_CMD mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
  fi

  if command -v mysqld >/dev/null 2>&1; then
    if ! $SUDO_CMD mysqld --validate-config; then
      echo "La configuración MySQL tiene errores. Se abre nano para corregir."
      $SUDO_CMD nano "$CONFIG_FILE"
    fi
  fi

  echo
  echo "Reiniciando servicio para aplicar cambios..."
  run_cmd $SUDO_CMD systemctl restart "$SERVICE_NAME"
  wait_service_ok "$SERVICE_NAME" || true
}

# ============================================================
# MENÚ 10: Configurar Firewall
# Si UFW está activo, abre el puerto indicado para el servicio.
# ============================================================
configure_firewall() {
  print_header "10" "$MENU_10"

  local port

  read -r -p "Digite el puerto que desea permitir en UFW [${DEFAULT_PORT}]: " port
  port="${port:-$DEFAULT_PORT}"

  if ! valid_port "$port"; then
    echo "ERROR: Puerto inválido."
    return 1
  fi

  if ufw_active; then
    allow_firewall_port "$port"
    run_cmd $SUDO_CMD ufw status numbered || true
  else
    echo "Firewall UFW inactivo. No se aplican reglas."
    echo "Para activar UFW manualmente: sudo ufw enable"
  fi
}

# ============================================================
# MENÚ 11: Consultar Logs
# Muestra los últimos registros del servicio usando journalctl.
# ============================================================
check_service_logs() {
  print_header "11" "$MENU_11"

  local lines

  read -r -p "Cantidad de líneas a consultar [80]: " lines
  lines="${lines:-80}"

  if ! [[ "$lines" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Debes ingresar un número válido."
    return 1
  fi

  run_cmd $SUDO_CMD journalctl -u "$SERVICE_NAME" -n "$lines" --no-pager
}

show_menu() {
  clear || true
  echo "=============================================="
  echo "        MENÚ SERVICIO MYSQL - UBUNTU"
  echo "=============================================="
  echo "Usuario actual : $(whoami)"
  echo "Servicio       : $SERVICE_NAME"
  echo "Paquete        : $PACKAGE_NAME"
  echo "Puerto base    : $DEFAULT_PORT"
  echo "=============================================="
  echo "1. $MENU_1"
  echo "2. $MENU_2"
  echo "3. $MENU_3"
  echo "4. $MENU_4"
  echo "5. $MENU_5"
  echo "6. $MENU_6"
  echo "7. $MENU_7"
  echo "8. $MENU_8"
  echo "9. $MENU_9"
  echo "10. $MENU_10"
  echo "11. $MENU_11"
  echo "0. Salir"
  echo "=============================================="
}

main() {
  local option

  while true; do
    show_menu
    read -r -p "Seleccione una opción: " option
    echo

    case "$option" in
      1) install_service_flow; pause_menu ;;
      2) check_service_status; pause_menu ;;
      3) start_service; pause_menu ;;
      4) stop_service; pause_menu ;;
      5) restart_service; pause_menu ;;
      6) enable_service; pause_menu ;;
      7) disable_service; pause_menu ;;
      8) check_service_version; pause_menu ;;
      9) configure_service_port; pause_menu ;;
      10) configure_firewall; pause_menu ;;
      11) check_service_logs; pause_menu ;;
      0) echo "Saliendo del menú del servicio MySQL."; exit 0 ;;
      *) echo "Opción no válida."; pause_menu ;;
    esac
  done
}

main "$@"
