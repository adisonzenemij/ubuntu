#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================================
# Script: ubuntu_sistema_menu_documentado.sh
# Objetivo: Administrar tareas básicas del Sistema Operativo Ubuntu.
# Menú: actualización de librerías/índice, actualización de dependencias,
#       limpieza y consultas básicas del sistema.
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
# Opción 1. Actualizar Librerías
# Objetivo: ejecutar apt update para actualizar el índice/listado
#           de paquetes disponibles en los repositorios.
# ==========================================================
update_package_index() {
  echo "----- 1. Actualizar Librerías -----"
  echo "Esta opción ejecuta apt update para refrescar el índice de paquetes."
  echo
  run_cmd $SUDO_CMD apt update -y
}

# ==========================================================
# Opción 2. Actualizar Dependencias
# Objetivo: ejecutar apt upgrade para actualizar los paquetes instalados.
# ==========================================================
upgrade_installed_packages() {
  echo "----- 2. Actualizar Dependencias -----"
  echo "Esta opción ejecuta apt upgrade para actualizar paquetes instalados."
  echo

  if ask_yes_no "¿Confirmas actualizar las dependencias/paquetes instalados?"; then
    run_cmd $SUDO_CMD apt upgrade -y
  else
    echo "Operación cancelada."
  fi
}

# ==========================================================
# Opción 3. Actualización Completa del Sistema
# Objetivo: ejecutar apt update + apt upgrade en un solo flujo.
# ==========================================================
full_system_update() {
  echo "----- 3. Actualización Completa del Sistema -----"
  echo "Esta opción ejecuta apt update y luego apt upgrade."
  echo

  run_cmd $SUDO_CMD apt update -y

  if ask_yes_no "¿Deseas continuar con apt upgrade?"; then
    run_cmd $SUDO_CMD apt upgrade -y
  else
    echo "Se ejecutó apt update, pero se omitió apt upgrade."
  fi
}

# ==========================================================
# Opción 4. Instalar Paquetes Base
# Objetivo: instalar utilidades comunes para administración del servidor.
# ==========================================================
install_base_packages() {
  echo "----- 4. Instalar Paquetes Base -----"
  echo "Esta opción instala paquetes comunes: curl, wget, git, nano, unzip, ca-certificates, gnupg y lsb-release."
  echo

  if ask_yes_no "¿Confirmas instalar los paquetes base?"; then
    run_cmd $SUDO_CMD apt install -y \
      curl wget git nano unzip ca-certificates gnupg lsb-release software-properties-common
  else
    echo "Operación cancelada."
  fi
}

# ==========================================================
# Opción 5. Limpiar Paquetes No Usados
# Objetivo: liberar espacio eliminando paquetes no requeridos y caché.
# ==========================================================
clean_unused_packages() {
  echo "----- 5. Limpiar Paquetes No Usados -----"
  echo "Esta opción ejecuta apt autoremove y apt autoclean."
  echo

  if ask_yes_no "¿Confirmas limpiar paquetes no usados y caché?"; then
    run_cmd $SUDO_CMD apt autoremove -y
    run_cmd $SUDO_CMD apt autoclean -y
  else
    echo "Operación cancelada."
  fi
}

# ==========================================================
# Opción 6. Consultar Información del Sistema
# Objetivo: mostrar datos básicos del sistema operativo y kernel.
# ==========================================================
show_system_info() {
  echo "----- 6. Consultar Información del Sistema -----"
  echo

  if command -v lsb_release >/dev/null 2>&1; then
    run_cmd lsb_release -a || true
  else
    echo "lsb_release no está instalado. Mostrando /etc/os-release:"
    cat /etc/os-release || true
  fi

  echo
  run_cmd uname -a
  echo
  run_cmd uptime
}

# ==========================================================
# Opción 7. Consultar Espacio en Disco
# Objetivo: mostrar uso del almacenamiento del servidor.
# ==========================================================
show_disk_usage() {
  echo "----- 7. Consultar Espacio en Disco -----"
  echo
  run_cmd df -h
}

# ==========================================================
# Opción 8. Consultar Memoria RAM
# Objetivo: mostrar uso actual de memoria RAM.
# ==========================================================
show_memory_usage() {
  echo "----- 8. Consultar Memoria RAM -----"
  echo
  run_cmd free -h
}

# ==========================================================
# Menú principal
# Objetivo: mostrar opciones disponibles del Sistema Operativo.
# ==========================================================
show_menu() {
  clear || true
  echo "=============================================="
  echo "        MENÚ SISTEMA OPERATIVO UBUNTU"
  echo "=============================================="
  echo "Usuario actual : $(whoami)"
  echo "HOME           : $HOME"
  echo "=============================================="
  echo "1. Actualizar Librerías"
  echo "2. Actualizar Dependencias"
  echo "3. Actualización Completa del Sistema"
  echo "4. Instalar Paquetes Base"
  echo "5. Limpiar Paquetes No Usados"
  echo "6. Consultar Información del Sistema"
  echo "7. Consultar Espacio en Disco"
  echo "8. Consultar Memoria RAM"
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
      1) update_package_index; pause_menu ;;
      2) upgrade_installed_packages; pause_menu ;;
      3) full_system_update; pause_menu ;;
      4) install_base_packages; pause_menu ;;
      5) clean_unused_packages; pause_menu ;;
      6) show_system_info; pause_menu ;;
      7) show_disk_usage; pause_menu ;;
      8) show_memory_usage; pause_menu ;;
      0) echo "Saliendo del menú Sistema Operativo Ubuntu."; exit 0 ;;
      *) echo "Opción no válida."; pause_menu ;;
    esac
  done
}

main "$@"
