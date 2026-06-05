#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Script: Servicio Apache
# Objetivo:
#   Administrar Apache2 desde un menu interactivo en Ubuntu.
#   Sigue la misma logica general del script de Nginx.
# ============================================================

SUDO_CMD=""
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  SUDO_CMD="sudo"
fi

SERVICE_NAME="apache2"
PACKAGE_NAME="apache2"
DEFAULT_PORT="80"
PORTS_FILE="/etc/apache2/ports.conf"
VHOST_FILE="/etc/apache2/sites-available/000-default.conf"

MENU_1="Instalacion Servicio"
MENU_2="Desintalar Servicio"
MENU_3="Consultar Estado"
MENU_4="Iniciar Servicio"
MENU_5="Detener Servicio"
MENU_6="Reiniciar Servicio"
MENU_7="Habilitar Inicio Automatico"
MENU_8="Inactivar Inicio Automatico"
MENU_9="Consultar Version"
MENU_10="Configurar Puerto"
MENU_11="Configurar Firewall"
MENU_12="Consultar Logs"
MENU_13="Validar Configuracion"

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
      s|si|y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Respuesta no valida." ;;
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
    echo "El servicio $service esta activo correctamente."
    return 0
  fi

  echo "El servicio $service no esta activo. Estado actual:"
  $SUDO_CMD systemctl --no-pager status "$service" || true
  echo
  echo "Ultimos logs:"
  $SUDO_CMD journalctl -u "$service" -n 40 --no-pager || true
  return 1
}

print_header() {
  local option_number="$1"
  local option_title="$2"
  echo "----- ${option_number}. ${option_title} -----"
}

apache_configtest() {
  run_cmd $SUDO_CMD apache2ctl configtest
}

# ============================================================
# MENU 1: Instalacion Servicio
# ============================================================
install_service_flow() {
  print_header "1" "$MENU_1"

  run_cmd $SUDO_CMD apt update -y
  run_cmd $SUDO_CMD apt install "$PACKAGE_NAME" -y

  run_cmd apache2 -v || true
  apache_configtest || true

  run_cmd $SUDO_CMD systemctl enable --now "$SERVICE_NAME"
  run_cmd $SUDO_CMD systemctl is-enabled "$SERVICE_NAME" || true
  run_cmd $SUDO_CMD systemctl is-active "$SERVICE_NAME" || true
  $SUDO_CMD systemctl --no-pager status "$SERVICE_NAME" || true

  echo
  echo "Instalacion del servicio Apache finalizada."
}

# ============================================================
# MENU 2: Desintalar Servicio
# ============================================================
uninstall_service_flow() {
  print_header "2" "$MENU_2"

  if ! ask_yes_no "Confirmas desinstalar Apache2 y purgar sus paquetes?"; then
    echo "Operacion cancelada."
    return 0
  fi

  run_cmd $SUDO_CMD systemctl stop "$SERVICE_NAME" || true
  run_cmd $SUDO_CMD systemctl disable "$SERVICE_NAME" || true
  run_cmd $SUDO_CMD apt purge "$PACKAGE_NAME" -y
  run_cmd $SUDO_CMD apt autoremove -y
  run_cmd $SUDO_CMD systemctl daemon-reload

  echo "Desinstalacion de Apache finalizada."
}

# ============================================================
# MENU 3: Consultar Estado
# ============================================================
check_service_status() {
  print_header "3" "$MENU_3"

  echo "Servicio: $SERVICE_NAME"
  echo

  run_cmd $SUDO_CMD systemctl is-enabled "$SERVICE_NAME" || true
  run_cmd $SUDO_CMD systemctl is-active "$SERVICE_NAME" || true
  echo
  $SUDO_CMD systemctl --no-pager status "$SERVICE_NAME" || true
}

# ============================================================
# MENU 4: Iniciar Servicio
# ============================================================
start_service() {
  print_header "4" "$MENU_4"

  run_cmd $SUDO_CMD systemctl start "$SERVICE_NAME"
  wait_service_ok "$SERVICE_NAME" || true
}

# ============================================================
# MENU 5: Detener Servicio
# ============================================================
stop_service() {
  print_header "5" "$MENU_5"

  if ask_yes_no "Confirmas detener el servicio $SERVICE_NAME?"; then
    run_cmd $SUDO_CMD systemctl stop "$SERVICE_NAME"
    run_cmd $SUDO_CMD systemctl is-active "$SERVICE_NAME" || true
  else
    echo "Operacion cancelada."
  fi
}

# ============================================================
# MENU 6: Reiniciar Servicio
# ============================================================
restart_service() {
  print_header "6" "$MENU_6"

  apache_configtest
  run_cmd $SUDO_CMD systemctl restart "$SERVICE_NAME"
  wait_service_ok "$SERVICE_NAME" || true
}

# ============================================================
# MENU 7: Habilitar Inicio Automatico
# ============================================================
enable_service() {
  print_header "7" "$MENU_7"

  run_cmd $SUDO_CMD systemctl enable "$SERVICE_NAME"
  run_cmd $SUDO_CMD systemctl is-enabled "$SERVICE_NAME" || true
}

# ============================================================
# MENU 8: Inactivar Inicio Automatico
# ============================================================
disable_service() {
  print_header "8" "$MENU_8"

  if ask_yes_no "Confirmas deshabilitar el inicio automatico de $SERVICE_NAME?"; then
    run_cmd $SUDO_CMD systemctl disable "$SERVICE_NAME"
    run_cmd $SUDO_CMD systemctl is-enabled "$SERVICE_NAME" || true
  else
    echo "Operacion cancelada."
  fi
}

# ============================================================
# MENU 9: Consultar Version
# ============================================================
check_service_version() {
  print_header "9" "$MENU_9"

  run_cmd apache2 -v || true
  run_cmd apache2ctl -v || true
}

# ============================================================
# MENU 10: Configurar Puerto
# ============================================================
configure_service_port() {
  print_header "10" "$MENU_10"

  local new_port
  local ports_backup
  local vhost_backup

  echo "Archivo de puertos : $PORTS_FILE"
  echo "VirtualHost base   : $VHOST_FILE"
  echo "Puerto por defecto : $DEFAULT_PORT"
  echo

  if [[ ! -f "$PORTS_FILE" ]]; then
    echo "ERROR: No existe el archivo de configuracion: $PORTS_FILE"
    echo "Instala primero el servicio desde la opcion 1."
    return 1
  fi

  if [[ ! -f "$VHOST_FILE" ]]; then
    echo "ERROR: No existe el archivo VirtualHost: $VHOST_FILE"
    echo "Instala primero el servicio desde la opcion 1."
    return 1
  fi

  while true; do
    read -r -p "Digite el puerto que desea configurar: " new_port
    if valid_port "$new_port"; then
      break
    fi
    echo "Puerto invalido. Debe estar entre 1 y 65535."
  done

  if ! ask_yes_no "Confirmas configurar el puerto $new_port para Apache?"; then
    echo "Operacion cancelada."
    return 0
  fi

  ports_backup="${PORTS_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
  vhost_backup="${VHOST_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
  run_cmd $SUDO_CMD cp "$PORTS_FILE" "$ports_backup"
  run_cmd $SUDO_CMD cp "$VHOST_FILE" "$vhost_backup"
  echo "Copias de seguridad:"
  echo "- $ports_backup"
  echo "- $vhost_backup"

  run_cmd $SUDO_CMD sed -i -E \
    "s/^[[:space:]]*Listen[[:space:]]+[0-9]+/Listen ${new_port}/g" \
    "$PORTS_FILE"

  run_cmd $SUDO_CMD sed -i -E \
    "s/<VirtualHost[[:space:]]+\\*:[0-9]+>/<VirtualHost *:${new_port}>/g" \
    "$VHOST_FILE"

  if ! $SUDO_CMD apache2ctl configtest; then
    echo "La configuracion Apache tiene errores. Se abre nano para corregir."
    $SUDO_CMD nano "$PORTS_FILE"
    $SUDO_CMD nano "$VHOST_FILE"
    until $SUDO_CMD apache2ctl configtest; do
      echo "Aun existen errores. Corrige antes de continuar."
      $SUDO_CMD nano "$PORTS_FILE"
      $SUDO_CMD nano "$VHOST_FILE"
    done
  fi

  echo
  echo "Reiniciando servicio para aplicar cambios..."
  run_cmd $SUDO_CMD systemctl restart "$SERVICE_NAME"
  wait_service_ok "$SERVICE_NAME" || true
}

# ============================================================
# MENU 11: Configurar Firewall
# ============================================================
configure_firewall() {
  print_header "11" "$MENU_11"

  local port

  read -r -p "Digite el puerto que desea permitir en UFW [${DEFAULT_PORT}]: " port
  port="${port:-$DEFAULT_PORT}"

  if ! valid_port "$port"; then
    echo "ERROR: Puerto invalido."
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
# MENU 12: Consultar Logs
# ============================================================
check_service_logs() {
  print_header "12" "$MENU_12"

  local lines

  read -r -p "Cantidad de lineas a consultar [80]: " lines
  lines="${lines:-80}"

  if ! [[ "$lines" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Debes ingresar un numero valido."
    return 1
  fi

  echo "Logs systemd:"
  run_cmd $SUDO_CMD journalctl -u "$SERVICE_NAME" -n "$lines" --no-pager
  echo
  echo "Logs Apache:"
  run_cmd $SUDO_CMD tail -n "$lines" /var/log/apache2/error.log || true
  run_cmd $SUDO_CMD tail -n "$lines" /var/log/apache2/access.log || true
}

# ============================================================
# MENU 13: Validar Configuracion
# ============================================================
validate_service_config() {
  print_header "13" "$MENU_13"

  apache_configtest
  echo
  echo "Sitios habilitados:"
  run_cmd $SUDO_CMD apache2ctl -S || true
}

show_menu() {
  clear || true
  echo "=============================================="
  echo "        MENU SERVICIO APACHE - UBUNTU"
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
  echo "12. $MENU_12"
  echo "13. $MENU_13"
  echo "0. Salir"
  echo "=============================================="
}

main() {
  local option

  while true; do
    show_menu
    read -r -p "Seleccione una opcion: " option
    echo

    case "$option" in
      1) install_service_flow; pause_menu ;;
      2) uninstall_service_flow; pause_menu ;;
      3) check_service_status; pause_menu ;;
      4) start_service; pause_menu ;;
      5) stop_service; pause_menu ;;
      6) restart_service; pause_menu ;;
      7) enable_service; pause_menu ;;
      8) disable_service; pause_menu ;;
      9) check_service_version; pause_menu ;;
      10) configure_service_port; pause_menu ;;
      11) configure_firewall; pause_menu ;;
      12) check_service_logs; pause_menu ;;
      13) validate_service_config; pause_menu ;;
      0) echo "Saliendo del menu del servicio Apache."; exit 0 ;;
      *) echo "Opcion no valida."; pause_menu ;;
    esac
  done
}

main "$@"
