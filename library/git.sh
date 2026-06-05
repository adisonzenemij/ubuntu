#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Script: lib_git_menu_documentado.sh
# Objetivo: Administrar instalación y configuración global de Git
# Sistema Operativo: Ubuntu / Debian
# ============================================================

SUDO_CMD=""
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  SUDO_CMD="sudo"
fi

# ============================================================
# Variables de menú
# Estos títulos se reutilizan en el menú y en cada bloque para
# evitar diferencias entre el nombre de la opción y su ejecución.
# ============================================================
MENU_1="Instalación Git"
MENU_2="Configurar Nombre de Usuario"
MENU_3="Configurar Email de Usuario"
MENU_4="Configurar Credencial"
MENU_5="Configurar Safe Directory"
MENU_6="Consultar Configuración"
MENU_7="Consultar Versión Git"
MENU_8="Eliminar Configuración de Usuario"
MENU_9="Probar Configuración Básica"
MENU_10="Instalación y Configuración Completa"
MENU_0="Salir"

# ============================================================
# Función común: Ejecutar comando mostrando qué se ejecuta
# ============================================================
run_cmd() {
  echo "+ $*"
  "$@"
}

# ============================================================
# Función común: Pausa para volver al menú
# ============================================================
pause_menu() {
  echo
  read -r -p "Presiona ENTER para continuar..."
}

# ============================================================
# Función común: Pregunta Sí/No
# ============================================================
ask_yes_no() {
  local prompt="$1"
  local answer

  while true; do
    read -r -p "$prompt (S/N - Y/N): " answer
    case "${answer,,}" in
      s|si|sí|y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Respuesta no válida. Escribe S, N, Y o No." ;;
    esac
  done
}

# ============================================================
# Función común: Validar si Git está instalado
# ============================================================
ensure_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: Git no está instalado o no está disponible en PATH."
    echo "Ejecuta primero la opción 1: ${MENU_1}."
    return 1
  fi
}

# ============================================================
# Opción 1: Instalación Git
# Instala Git desde los repositorios del sistema operativo.
# ============================================================
install_git_flow() {
  echo "----- ${MENU_1} -----"
  echo "Se actualizará el índice de paquetes y se instalará Git."
  echo

  run_cmd $SUDO_CMD apt update -y
  run_cmd $SUDO_CMD apt install git -y

  echo
  echo "Validando instalación:"
  run_cmd git --version
}

# ============================================================
# Opción 2: Configurar Nombre de Usuario
# Configura git config --global user.name.
# ============================================================
configure_git_name() {
  echo "----- ${MENU_2} -----"
  ensure_git || return 1

  local git_name
  read -r -p "Nombre de usuario para Git: " git_name

  while [[ -z "${git_name// }" ]]; do
    read -r -p "El nombre no puede estar vacío. Nombre de usuario para Git: " git_name
  done

  run_cmd git config --global user.name "$git_name"

  echo
  echo "Nombre configurado:"
  run_cmd git config --global user.name
}

# ============================================================
# Opción 3: Configurar Email de Usuario
# Configura git config --global user.email.
# ============================================================
configure_git_email() {
  echo "----- ${MENU_3} -----"
  ensure_git || return 1

  local git_email
  read -r -p "Correo de usuario para Git: " git_email

  while [[ -z "${git_email// }" ]]; do
    read -r -p "El correo no puede estar vacío. Correo de usuario para Git: " git_email
  done

  run_cmd git config --global user.email "$git_email"

  echo
  echo "Email configurado:"
  run_cmd git config --global user.email
}

# ============================================================
# Opción 4: Configurar Credencial
# Configura el helper de credenciales de Git.
# Opciones:
# - cache: guarda credenciales temporalmente en memoria.
# - store: guarda credenciales en texto plano en el usuario.
# - manager: usa Git Credential Manager si está instalado.
# - none: elimina el helper configurado.
# ============================================================
configure_git_credentials() {
  echo "----- ${MENU_4} -----"
  ensure_git || return 1

  echo "Métodos disponibles:"
  echo "1. cache   - Credenciales temporales en memoria"
  echo "2. store   - Credenciales persistentes en texto plano"
  echo "3. manager - Git Credential Manager si está instalado"
  echo "4. none    - Eliminar credential.helper"
  echo

  local method
  while true; do
    read -r -p "Método de credencial (cache | store | manager | none): " method
    case "${method,,}" in
      cache|store|manager|none) break ;;
      *) echo "Método no válido." ;;
    esac
  done

  if [[ "${method,,}" == "manager" ]] && ! git credential-manager --version >/dev/null 2>&1; then
    echo "Aviso: git credential-manager no parece estar instalado en este servidor."
    echo "Se configurará igualmente, pero puede requerir instalación adicional."
  fi

  if [[ "${method,,}" == "none" ]]; then
    run_cmd git config --global --unset credential.helper || true
    echo "credential.helper eliminado si existía."
  else
    run_cmd git config --global credential.helper "${method,,}"
  fi

  echo
  echo "Credencial configurada actualmente:"
  git config --global credential.helper || echo "credential.helper no configurado."
}

# ============================================================
# Opción 5: Configurar Safe Directory
# Agrega safe.directory para evitar errores de propiedad en repositorios.
# Permite configurar todos (*) o una ruta específica.
# ============================================================
configure_safe_directory() {
  echo "----- ${MENU_5} -----"
  ensure_git || return 1

  echo "Esta opción configura repositorios seguros para Git."
  echo "Usa '*' si deseas permitir todos los directorios."
  echo

  local safe_path
  read -r -p "Ruta segura para Git [*]: " safe_path
  safe_path="${safe_path:-*}"

  if ask_yes_no "¿Confirmas agregar safe.directory '${safe_path}'?"; then
    run_cmd git config --global --add safe.directory "$safe_path"
  else
    echo "Operación cancelada."
  fi

  echo
  echo "safe.directory configurados:"
  git config --global --get-all safe.directory || echo "No hay safe.directory configurados."
}

# ============================================================
# Opción 6: Consultar Configuración
# Muestra configuración global principal y listado completo.
# ============================================================
consult_git_config() {
  echo "----- ${MENU_6} -----"
  ensure_git || return 1

  echo "Usuario configurado:"
  git config --global user.name || echo "user.name no configurado."

  echo
  echo "Email configurado:"
  git config --global user.email || echo "user.email no configurado."

  echo
  echo "Credential helper configurado:"
  git config --global credential.helper || echo "credential.helper no configurado."

  echo
  echo "Safe directories configurados:"
  git config --global --get-all safe.directory || echo "No hay safe.directory configurados."

  echo
  echo "Configuración global completa:"
  git config --global --list || true
}

# ============================================================
# Opción 7: Consultar Versión Git
# Muestra la versión instalada de Git.
# ============================================================
consult_git_version() {
  echo "----- ${MENU_7} -----"
  ensure_git || return 1
  run_cmd git --version
}

# ============================================================
# Opción 8: Eliminar Configuración de Usuario
# Permite eliminar user.name, user.email y credential.helper.
# No desinstala Git.
# ============================================================
remove_user_config() {
  echo "----- ${MENU_8} -----"
  ensure_git || return 1

  if ask_yes_no "¿Deseas eliminar user.name?"; then
    run_cmd git config --global --unset user.name || true
  fi

  if ask_yes_no "¿Deseas eliminar user.email?"; then
    run_cmd git config --global --unset user.email || true
  fi

  if ask_yes_no "¿Deseas eliminar credential.helper?"; then
    run_cmd git config --global --unset credential.helper || true
  fi

  echo
  echo "Configuración resultante:"
  consult_git_config || true
}

# ============================================================
# Opción 9: Probar Configuración Básica
# Valida que Git esté instalado y que exista usuario/email global.
# ============================================================
test_git_config() {
  echo "----- ${MENU_9} -----"
  ensure_git || return 1

  local has_error=0

  echo "Validando Git:"
  git --version || has_error=1

  echo
  echo "Validando user.name:"
  if git config --global user.name >/dev/null 2>&1; then
    git config --global user.name
  else
    echo "ERROR: user.name no está configurado."
    has_error=1
  fi

  echo
  echo "Validando user.email:"
  if git config --global user.email >/dev/null 2>&1; then
    git config --global user.email
  else
    echo "ERROR: user.email no está configurado."
    has_error=1
  fi

  echo
  if [[ "$has_error" -eq 0 ]]; then
    echo "Configuración básica de Git correcta."
  else
    echo "La configuración básica de Git está incompleta."
  fi
}

# ============================================================
# Opción 10: Instalación y Configuración Completa
# Ejecuta instalación, nombre, email, safe.directory y credenciales.
# ============================================================
full_git_flow() {
  echo "----- ${MENU_10} -----"

  install_git_flow
  echo
  configure_git_name
  echo
  configure_git_email
  echo

  if ask_yes_no "¿Deseas configurar safe.directory ahora?"; then
    configure_safe_directory
  fi

  echo
  if ask_yes_no "¿Deseas configurar credenciales ahora?"; then
    configure_git_credentials
  fi

  echo
  echo "Validación final:"
  consult_git_config

  echo
  echo "Flujo Git finalizado."
}

# ============================================================
# Menú principal
# Muestra las opciones disponibles usando los mismos títulos que
# se usan en cada bloque funcional.
# ============================================================
show_menu() {
  clear || true
  echo "=============================================="
  echo "             MENÚ GIT - UBUNTU"
  echo "=============================================="
  echo "Usuario actual : $(whoami)"
  echo "HOME           : $HOME"
  echo "=============================================="
  echo "1. ${MENU_1}"
  echo "2. ${MENU_2}"
  echo "3. ${MENU_3}"
  echo "4. ${MENU_4}"
  echo "5. ${MENU_5}"
  echo "6. ${MENU_6}"
  echo "7. ${MENU_7}"
  echo "8. ${MENU_8}"
  echo "9. ${MENU_9}"
  echo "10. ${MENU_10}"
  echo "0. ${MENU_0}"
  echo "=============================================="
}

# ============================================================
# Controlador del menú
# Relaciona cada opción del menú con su bloque documentado.
# ============================================================
main() {
  local option

  while true; do
    show_menu
    read -r -p "Seleccione una opción: " option
    echo

    case "$option" in
      1) install_git_flow; pause_menu ;;
      2) configure_git_name; pause_menu ;;
      3) configure_git_email; pause_menu ;;
      4) configure_git_credentials; pause_menu ;;
      5) configure_safe_directory; pause_menu ;;
      6) consult_git_config; pause_menu ;;
      7) consult_git_version; pause_menu ;;
      8) remove_user_config; pause_menu ;;
      9) test_git_config; pause_menu ;;
      10) full_git_flow; pause_menu ;;
      0) echo "Saliendo del menú Git."; exit 0 ;;
      *) echo "Opción no válida."; pause_menu ;;
    esac
  done
}

main "$@"
