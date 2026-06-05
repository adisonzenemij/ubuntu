#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================================
# Script: ubuntu_firewall_menu_documentado.sh
# Objetivo: Administrar el firewall UFW en Ubuntu mediante menú.
# Menú: activar, desactivar, agregar puertos, eliminar puertos,
#       consultar estado, reglas, recargar y resetear firewall.
# ==========================================================

SUDO_CMD=""
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  SUDO_CMD="sudo"
fi

# ==========================================================
# Bloque común: ejecución visible de comandos
# Pertenece a: uso general del script
# ==========================================================
run_cmd() {
  echo "+ $*"
  "$@"
}

# ==========================================================
# Bloque común: pausa del menú
# Pertenece a: uso general del script
# ==========================================================
pause_menu() {
  echo
  read -r -p "Presiona ENTER para continuar..."
}

# ==========================================================
# Bloque común: pregunta S/N
# Pertenece a: confirmaciones del menú
# ==========================================================
ask_yes_no() {
  local prompt="$1" answer

  while true; do
    read -r -p "$prompt (S/N - Y/N): " answer
    case "${answer,,}" in
      s|si|sí|y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Respuesta no válida. Escribe S, N, Y o N." ;;
    esac
  done
}

# ==========================================================
# Bloque común: validar puerto TCP/UDP
# Pertenece a: opciones de agregar/eliminar puertos
# ==========================================================
valid_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 ))
}

# ==========================================================
# Bloque común: validar protocolo
# Pertenece a: opciones de agregar/eliminar puertos
# ==========================================================
valid_protocol() {
  [[ "$1" == "tcp" || "$1" == "udp" || "$1" == "both" ]]
}

# ==========================================================
# Bloque común: solicitar puerto válido
# Pertenece a: opciones de agregar/eliminar puertos
# ==========================================================
read_port() {
  local port

  while true; do
    read -r -p "Digite el puerto: " port
    if valid_port "$port"; then
      echo "$port"
      return 0
    fi
    echo "Puerto inválido. Debe estar entre 1 y 65535."
  done
}

# ==========================================================
# Bloque común: solicitar protocolo válido
# Pertenece a: opciones de agregar/eliminar puertos
# ==========================================================
read_protocol() {
  local protocol

  while true; do
    read -r -p "Protocolo tcp, udp o both: " protocol
    protocol="${protocol,,}"

    if valid_protocol "$protocol"; then
      echo "$protocol"
      return 0
    fi

    echo "Protocolo inválido. Usa: tcp, udp o both."
  done
}

# ==========================================================
# Bloque común: instalar UFW si no existe
# Pertenece a: opciones que requieren firewall
# ==========================================================
ensure_ufw_installed() {
  if ! command -v ufw >/dev/null 2>&1; then
    echo "ufw no está instalado. Instalando ufw..."
    run_cmd $SUDO_CMD apt update -y
    run_cmd $SUDO_CMD apt install ufw -y
  fi
}

# ==========================================================
# Opción 1. Instalar Firewall UFW
# Objetivo: instalar el paquete ufw si no existe.
# ==========================================================
install_firewall() {
  echo "----- 1. Instalar Firewall UFW -----"
  echo
  ensure_ufw_installed
  run_cmd $SUDO_CMD ufw version || true
}

# ==========================================================
# Opción 2. Activar Firewall
# Objetivo: habilitar UFW.
# ==========================================================
enable_firewall() {
  echo "----- 2. Activar Firewall -----"
  echo
  ensure_ufw_installed

  echo "IMPORTANTE: si estás conectado por SSH, verifica que el puerto SSH esté permitido antes de activar UFW."
  if ask_yes_no "¿Confirmas activar el firewall?"; then
    run_cmd $SUDO_CMD ufw --force enable
    run_cmd $SUDO_CMD ufw status verbose
  else
    echo "Operación cancelada."
  fi
}

# ==========================================================
# Opción 3. Desactivar Firewall
# Objetivo: deshabilitar UFW sin eliminar reglas.
# ==========================================================
disable_firewall() {
  echo "----- 3. Desactivar Firewall -----"
  echo
  ensure_ufw_installed

  if ask_yes_no "¿Confirmas desactivar el firewall?"; then
    run_cmd $SUDO_CMD ufw disable
    run_cmd $SUDO_CMD ufw status
  else
    echo "Operación cancelada."
  fi
}

# ==========================================================
# Opción 4. Agregar Puertos
# Objetivo: permitir tráfico por puerto y protocolo.
# ==========================================================
add_ports() {
  echo "----- 4. Agregar Puertos -----"
  echo
  ensure_ufw_installed

  while true; do
    local port protocol
    port="$(read_port)"
    protocol="$(read_protocol)"

    case "$protocol" in
      tcp) run_cmd $SUDO_CMD ufw allow "${port}/tcp" ;;
      udp) run_cmd $SUDO_CMD ufw allow "${port}/udp" ;;
      both)
        run_cmd $SUDO_CMD ufw allow "${port}/tcp"
        run_cmd $SUDO_CMD ufw allow "${port}/udp"
        ;;
    esac

    ask_yes_no "¿Deseas agregar otro puerto?" || break
  done

  run_cmd $SUDO_CMD ufw status numbered
}

# ==========================================================
# Opción 5. Eliminar Puertos
# Objetivo: eliminar reglas por puerto/protocolo.
# ==========================================================
remove_ports() {
  echo "----- 5. Eliminar Puertos -----"
  echo
  ensure_ufw_installed

  while true; do
    local port protocol
    port="$(read_port)"
    protocol="$(read_protocol)"

    case "$protocol" in
      tcp) run_cmd $SUDO_CMD ufw delete allow "${port}/tcp" || true ;;
      udp) run_cmd $SUDO_CMD ufw delete allow "${port}/udp" || true ;;
      both)
        run_cmd $SUDO_CMD ufw delete allow "${port}/tcp" || true
        run_cmd $SUDO_CMD ufw delete allow "${port}/udp" || true
        ;;
    esac

    ask_yes_no "¿Deseas eliminar otro puerto?" || break
  done

  run_cmd $SUDO_CMD ufw status numbered
}

# ==========================================================
# Opción 6. Consultar Estado Firewall
# Objetivo: mostrar estado general y detalle de UFW.
# ==========================================================
show_firewall_status() {
  echo "----- 6. Consultar Estado Firewall -----"
  echo
  ensure_ufw_installed
  run_cmd $SUDO_CMD ufw status verbose
}

# ==========================================================
# Opción 7. Listar Reglas Numeradas
# Objetivo: listar reglas con número para eliminación manual.
# ==========================================================
show_numbered_rules() {
  echo "----- 7. Listar Reglas Numeradas -----"
  echo
  ensure_ufw_installed
  run_cmd $SUDO_CMD ufw status numbered
}

# ==========================================================
# Opción 8. Eliminar Regla por Número
# Objetivo: eliminar una regla específica usando el número mostrado por UFW.
# ==========================================================
delete_rule_by_number() {
  echo "----- 8. Eliminar Regla por Número -----"
  echo
  ensure_ufw_installed
  run_cmd $SUDO_CMD ufw status numbered
  echo

  local rule_number
  read -r -p "Digite el número de la regla a eliminar: " rule_number

  if [[ ! "$rule_number" =~ ^[0-9]+$ ]]; then
    echo "Número de regla inválido."
    return 1
  fi

  if ask_yes_no "¿Confirmas eliminar la regla número ${rule_number}?"; then
    run_cmd $SUDO_CMD ufw --force delete "$rule_number"
    run_cmd $SUDO_CMD ufw status numbered
  else
    echo "Operación cancelada."
  fi
}

# ==========================================================
# Opción 9. Permitir Servicio Predefinido
# Objetivo: permitir perfiles conocidos como OpenSSH o Nginx Full.
# ==========================================================
allow_predefined_service() {
  echo "----- 9. Permitir Servicio Predefinido -----"
  echo
  ensure_ufw_installed

  echo "Perfiles disponibles:"
  run_cmd $SUDO_CMD ufw app list || true
  echo

  local app_name
  read -r -p "Digite el nombre exacto del perfil a permitir, ejemplo OpenSSH o 'Nginx Full': " app_name

  if [[ -z "${app_name// }" ]]; then
    echo "No ingresaste ningún perfil."
    return 1
  fi

  run_cmd $SUDO_CMD ufw allow "$app_name"
  run_cmd $SUDO_CMD ufw status verbose
}

# ==========================================================
# Opción 10. Recargar Firewall
# Objetivo: recargar reglas de UFW.
# ==========================================================
reload_firewall() {
  echo "----- 10. Recargar Firewall -----"
  echo
  ensure_ufw_installed
  run_cmd $SUDO_CMD ufw reload
  run_cmd $SUDO_CMD ufw status verbose
}

# ==========================================================
# Opción 11. Resetear Firewall
# Objetivo: eliminar reglas y volver UFW a su estado inicial.
# ==========================================================
reset_firewall() {
  echo "----- 11. Resetear Firewall -----"
  echo
  ensure_ufw_installed

  echo "ADVERTENCIA: esta opción elimina las reglas configuradas en UFW."
  if ask_yes_no "¿Confirmas resetear el firewall?"; then
    run_cmd $SUDO_CMD ufw --force reset
    run_cmd $SUDO_CMD ufw status
  else
    echo "Operación cancelada."
  fi
}

# ==========================================================
# Opción 12. Consultar Versión UFW
# Objetivo: mostrar versión instalada de UFW.
# ==========================================================
show_firewall_version() {
  echo "----- 12. Consultar Versión UFW -----"
  echo
  ensure_ufw_installed
  run_cmd $SUDO_CMD ufw version || true
}

# ==========================================================
# Menú principal
# Objetivo: mostrar opciones disponibles del firewall.
# ==========================================================
show_menu() {
  clear || true
  echo "=============================================="
  echo "        MENÚ FIREWALL UFW - UBUNTU"
  echo "=============================================="
  echo "Usuario actual : $(whoami)"
  echo "HOME           : $HOME"
  echo "=============================================="
  echo "1. Instalar Firewall UFW"
  echo "2. Activar Firewall"
  echo "3. Desactivar Firewall"
  echo "4. Agregar Puertos"
  echo "5. Eliminar Puertos"
  echo "6. Consultar Estado Firewall"
  echo "7. Listar Reglas Numeradas"
  echo "8. Eliminar Regla por Número"
  echo "9. Permitir Servicio Predefinido"
  echo "10. Recargar Firewall"
  echo "11. Resetear Firewall"
  echo "12. Consultar Versión UFW"
  echo "0. Salir"
  echo "=============================================="
}

# ==========================================================
# Ejecución principal
# Objetivo: controlar el ciclo del menú.
# ==========================================================
main() {
  local option

  while true; do
    show_menu
    read -r -p "Seleccione una opción: " option
    echo

    case "$option" in
      1) install_firewall; pause_menu ;;
      2) enable_firewall; pause_menu ;;
      3) disable_firewall; pause_menu ;;
      4) add_ports; pause_menu ;;
      5) remove_ports; pause_menu ;;
      6) show_firewall_status; pause_menu ;;
      7) show_numbered_rules; pause_menu ;;
      8) delete_rule_by_number; pause_menu ;;
      9) allow_predefined_service; pause_menu ;;
      10) reload_firewall; pause_menu ;;
      11) reset_firewall; pause_menu ;;
      12) show_firewall_version; pause_menu ;;
      0) echo "Saliendo del menú Firewall UFW."; exit 0 ;;
      *) echo "Opción no válida."; pause_menu ;;
    esac
  done
}

main "$@"
