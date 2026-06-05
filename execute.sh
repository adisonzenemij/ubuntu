#!/usr/bin/env bash
set -Eeuo pipefail

# Main launcher for the Ubuntu server scripts.
# It groups the existing scripts by folder and runs each one as a submenu option.

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pause_menu() {
  echo
  read -r -p "Presiona ENTER para continuar..."
}

show_header() {
  local title="$1"

  clear || true
  echo "=============================================="
  echo "        $title"
  echo "=============================================="
}

run_script() {
  local script_path="$1"

  if [[ ! -f "$script_path" ]]; then
    echo "ERROR: No existe el archivo: $script_path"
    return 1
  fi

  echo "Ejecutando: $script_path"
  echo
  bash "$script_path"
}

folder_menu() {
  local title="$1"
  local folder="$2"
  local folder_path="$BASE_DIR/$folder"
  local option
  local scripts=()
  local script

  if [[ ! -d "$folder_path" ]]; then
    echo "ERROR: No existe la carpeta: $folder_path"
    pause_menu
    return 1
  fi

  while true; do
    scripts=()
    shopt -s nullglob
    for script in "$folder_path"/*.sh; do
      scripts+=("$script")
    done
    shopt -u nullglob

    show_header "$title"

    if (( ${#scripts[@]} == 0 )); then
      echo "No hay archivos .sh en: $folder_path"
      echo "0. Volver"
      echo "=============================================="
      read -r -p "Selecciona una opcion: " option
      [[ "$option" == "0" ]] && return 0
      echo "Opcion no valida."
      pause_menu
      continue
    fi

    local i
    for i in "${!scripts[@]}"; do
      echo "$((i + 1)). $(basename "${scripts[$i]}")"
    done
    echo "0. Volver"
    echo "=============================================="
    read -r -p "Selecciona una opcion: " option
    echo

    if [[ "$option" == "0" ]]; then
      return 0
    fi

    if [[ "$option" =~ ^[0-9]+$ ]] && (( option >= 1 && option <= ${#scripts[@]} )); then
      run_script "${scripts[$((option - 1))]}"
      pause_menu
    else
      echo "Opcion no valida."
      pause_menu
    fi
  done
}

show_main_menu() {
  show_header "MENU PRINCIPAL UBUNTU"
  echo "1. Defecto"
  echo "2. Servicios"
  echo "3. Librerias"
  echo "4. Git"
  echo "0. Salir"
  echo "=============================================="
}

main() {
  local option

  while true; do
    show_main_menu
    read -r -p "Selecciona una opcion: " option
    echo

    case "$option" in
      1) folder_menu "SUBMENU DEFECTO" "default" ;;
      2) folder_menu "SUBMENU SERVICIOS" "service" ;;
      3) folder_menu "SUBMENU LIBRERIAS" "library" ;;
      4) folder_menu "SUBMENU GIT" "git" ;;
      0) echo "Saliendo del menu principal."; exit 0 ;;
      *) echo "Opcion no valida."; pause_menu ;;
    esac
  done
}

main "$@"
