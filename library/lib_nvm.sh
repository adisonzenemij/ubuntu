#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Archivo: lib_nvm.sh
# Objetivo: Administrar NVM y versiones de Node.js en Ubuntu.
# Nota: En Linux el comando equivalente a "nvm list available"
#       de Windows es "nvm ls-remote".
# ============================================================

SUDO_CMD=""
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  SUDO_CMD="sudo"
fi

NVM_VERSION="${NVM_VERSION:-v0.40.3}"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# ============================================================
# Títulos oficiales del menú.
# Cada bloque funcional usa estos mismos títulos para evitar
# diferencias entre el menú y el encabezado mostrado en pantalla.
# ============================================================
MENU_1="Instalación Libreria"
MENU_2="Versiones Disponibles"
MENU_3="Listar Versiones"
MENU_4="Instalar Versiones"
MENU_5="Establecer Versiones"
MENU_6="Eliminar Versiones"
MENU_7="Verificar Versión"
MENU_8="Consultar Versión"
MENU_0="Salir"

# ============================================================
# Función general: imprime y ejecuta comandos.
# No pertenece a una opción del menú; se reutiliza en varios bloques.
# ============================================================
run_cmd() {
  echo "+ $*"
  "$@"
}

# ============================================================
# Función general: pausa la ejecución para volver al menú.
# No pertenece a una opción del menú; se reutiliza en varios bloques.
# ============================================================
pause() {
  echo
  read -r -p "Presiona ENTER para continuar..."
}

# ============================================================
# Función general: confirmación S/N - Y/N.
# No pertenece a una opción del menú; se reutiliza en varios bloques.
# ============================================================
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

# ============================================================
# Función general: carga NVM en la sesión actual.
# No pertenece a una opción del menú; es necesaria antes de usar nvm.
# ============================================================
load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    set +u
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    set -u
  else
    echo "ERROR: No se encontró nvm en: $NVM_DIR"
    echo "Primero ejecuta la opción 1: $MENU_1."
    return 1
  fi

  if [[ -s "$NVM_DIR/bash_completion" ]]; then
    set +u
    # shellcheck disable=SC1091
    . "$NVM_DIR/bash_completion"
    set -u
  fi
}

# ============================================================
# Función general: ejecuta comandos nvm evitando errores con set -u.
# No pertenece a una opción del menú; corrige errores como:
# PATTERN: unbound variable.
# ============================================================
safe_nvm() {
  set +u
  "$@"
  local status=$?
  set -u
  return "$status"
}

# ============================================================
# MENÚ 1: Instalación Libreria
# Instala dependencias, instala/carga NVM y opcionalmente instala
# la versión LTS de Node.js.
# ============================================================
install_nvm_flow() {
  echo "----- $MENU_1 -----"
  echo "Se instalará nvm versión ${NVM_VERSION}."
  echo "Puedes cambiarla ejecutando: NVM_VERSION=vX.Y.Z ./lib_nvm.sh"
  echo

  run_cmd $SUDO_CMD apt update -y
  run_cmd $SUDO_CMD apt install -y curl ca-certificates

  if [[ ! -d "$NVM_DIR" ]]; then
    echo "Instalando nvm en $NVM_DIR"
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
  else
    echo "nvm ya existe en $NVM_DIR. Se omite instalación."
  fi

  load_nvm

  echo
  echo "Versión de NVM instalada:"
  safe_nvm nvm --version

  echo
  if ask_yes_no "¿Deseas instalar la versión LTS de Node.js ahora?"; then
    safe_nvm nvm install --lts
    safe_nvm nvm use --lts
    safe_nvm nvm alias default 'lts/*'
  else
    echo "Se omite instalación de Node.js. Puedes instalar después desde la opción 4: $MENU_4."
  fi

  echo
  echo "Validación final:"
  safe_nvm nvm list || true
  safe_nvm nvm current || true

  if command -v node >/dev/null 2>&1; then
    node --version
  else
    echo "Node.js todavía no está instalado."
  fi

  if command -v npm >/dev/null 2>&1; then
    npm --version
  else
    echo "npm todavía no está instalado."
  fi

  echo
  echo "Flujo finalizado. Para recargar la terminal ejecuta:"
  echo "source ~/.bashrc"
}

# ============================================================
# MENÚ 2: Versiones Disponibles
# Lista versiones remotas disponibles para instalar.
# En Linux se usa: nvm ls-remote.
# ============================================================
show_available_versions() {
  echo "----- $MENU_2 -----"
  load_nvm || return 1

  echo "Equivalente en NVM Linux: nvm ls-remote"
  echo
  safe_nvm nvm ls-remote | tail -n 40
}

# ============================================================
# MENÚ 3: Listar Versiones
# Muestra las versiones de Node.js instaladas localmente con NVM.
# ============================================================
list_installed_versions() {
  echo "----- $MENU_3 -----"
  load_nvm || return 1
  safe_nvm nvm list
}

# ============================================================
# MENÚ 4: Instalar Versiones
# Solicita una versión de Node.js y la instala con nvm install x.x.x.
# ============================================================
install_node_version() {
  echo "----- $MENU_4 -----"
  load_nvm || return 1

  echo "Versiones LTS disponibles recientes:"
  safe_nvm nvm ls-remote --lts | tail -n 20 || true
  echo

  read -r -p "Digite la versión a instalar: " node_version

  if [[ -z "${node_version// /}" ]]; then
    echo "ERROR: No ingresaste ninguna versión."
    return 1
  fi

  safe_nvm nvm install "$node_version"
  safe_nvm nvm list
}

# ============================================================
# MENÚ 5: Establecer Versiones
# Solicita una versión instalada, ejecuta nvm use x.x.x y la deja
# como versión por defecto con nvm alias default x.x.x.
# ============================================================
use_node_version() {
  echo "----- $MENU_5 -----"
  load_nvm || return 1

  echo "Versiones instaladas:"
  safe_nvm nvm list
  echo

  read -r -p "Digite la versión a usar: " node_version

  if [[ -z "${node_version// /}" ]]; then
    echo "ERROR: No ingresaste ninguna versión."
    return 1
  fi

  if ask_yes_no "¿Confirmas establecer la versión ${node_version}?"; then
    safe_nvm nvm use "$node_version"
    safe_nvm nvm alias default "$node_version"
    safe_nvm nvm current
    node --version
    npm --version
  else
    echo "Operación cancelada."
  fi
}

# ============================================================
# MENÚ 6: Eliminar Versiones
# Solicita una versión instalada y la elimina con nvm uninstall x.x.x.
# ============================================================
uninstall_node_version() {
  echo "----- $MENU_6 -----"
  load_nvm || return 1

  echo "Versiones instaladas:"
  safe_nvm nvm list
  echo

  read -r -p "Digite la versión a desinstalar: " node_version

  if [[ -z "${node_version// /}" ]]; then
    echo "ERROR: No ingresaste ninguna versión."
    return 1
  fi

  if ask_yes_no "¿Confirmas desinstalar la versión ${node_version}?"; then
    safe_nvm nvm uninstall "$node_version"
    safe_nvm nvm list
  else
    echo "Operación cancelada."
  fi
}

# ============================================================
# MENÚ 7: Verificar Versión
# Consulta la versión activa con nvm current y node --version.
# ============================================================
check_current_version() {
  echo "----- $MENU_7 -----"
  load_nvm || return 1
  safe_nvm nvm current

  if command -v node >/dev/null 2>&1; then
    node --version
  else
    echo "Node.js no está disponible en la sesión actual."
  fi
}

# ============================================================
# MENÚ 8: Consultar Versión
# Consulta la versión de npm activa con npm --version.
# ============================================================
check_npm_version() {
  echo "----- $MENU_8 -----"
  load_nvm || return 1

  if command -v npm >/dev/null 2>&1; then
    npm --version
  else
    echo "npm no está disponible. Primero instala una versión de Node.js."
  fi
}

# ============================================================
# Menú principal: muestra las opciones disponibles.
# Los títulos impresos aquí deben coincidir con los encabezados
# de cada bloque funcional.
# ============================================================
show_menu() {
  clear || true
  echo "=============================================="
  echo "        Menú NVM + Node.js"
  echo "=============================================="
  echo "Usuario actual : $(whoami)"
  echo "HOME           : $HOME"
  echo "NVM_DIR        : $NVM_DIR"
  echo "=============================================="
  echo "1. $MENU_1"
  echo "2. $MENU_2"
  echo "3. $MENU_3"
  echo "4. $MENU_4"
  echo "5. $MENU_5"
  echo "6. $MENU_6"
  echo "7. $MENU_7"
  echo "8. $MENU_8"
  echo "0. $MENU_0"
  echo "=============================================="
}

# ============================================================
# Controlador principal: ejecuta el bloque correspondiente
# según la opción seleccionada en el menú.
# ============================================================
main() {
  local option

  while true; do
    show_menu
    read -r -p "Seleccione una opción: " option
    echo

    case "$option" in
      1) install_nvm_flow; pause ;;
      2) show_available_versions; pause ;;
      3) list_installed_versions; pause ;;
      4) install_node_version; pause ;;
      5) use_node_version; pause ;;
      6) uninstall_node_version; pause ;;
      7) check_current_version; pause ;;
      8) check_npm_version; pause ;;
      0) echo "Saliendo..."; exit 0 ;;
      *) echo "Opción no válida."; pause ;;
    esac
  done
}

main "$@"
