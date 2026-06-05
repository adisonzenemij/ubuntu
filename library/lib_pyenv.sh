#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Archivo: lib_pyenv.sh
# Objetivo: Administrar pyenv y versiones de Python en Ubuntu.
# ============================================================

SUDO_CMD=""
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  SUDO_CMD="sudo"
fi

# ============================================================
# Títulos oficiales del menú.
# Cada bloque funcional usa estos mismos títulos para evitar
# diferencias entre el menú y el encabezado mostrado en pantalla.
# ============================================================
MENU_1="Instalación Libreria"
MENU_2="Versiones Disponibles"
MENU_3="Listar Versiones Instaladas"
MENU_4="Instalar Versiones"
MENU_5="Establecer Versión Global"
MENU_6="Establecer Versión Local"
MENU_7="Desinstalar Versiones"
MENU_8="Verificar Versión Actual"
MENU_9="Consultar Versión Python/PIP"
MENU_0="Salir"

# ============================================================
# Función general: confirmación S/N - Y/N.
# No pertenece a una opción del menú; se reutiliza en varios bloques.
# ============================================================
ask_yes_no() {
  local p="$1"
  local a

  while true; do
    read -r -p "$p (S/N - Y/N): " a
    case "${a,,}" in
      s|si|sí|y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Respuesta no válida." ;;
    esac
  done
}

# ============================================================
# Función general: pausa la ejecución para volver al menú.
# No pertenece a una opción del menú; se reutiliza en varios bloques.
# ============================================================
pause_menu() {
  echo
  read -r -p "Presiona ENTER para continuar..."
}

# ============================================================
# Función general: imprime y ejecuta comandos.
# No pertenece a una opción del menú; se reutiliza en varios bloques.
# ============================================================
run_cmd() {
  echo "+ $*"
  "$@"
}

# ============================================================
# Función general: carga pyenv en la sesión actual.
# No pertenece a una opción del menú; es necesaria antes de usar pyenv.
# ============================================================
load_pyenv() {
  export PYENV_ROOT="$HOME/.pyenv"

  if [[ -d "$PYENV_ROOT/bin" ]]; then
    export PATH="$PYENV_ROOT/bin:$PATH"
  fi

  if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init -)"
    return 0
  fi

  return 1
}

# ============================================================
# Función general: valida que pyenv esté instalado y cargado.
# No pertenece a una opción del menú; se reutiliza antes de operar.
# ============================================================
ensure_pyenv() {
  if ! load_pyenv; then
    echo "ERROR: pyenv no está instalado o no está cargado en esta sesión."
    echo "Ejecuta primero la opción 1: $MENU_1."
    return 1
  fi
}

# ============================================================
# Función auxiliar de MENÚ 1: Instalación Libreria
# Agrega la configuración de pyenv en ~/.bashrc.
# ============================================================
configure_bashrc() {
  local bashrc="$HOME/.bashrc"
  touch "$bashrc"

  if ! grep -q 'PYENV_ROOT' "$bashrc"; then
    cat >> "$bashrc" <<'BASHRC_EOF'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
BASHRC_EOF
    echo "Configuración de pyenv agregada en $bashrc"
  else
    echo "La configuración de pyenv ya existe en $bashrc"
  fi
}

# ============================================================
# MENÚ 1: Instalación Libreria
# Instala dependencias de compilación, instala/carga pyenv y
# configura ~/.bashrc.
# ============================================================
install_pyenv_flow() {
  echo "----- $MENU_1 -----"
  echo "Se instalará pyenv desde el repositorio oficial disponible al momento de ejecución."

  run_cmd $SUDO_CMD apt update -y
  run_cmd $SUDO_CMD apt install -y \
    make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils tk-dev \
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev git

  if [[ ! -d "$HOME/.pyenv" ]]; then
    echo "Instalando pyenv en $HOME/.pyenv"
    curl https://pyenv.run | bash
  else
    echo "pyenv ya existe en $HOME/.pyenv. Se omite instalación."
  fi

  configure_bashrc

  if load_pyenv; then
    run_cmd pyenv --version
    echo "PYENV instalado/cargado correctamente."
  else
    echo "ERROR: pyenv no pudo cargarse. Reinicia la terminal o ejecuta: source ~/.bashrc"
    return 1
  fi
}

# ============================================================
# MENÚ 2: Versiones Disponibles
# Lista versiones disponibles para instalar con pyenv install -l.
# ============================================================
show_available_versions() {
  echo "----- $MENU_2 -----"
  ensure_pyenv || return 1

  echo "Comando ejecutado: pyenv install -l"
  echo "Nota: si se abre less, presiona Q para volver al menú."
  echo

  if command -v less >/dev/null 2>&1; then
    pyenv install -l | less -FRX
  else
    pyenv install -l
  fi
}

# ============================================================
# MENÚ 3: Listar Versiones Instaladas
# Muestra las versiones instaladas con pyenv versions.
# ============================================================
list_installed_versions() {
  echo "----- $MENU_3 -----"
  ensure_pyenv || return 1
  run_cmd pyenv versions
}

# ============================================================
# MENÚ 4: Instalar Versiones
# Solicita una versión de Python y la instala con pyenv install x.x.x.
# ============================================================
install_python_version() {
  echo "----- $MENU_4 -----"
  ensure_pyenv || return 1

  local py_version

  while true; do
    read -r -p "¿Qué versión deseas instalar?: " py_version
    py_version="${py_version// /}"

    if [[ -z "$py_version" ]]; then
      echo "La versión no puede estar vacía."
      continue
    fi

    if ask_yes_no "¿Confirmas instalar Python ${py_version}?"; then
      run_cmd pyenv install "$py_version"
      break
    fi
  done

  if ask_yes_no "¿Deseas establecer ${py_version} como versión global por defecto?"; then
    run_cmd pyenv global "$py_version"
  fi

  run_cmd pyenv versions
  run_cmd pyenv version
}

# ============================================================
# MENÚ 5: Establecer Versión Global
# Solicita una versión instalada y la establece globalmente con
# pyenv global x.x.x.
# ============================================================
select_python_version() {
  echo "----- $MENU_5 -----"
  ensure_pyenv || return 1

  local py_version
  echo "Versiones instaladas:"
  pyenv versions

  echo
  read -r -p "¿Qué versión deseas establecer como global?: " py_version
  py_version="${py_version// /}"

  if [[ -z "$py_version" ]]; then
    echo "ERROR: No ingresaste ninguna versión."
    return 1
  fi

  if ask_yes_no "¿Confirmas establecer ${py_version} como versión global?"; then
    run_cmd pyenv global "$py_version"
    run_cmd pyenv version
    run_cmd python --version
  else
    echo "Operación cancelada."
  fi
}

# ============================================================
# MENÚ 6: Establecer Versión Local
# Solicita una versión instalada y la establece en el directorio
# actual con pyenv local x.x.x, creando/actualizando .python-version.
# ============================================================
select_local_python_version() {
  echo "----- $MENU_6 -----"
  ensure_pyenv || return 1

  local py_version
  echo "Versiones instaladas:"
  pyenv versions

  echo
  echo "Esta opción crea/actualiza el archivo .python-version en el directorio actual:"
  pwd
  echo

  read -r -p "¿Qué versión deseas establecer como local?: " py_version
  py_version="${py_version// /}"

  if [[ -z "$py_version" ]]; then
    echo "ERROR: No ingresaste ninguna versión."
    return 1
  fi

  if ask_yes_no "¿Confirmas establecer ${py_version} como versión local en este directorio?"; then
    run_cmd pyenv local "$py_version"
    run_cmd pyenv version
    run_cmd python --version
  else
    echo "Operación cancelada."
  fi
}

# ============================================================
# MENÚ 7: Desinstalar Versiones
# Solicita una versión instalada y la elimina con pyenv uninstall x.x.x.
# ============================================================
uninstall_python_version() {
  echo "----- $MENU_7 -----"
  ensure_pyenv || return 1

  local py_version
  echo "Versiones instaladas:"
  pyenv versions

  echo
  read -r -p "¿Qué versión deseas desinstalar?: " py_version
  py_version="${py_version// /}"

  if [[ -z "$py_version" ]]; then
    echo "ERROR: No ingresaste ninguna versión."
    return 1
  fi

  if ask_yes_no "¿Confirmas desinstalar Python ${py_version}?"; then
    run_cmd pyenv uninstall "$py_version"
    run_cmd pyenv versions
  else
    echo "Operación cancelada."
  fi
}

# ============================================================
# MENÚ 8: Verificar Versión Actual
# Consulta la versión activa con pyenv version y la ruta del binario.
# ============================================================
check_current_version() {
  echo "----- $MENU_8 -----"
  ensure_pyenv || return 1

  run_cmd pyenv version
  run_cmd pyenv which python || true
}

# ============================================================
# MENÚ 9: Consultar Versión Python/PIP
# Consulta las versiones activas de python y pip en la sesión actual.
# ============================================================
check_python_pip_version() {
  echo "----- $MENU_9 -----"
  ensure_pyenv || true

  if command -v python >/dev/null 2>&1; then
    run_cmd python --version
  else
    echo "python no está disponible en PATH."
  fi

  if command -v pip >/dev/null 2>&1; then
    run_cmd pip --version
  else
    echo "pip no está disponible en PATH."
  fi

  if command -v pyenv >/dev/null 2>&1; then
    run_cmd pyenv version
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
  echo "        MENÚ PYENV + PYTHON - UBUNTU"
  echo "=============================================="
  echo "Usuario actual : $(whoami)"
  echo "HOME           : $HOME"
  echo "PYENV_ROOT     : ${PYENV_ROOT:-$HOME/.pyenv}"
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
    read -r -p "Selecciona una opción: " option
    echo

    case "$option" in
      1) install_pyenv_flow; pause_menu ;;
      2) show_available_versions; pause_menu ;;
      3) list_installed_versions; pause_menu ;;
      4) install_python_version; pause_menu ;;
      5) select_python_version; pause_menu ;;
      6) select_local_python_version; pause_menu ;;
      7) uninstall_python_version; pause_menu ;;
      8) check_current_version; pause_menu ;;
      9) check_python_pip_version; pause_menu ;;
      0) echo "Saliendo del menú PYENV + Python."; exit 0 ;;
      *) echo "Opción no válida."; pause_menu ;;
    esac
  done
}

main "$@"
