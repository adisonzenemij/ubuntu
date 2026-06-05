#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# Archivo: git.sh
# Propósito: Administrar directorio base Git, proyectos descargados y despliegues
#            Python/Angular en Ubuntu.
# ==============================================================================

SUDO_CMD=""
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  SUDO_CMD="sudo"
fi

CONFIG_FILE="$HOME/.git_deploy_manager.conf"
DEFAULT_BASE_DIR="/var/www"
DEFAULT_GIT_FOLDER="git"
BASE_DIR="$DEFAULT_BASE_DIR"
GIT_FOLDER="$DEFAULT_GIT_FOLDER"
GIT_DIR="$BASE_DIR/$GIT_FOLDER"
APP_USER="$(whoami)"

# ==============================================================================
# Funciones Generales
# ==============================================================================

run_cmd() {
  echo "+ $*"
  "$@"
}

pause_menu() {
  echo
  read -r -p "Presiona ENTER para continuar..."
}

ask_yes_no() {
  local prompt="$1"
  local answer

  while true; do
    read -r -p "$prompt (S/N - Y/N): " answer
    case "${answer,,}" in
      s|si|sí|y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Respuesta no válida. Escribe S/N o Y/N." ;;
    esac
  done
}

valid_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( "$1" >= 1 && "$1" <= 65535 ))
}

valid_user() {
  id "$1" >/dev/null 2>&1
}

slugify_service_name() {
  local value="$1"
  echo "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  fi

  BASE_DIR="${BASE_DIR:-$DEFAULT_BASE_DIR}"
  GIT_FOLDER="${GIT_FOLDER:-$DEFAULT_GIT_FOLDER}"
  GIT_DIR="$BASE_DIR/$GIT_FOLDER"
  APP_USER="${APP_USER:-$(whoami)}"
}

save_config() {
  cat > "$CONFIG_FILE" <<EOF_CONF
BASE_DIR="$BASE_DIR"
GIT_FOLDER="$GIT_FOLDER"
APP_USER="$APP_USER"
EOF_CONF
  echo "Configuración guardada en: $CONFIG_FILE"
}

ensure_git_dir() {
  load_config
  if [[ ! -d "$GIT_DIR" ]]; then
    echo "ERROR: El directorio configurado no existe: $GIT_DIR"
    echo "Ejecuta primero la opción 1. Configurar Directorio."
    return 1
  fi
}

ensure_command() {
  local cmd="$1"
  local pkg="${2:-$1}"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "El comando '$cmd' no está instalado. Instalando paquete: $pkg"
    run_cmd $SUDO_CMD apt update -y
    run_cmd $SUDO_CMD apt install -y "$pkg"
  fi
}

select_project() {
  ensure_git_dir || return 1

  local projects=()
  local item
  local option

  shopt -s nullglob
  for item in "$GIT_DIR"/*; do
    if [[ -d "$item" ]]; then
      projects+=("$item")
    fi
  done
  shopt -u nullglob

  if (( ${#projects[@]} == 0 )); then
    echo "No existen proyectos descargados en: $GIT_DIR"
    return 1
  fi

  echo "Proyectos disponibles:"
  local i
  for i in "${!projects[@]}"; do
    echo "$((i + 1)). $(basename "${projects[$i]}")"
  done
  echo "0. Cancelar"
  echo

  while true; do
    read -r -p "Selecciona el proyecto: " option
    if [[ "$option" == "0" ]]; then
      echo "Operación cancelada."
      return 1
    fi
    if [[ "$option" =~ ^[0-9]+$ ]] && (( option >= 1 && option <= ${#projects[@]} )); then
      SELECTED_PROJECT="${projects[$((option - 1))]}"
      SELECTED_PROJECT_NAME="$(basename "$SELECTED_PROJECT")"
      return 0
    fi
    echo "Opción inválida. Selecciona un número de la lista."
  done
}

current_project_branch() {
  local project_dir="$1"

  if [[ ! -d "$project_dir/.git" ]]; then
    echo "no es repositorio git"
    return 0
  fi

  local branch
  branch="$(git -C "$project_dir" branch --show-current 2>/dev/null || true)"
  if [[ -n "$branch" ]]; then
    echo "$branch"
  else
    echo "detached HEAD"
  fi
}

select_file_if_exists() {
  local base="$1"
  shift
  local candidates=("$@")
  local file

  for file in "${candidates[@]}"; do
    if [[ -f "$base/$file" ]]; then
      echo "$base/$file"
      return 0
    fi
  done

  return 1
}

# ==============================================================================
# Menú Principal - Opción 1. Configurar Directorio
# ==============================================================================
configure_directory() {
  load_config
  echo "----- 1. Configurar Directorio -----"
  echo "Directorio base sugerido : $DEFAULT_BASE_DIR"
  echo "Carpeta sugerida        : $DEFAULT_GIT_FOLDER"
  echo

  BASE_DIR="$DEFAULT_BASE_DIR"

  if ask_yes_no "¿Deseas cambiar el nombre sugerido de la carpeta '$DEFAULT_GIT_FOLDER'?"; then
    while true; do
      read -r -p "Nombre de la carpeta dentro de $BASE_DIR: " GIT_FOLDER
      GIT_FOLDER="${GIT_FOLDER// /}"
      if [[ -n "$GIT_FOLDER" ]]; then
        break
      fi
      echo "El nombre de la carpeta no puede estar vacío."
    done
  else
    GIT_FOLDER="$DEFAULT_GIT_FOLDER"
  fi

  GIT_DIR="$BASE_DIR/$GIT_FOLDER"
  APP_USER="$(whoami)"

  echo
  echo "Usuario detectado en la sesión actual: $APP_USER"
  if ask_yes_no "¿Deseas asignar permisos a otro usuario del servidor?"; then
    while true; do
      read -r -p "Nombre del usuario del servidor: " APP_USER
      if valid_user "$APP_USER"; then
        break
      fi
      echo "El usuario '$APP_USER' no existe en el servidor."
      echo "Usuarios disponibles con shell común:"
      awk -F: '$7 ~ /(bash|sh)$/ {print "- "$1}' /etc/passwd || true
    done
  fi

  echo
  echo "Creando directorio: $GIT_DIR"
  run_cmd $SUDO_CMD mkdir -p "$GIT_DIR"
  run_cmd $SUDO_CMD chown -R "$APP_USER:$APP_USER" "$GIT_DIR"
  run_cmd $SUDO_CMD chmod -R 775 "$GIT_DIR"

  save_config

  echo
  echo "Directorio configurado correctamente: $GIT_DIR"
  echo "Usuario propietario: $APP_USER"
}

# ==============================================================================
# Menú Principal - Opción 2. Visualizar Directorio
# ==============================================================================
show_directory() {
  load_config
  echo "----- 2. Visualizar Directorio -----"
  echo "Directorio base     : $BASE_DIR"
  echo "Carpeta Git         : $GIT_FOLDER"
  echo "Ruta configurada    : $GIT_DIR"
  echo "Usuario configurado : $APP_USER"
  echo "Archivo config      : $CONFIG_FILE"

  if [[ -d "$GIT_DIR" ]]; then
    echo
    echo "Contenido actual:"
    ls -la "$GIT_DIR"
  else
    echo
    echo "El directorio todavía no existe. Ejecuta la opción 1."
  fi
}

# ==============================================================================
# Menú Principal - Opción 3. Listar Proyectos Descargados
# ==============================================================================
list_downloaded_projects() {
  ensure_git_dir || return 1

  echo "----- 3. Listar Proyectos Descargados -----"
  echo "Directorio configurado: $GIT_DIR"
  echo

  local projects=()
  local item

  shopt -s nullglob
  for item in "$GIT_DIR"/*; do
    [[ -d "$item" ]] && projects+=("$item")
  done
  shopt -u nullglob

  if (( ${#projects[@]} == 0 )); then
    echo "No existen proyectos descargados en: $GIT_DIR"
    return 0
  fi

  local i
  local project_name
  local branch

  for i in "${!projects[@]}"; do
    project_name="$(basename "${projects[$i]}")"
    branch="$(current_project_branch "${projects[$i]}")"
    echo "$((i + 1)). $project_name"
    echo "   Ruta   : ${projects[$i]}"
    echo "   Branch : $branch"
  done
}

# ==============================================================================
# Menú Principal - Opción 4. Descargar Proyecto
# ==============================================================================
download_project() {
  ensure_git_dir || return 1
  ensure_command git git

  echo "----- 4. Descargar Proyecto -----"
  local repo_url
  local custom_name
  local target_dir

  while true; do
    read -r -p "URL del repositorio Git: " repo_url
    if [[ -n "${repo_url// }" ]]; then
      break
    fi
    echo "La URL no puede estar vacía."
  done

  if ask_yes_no "¿Deseas especificar un nombre de carpeta para el proyecto?"; then
    read -r -p "Nombre de carpeta destino: " custom_name
    custom_name="${custom_name// /}"
    if [[ -n "$custom_name" ]]; then
      target_dir="$GIT_DIR/$custom_name"
      run_cmd git clone "$repo_url" "$target_dir"
    else
      echo "Nombre vacío. Se clonará usando el nombre original del repositorio."
      run_cmd git -C "$GIT_DIR" clone "$repo_url"
    fi
  else
    run_cmd git -C "$GIT_DIR" clone "$repo_url"
  fi

  run_cmd $SUDO_CMD chown -R "$APP_USER:$APP_USER" "$GIT_DIR"
  run_cmd $SUDO_CMD chmod -R 775 "$GIT_DIR"
  echo "Proyecto descargado y permisos aplicados."
}

# ==============================================================================
# Menú Principal - Opción 5. Eliminar Proyectos
# ==============================================================================
delete_project() {
  echo "----- 5. Eliminar Proyectos -----"
  select_project || return 1

  echo
  echo "Proyecto seleccionado: $SELECTED_PROJECT"
  if ask_yes_no "¿Confirmas eliminar este proyecto?"; then
    run_cmd rm -rf "$SELECTED_PROJECT"
    echo "Proyecto eliminado: $SELECTED_PROJECT_NAME"
  else
    echo "Operación cancelada."
  fi
}

# ==============================================================================
# Menú Principal - Opción 6. Descargar Cambios
# ==============================================================================
pull_project_changes() {
  echo "----- 6. Descargar Cambios -----"
  select_project || return 1

  if [[ ! -d "$SELECTED_PROJECT/.git" ]]; then
    echo "ERROR: El proyecto seleccionado no parece ser un repositorio Git."
    return 1
  fi

  echo "Proyecto seleccionado: $SELECTED_PROJECT_NAME"
  run_cmd git -C "$SELECTED_PROJECT" status --short
  run_cmd git -C "$SELECTED_PROJECT" pull
  run_cmd $SUDO_CMD chown -R "$APP_USER:$APP_USER" "$SELECTED_PROJECT"
}

# ==============================================================================
# Menú Principal - Opción 7. Cambiar Branch
# ==============================================================================
select_project_branch() {
  local project_dir="$1"
  local branches=()
  local branch_refs=()
  local branch_types=()
  local branch
  local option

  while IFS= read -r branch; do
    [[ -n "$branch" ]] || continue
    branches+=("local: $branch")
    branch_refs+=("$branch")
    branch_types+=("local")
  done < <(git -C "$project_dir" for-each-ref --format='%(refname:short)' refs/heads)

  while IFS= read -r branch; do
    [[ -n "$branch" ]] || continue
    [[ "$branch" == */HEAD ]] && continue
    branches+=("remoto: $branch")
    branch_refs+=("$branch")
    branch_types+=("remote")
  done < <(git -C "$project_dir" for-each-ref --format='%(refname:short)' refs/remotes)

  if (( ${#branches[@]} > 0 )); then
    echo "Branches disponibles:"
    local i
    for i in "${!branches[@]}"; do
      echo "$((i + 1)). ${branches[$i]}"
    done
    echo "M. Escribir branch manualmente"
    echo "0. Cancelar"
    echo
  else
    echo "No se encontraron branches locales o remotos."
    echo "M. Escribir branch manualmente"
    echo "0. Cancelar"
    echo
  fi

  while true; do
    read -r -p "Selecciona el branch: " option
    case "${option,,}" in
      0)
        echo "Operación cancelada."
        return 1
        ;;
      m)
        read -r -p "Nombre del branch: " SELECTED_BRANCH_REF
        SELECTED_BRANCH_REF="${SELECTED_BRANCH_REF// /}"
        if [[ -n "$SELECTED_BRANCH_REF" ]]; then
          SELECTED_BRANCH_TYPE="manual"
          return 0
        fi
        echo "El nombre del branch no puede estar vacío."
        ;;
      *)
        if [[ "$option" =~ ^[0-9]+$ ]] && (( option >= 1 && option <= ${#branches[@]} )); then
          SELECTED_BRANCH_REF="${branch_refs[$((option - 1))]}"
          SELECTED_BRANCH_TYPE="${branch_types[$((option - 1))]}"
          return 0
        fi
        echo "Opción inválida. Selecciona un número de la lista, M o 0."
        ;;
    esac
  done
}

switch_to_selected_branch() {
  local project_dir="$1"
  local branch_ref="$2"
  local branch_type="$3"
  local local_branch

  if [[ "$branch_type" == "remote" ]]; then
    local_branch="${branch_ref#*/}"

    if git -C "$project_dir" show-ref --verify --quiet "refs/heads/$local_branch"; then
      if run_cmd git -C "$project_dir" switch "$local_branch"; then
        return 0
      fi
      run_cmd git -C "$project_dir" checkout "$local_branch"
      return 0
    fi

    if run_cmd git -C "$project_dir" switch --track "$branch_ref"; then
      return 0
    fi
    run_cmd git -C "$project_dir" checkout -b "$local_branch" "$branch_ref"
    return 0
  fi

  if run_cmd git -C "$project_dir" switch "$branch_ref"; then
    return 0
  fi
  run_cmd git -C "$project_dir" checkout "$branch_ref"
}

change_project_branch() {
  echo "----- 7. Cambiar Branch -----"
  select_project || return 1

  if [[ ! -d "$SELECTED_PROJECT/.git" ]]; then
    echo "ERROR: El proyecto seleccionado no parece ser un repositorio Git."
    return 1
  fi

  echo "Proyecto seleccionado: $SELECTED_PROJECT_NAME"
  echo "Ruta               : $SELECTED_PROJECT"
  echo "Branch actual      : $(current_project_branch "$SELECTED_PROJECT")"
  echo

  if ask_yes_no "¿Deseas actualizar la lista de branches remotos con git fetch?"; then
    run_cmd git -C "$SELECTED_PROJECT" fetch --all --prune
  fi

  if [[ -n "$(git -C "$SELECTED_PROJECT" status --porcelain)" ]]; then
    echo
    echo "AVISO: El proyecto tiene cambios locales sin confirmar."
    if ! ask_yes_no "¿Deseas intentar cambiar de branch de todas formas?"; then
      echo "Operación cancelada."
      return 1
    fi
  fi

  echo
  select_project_branch "$SELECTED_PROJECT" || return 1
  echo
  echo "Branch seleccionado: $SELECTED_BRANCH_REF"

  switch_to_selected_branch "$SELECTED_PROJECT" "$SELECTED_BRANCH_REF" "$SELECTED_BRANCH_TYPE"
  run_cmd $SUDO_CMD chown -R "$APP_USER:$APP_USER" "$SELECTED_PROJECT"

  echo
  echo "Estado actual del repositorio:"
  run_cmd git -C "$SELECTED_PROJECT" status -sb

  if ask_yes_no "¿Deseas descargar los últimos cambios del branch actual con git pull?"; then
    run_cmd git -C "$SELECTED_PROJECT" pull
  fi
}

# ==============================================================================
# Funciones Python - Selección y comandos de framework
# ==============================================================================
select_python_framework() {
  local option
  echo "Framework del proyecto Python:"
  echo "1. FastAPI"
  echo "2. Django"
  echo "3. Flask"
  echo "4. Otro"
  echo

  while true; do
    read -r -p "Selecciona el framework: " option
    case "$option" in
      1) PY_FRAMEWORK="fastapi"; return 0 ;;
      2) PY_FRAMEWORK="django"; return 0 ;;
      3) PY_FRAMEWORK="flask"; return 0 ;;
      4) PY_FRAMEWORK="otro"; return 0 ;;
      *) echo "Opción inválida." ;;
    esac
  done
}

ask_python_port() {
  while true; do
    read -r -p "Puerto para ejecutar la aplicación Python: " PY_PORT
    if valid_port "$PY_PORT"; then
      return 0
    fi
    echo "Puerto inválido. Debe estar entre 1 y 65535."
  done
}

build_python_exec_command() {
  local project_dir="$1"
  local framework="$2"
  local port="$3"
  local module_app
  local custom_cmd

  case "$framework" in
    fastapi)
      read -r -p "Módulo FastAPI [main:app]: " module_app
      module_app="${module_app:-main:app}"
      PY_EXEC_CMD="$project_dir/.venv/bin/uvicorn $module_app --host 0.0.0.0 --port $port"
      ;;
    django)
      PY_EXEC_CMD="$project_dir/.venv/bin/python manage.py runserver 0.0.0.0:$port"
      ;;
    flask)
      read -r -p "Archivo/módulo Flask [app.py]: " module_app
      module_app="${module_app:-app.py}"
      PY_EXEC_CMD="bash -lc 'source $project_dir/.venv/bin/activate && export FLASK_APP=$module_app && flask run --host=0.0.0.0 --port=$port'"
      ;;
    otro)
      echo "Escribe el comando completo. Puedes usar {port} para reemplazar por el puerto."
      read -r -p "Comando: " custom_cmd
      if [[ -z "${custom_cmd// }" ]]; then
        echo "ERROR: El comando no puede estar vacío."
        return 1
      fi
      PY_EXEC_CMD="${custom_cmd//\{port\}/$port}"
      ;;
  esac
}

python_service_name() {
  local project_name="$1"
  echo "app-python-$(slugify_service_name "$project_name")"
}

# ==============================================================================
# Menú Python - Opción 1. Detener Aplicación
# ==============================================================================
python_stop_app() {
  echo "----- Python - Detener Aplicación -----"
  select_project || return 1

  local service_name
  service_name="$(python_service_name "$SELECTED_PROJECT_NAME")"

  if systemctl list-unit-files | grep -q "^${service_name}.service"; then
    run_cmd $SUDO_CMD systemctl stop "$service_name" || true
    echo "Servicio detenido: $service_name"
  else
    echo "No existe servicio systemd para: $service_name"
  fi
}

# ==============================================================================
# Menú Python - Opción 2. Ejecutar Aplicación
# ==============================================================================
python_run_app() {
  echo "----- Python - Ejecutar Aplicación -----"
  select_project || return 1
  select_python_framework
  ask_python_port
  build_python_exec_command "$SELECTED_PROJECT" "$PY_FRAMEWORK" "$PY_PORT" || return 1

  echo
  echo "Comando sugerido para ejecución manual:"
  echo "$PY_EXEC_CMD"
  echo

  if ask_yes_no "¿Deseas ejecutarlo ahora en primer plano?"; then
    cd "$SELECTED_PROJECT"
    bash -lc "$PY_EXEC_CMD"
  else
    echo "Ejecución omitida. Para dejarlo permanente usa la opción Generar Enlace Simbólico / systemd."
  fi
}

# ==============================================================================
# Menú Python - Opción 3. Eliminar Entorno
# ==============================================================================
python_delete_venv() {
  echo "----- Python - Eliminar Entorno -----"
  select_project || return 1

  if [[ -d "$SELECTED_PROJECT/.venv" ]]; then
    if ask_yes_no "¿Confirmas eliminar $SELECTED_PROJECT/.venv?"; then
      run_cmd rm -rf "$SELECTED_PROJECT/.venv"
    fi
  else
    echo "No existe entorno virtual .venv en este proyecto."
  fi
}

# ==============================================================================
# Menú Python - Opción 4. Generar Entorno
# ==============================================================================
python_create_venv() {
  echo "----- Python - Generar Entorno -----"
  select_project || return 1
  ensure_command python3 python3
  ensure_command pip3 python3-pip

  if [[ -d "$SELECTED_PROJECT/.venv" ]]; then
    echo "Ya existe entorno virtual: $SELECTED_PROJECT/.venv"
    if ! ask_yes_no "¿Deseas continuar sin recrearlo?"; then
      return 0
    fi
  else
    run_cmd python3 -m venv "$SELECTED_PROJECT/.venv"
  fi

  run_cmd "$SELECTED_PROJECT/.venv/bin/python" --version
}

# ==============================================================================
# Menú Python - Opción 5. Instalar Dependencias
# ==============================================================================
python_install_dependencies() {
  echo "----- Python - Instalar Dependencias -----"
  select_project || return 1

  if [[ ! -d "$SELECTED_PROJECT/.venv" ]]; then
    echo "No existe .venv. Generando entorno virtual..."
    run_cmd python3 -m venv "$SELECTED_PROJECT/.venv"
  fi

  local req_file
  req_file="$(select_file_if_exists "$SELECTED_PROJECT" "requirements.txt" "requirements-prod.txt" "requirements/production.txt" "requirements/dev.txt" || true)"

  if [[ -z "${req_file:-}" ]]; then
    read -r -p "No encontré requirements.txt. Ruta del archivo de dependencias: " req_file
  fi

  if [[ ! -f "$req_file" ]]; then
    echo "ERROR: No existe el archivo de dependencias: $req_file"
    return 1
  fi

  run_cmd "$SELECTED_PROJECT/.venv/bin/python" -m pip install --upgrade pip
  run_cmd "$SELECTED_PROJECT/.venv/bin/pip" install -r "$req_file"
}

# ==============================================================================
# Menú Python - Opción 6. Generar Enlace Simbólico / Servicio systemd
# ==============================================================================
python_generate_systemd() {
  echo "----- Python - Generar Enlace Simbólico / Servicio systemd -----"
  select_project || return 1
  select_python_framework
  ask_python_port
  build_python_exec_command "$SELECTED_PROJECT" "$PY_FRAMEWORK" "$PY_PORT" || return 1

  local service_name
  local service_file
  service_name="$(python_service_name "$SELECTED_PROJECT_NAME")"
  service_file="/etc/systemd/system/${service_name}.service"

  echo "Servicio a generar: $service_name"
  echo "Archivo systemd  : $service_file"

  cat <<EOF_SERVICE | $SUDO_CMD tee "$service_file" >/dev/null
[Unit]
Description=Aplicación Python ${SELECTED_PROJECT_NAME}
After=network.target

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=${SELECTED_PROJECT}
ExecStart=/bin/bash -lc '${PY_EXEC_CMD}'
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF_SERVICE

  run_cmd $SUDO_CMD systemctl daemon-reload
  run_cmd $SUDO_CMD systemctl enable "$service_name"
  run_cmd $SUDO_CMD systemctl restart "$service_name"
  run_cmd $SUDO_CMD systemctl --no-pager status "$service_name" || true

  echo
  echo "Nota: systemctl enable genera el enlace simbólico para iniciar el servicio al encender el servidor."
}

# ==============================================================================
# Menú Python - Opción 7. Flujo Continuo Completo
# ==============================================================================
python_continuous_flow() {
  echo "----- Python - Flujo Continuo Completo -----"
  select_project || return 1
  select_python_framework
  ask_python_port
  build_python_exec_command "$SELECTED_PROJECT" "$PY_FRAMEWORK" "$PY_PORT" || return 1

  local service_name
  local req_file
  local service_file
  service_name="$(python_service_name "$SELECTED_PROJECT_NAME")"
  service_file="/etc/systemd/system/${service_name}.service"

  echo "1. Deteniendo aplicación si existe..."
  run_cmd $SUDO_CMD systemctl stop "$service_name" || true

  echo "2. Eliminando entorno virtual..."
  run_cmd rm -rf "$SELECTED_PROJECT/.venv"

  echo "3. Generando entorno virtual..."
  ensure_command python3 python3
  ensure_command pip3 python3-pip
  run_cmd python3 -m venv "$SELECTED_PROJECT/.venv"

  echo "4. Instalando dependencias..."
  req_file="$(select_file_if_exists "$SELECTED_PROJECT" "requirements.txt" "requirements-prod.txt" "requirements/production.txt" "requirements/dev.txt" || true)"
  if [[ -z "${req_file:-}" ]]; then
    read -r -p "Ruta del archivo de dependencias: " req_file
  fi
  if [[ -f "$req_file" ]]; then
    run_cmd "$SELECTED_PROJECT/.venv/bin/python" -m pip install --upgrade pip
    run_cmd "$SELECTED_PROJECT/.venv/bin/pip" install -r "$req_file"
  else
    echo "No se instaló dependencias porque no existe el archivo: $req_file"
  fi

  echo "5. Generando servicio systemd y enlace simbólico de inicio automático..."
  cat <<EOF_SERVICE | $SUDO_CMD tee "$service_file" >/dev/null
[Unit]
Description=Aplicación Python ${SELECTED_PROJECT_NAME}
After=network.target

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=${SELECTED_PROJECT}
ExecStart=/bin/bash -lc '${PY_EXEC_CMD}'
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF_SERVICE

  run_cmd $SUDO_CMD systemctl daemon-reload
  run_cmd $SUDO_CMD systemctl enable "$service_name"
  run_cmd $SUDO_CMD systemctl restart "$service_name"
  run_cmd $SUDO_CMD systemctl --no-pager status "$service_name" || true
}

# ==============================================================================
# Submenú Python
# ==============================================================================
show_python_menu() {
  clear || true
  echo "=============================================="
  echo "        DESPLEGAR PROYECTOS - PYTHON"
  echo "=============================================="
  echo "1. Detener Aplicación"
  echo "2. Ejecutar Aplicación"
  echo "3. Eliminar Entorno"
  echo "4. Generar Entorno"
  echo "5. Instalar Dependencias"
  echo "6. Generar Enlace Simbólico"
  echo "7. Flujo Continuo Completo"
  echo "0. Volver"
  echo "=============================================="
}

python_deploy_menu() {
  local option
  while true; do
    show_python_menu
    read -r -p "Selecciona una opción: " option
    echo
    case "$option" in
      1) python_stop_app; pause_menu ;;
      2) python_run_app; pause_menu ;;
      3) python_delete_venv; pause_menu ;;
      4) python_create_venv; pause_menu ;;
      5) python_install_dependencies; pause_menu ;;
      6) python_generate_systemd; pause_menu ;;
      7) python_continuous_flow; pause_menu ;;
      0) return 0 ;;
      *) echo "Opción no válida."; pause_menu ;;
    esac
  done
}

# ==============================================================================
# Funciones Angular
# ==============================================================================
select_build_configuration() {
  local option
  echo "Configuración de compilación Angular:"
  echo "1. production"
  echo "2. development"
  echo "3. staging"
  echo "4. Otro"
  echo

  while true; do
    read -r -p "Selecciona configuración: " option
    case "$option" in
      1) ANGULAR_CONFIG="production"; return 0 ;;
      2) ANGULAR_CONFIG="development"; return 0 ;;
      3) ANGULAR_CONFIG="staging"; return 0 ;;
      4)
        read -r -p "Nombre de configuración personalizada: " ANGULAR_CONFIG
        if [[ -n "${ANGULAR_CONFIG// }" ]]; then
          return 0
        fi
        echo "El nombre no puede estar vacío."
        ;;
      *) echo "Opción inválida." ;;
    esac
  done
}

select_web_service() {
  local option
  echo "Servicio web para completar despliegue:"
  echo "1. nginx"
  echo "2. apache2"
  echo "3. Otro servicio Apache/Nginx"
  echo

  while true; do
    read -r -p "Selecciona servicio: " option
    case "$option" in
      1) WEB_SERVICE="nginx"; return 0 ;;
      2) WEB_SERVICE="apache2"; return 0 ;;
      3)
        read -r -p "Nombre exacto del servicio systemd: " WEB_SERVICE
        if [[ -n "${WEB_SERVICE// }" ]]; then
          return 0
        fi
        echo "El nombre del servicio no puede estar vacío."
        ;;
      *) echo "Opción inválida." ;;
    esac
  done
}

find_angular_dist_dir() {
  local project_dir="$1"
  local dist_base="$project_dir/dist"

  if [[ ! -d "$dist_base" ]]; then
    return 1
  fi

  local candidates=()
  local item
  shopt -s nullglob
  for item in "$dist_base"/*; do
    [[ -d "$item" ]] && candidates+=("$item")
  done
  shopt -u nullglob

  if (( ${#candidates[@]} == 1 )); then
    echo "${candidates[0]}"
    return 0
  fi

  if (( ${#candidates[@]} > 1 )); then
    echo "Carpetas encontradas en dist:" >&2
    local i option
    for i in "${!candidates[@]}"; do
      echo "$((i + 1)). $(basename "${candidates[$i]}")" >&2
    done
    while true; do
      read -r -p "Selecciona carpeta compilada: " option
      if [[ "$option" =~ ^[0-9]+$ ]] && (( option >= 1 && option <= ${#candidates[@]} )); then
        echo "${candidates[$((option - 1))]}"
        return 0
      fi
      echo "Opción inválida." >&2
    done
  fi

  return 1
}

# ==============================================================================
# Menú Angular - Opción 1. Detener Aplicación
# ==============================================================================
angular_stop_app() {
  echo "----- Angular - Detener Aplicación -----"
  select_web_service
  run_cmd $SUDO_CMD systemctl stop "$WEB_SERVICE" || true
}

# ==============================================================================
# Menú Angular - Opción 2. Eliminar Compilado
# ==============================================================================
angular_delete_build() {
  echo "----- Angular - Eliminar Compilado -----"
  select_project || return 1

  if [[ -d "$SELECTED_PROJECT/dist" ]]; then
    if ask_yes_no "¿Confirmas eliminar la carpeta dist del proyecto?"; then
      run_cmd rm -rf "$SELECTED_PROJECT/dist"
    fi
  else
    echo "No existe carpeta dist en el proyecto."
  fi
}

# ==============================================================================
# Menú Angular - Opción 3. Instalar Dependencias
# ==============================================================================
angular_install_dependencies() {
  echo "----- Angular - Instalar Dependencias -----"
  select_project || return 1
  ensure_command node nodejs

  if [[ -f "$SELECTED_PROJECT/package-lock.json" ]]; then
    run_cmd bash -lc "cd '$SELECTED_PROJECT' && npm ci"
  else
    run_cmd bash -lc "cd '$SELECTED_PROJECT' && npm install"
  fi
}

# ==============================================================================
# Menú Angular - Opción 4. Generar Compilado
# ==============================================================================
angular_generate_build() {
  echo "----- Angular - Generar Compilado -----"
  select_project || return 1
  select_build_configuration

  if [[ ! -f "$SELECTED_PROJECT/node_modules/@angular/cli/bin/ng" ]]; then
    echo "No existe Angular CLI local en node_modules. Ejecuta primero Instalar Dependencias."
    return 1
  fi

  run_cmd bash -lc "cd '$SELECTED_PROJECT' && node node_modules/@angular/cli/bin/ng build -c=$ANGULAR_CONFIG"
}

# ==============================================================================
# Menú Angular - Opción 5. Publicar Compilado en Servicio Web
# ==============================================================================
angular_publish_build() {
  echo "----- Angular - Publicar Compilado en Servicio Web -----"
  select_project || return 1
  select_web_service

  local dist_dir
  local target_dir
  dist_dir="$(find_angular_dist_dir "$SELECTED_PROJECT" || true)"

  if [[ -z "${dist_dir:-}" || ! -d "$dist_dir" ]]; then
    echo "ERROR: No se encontró carpeta compilada dentro de dist."
    return 1
  fi

  read -r -p "Ruta destino web [/var/www/html/${SELECTED_PROJECT_NAME}]: " target_dir
  target_dir="${target_dir:-/var/www/html/${SELECTED_PROJECT_NAME}}"

  run_cmd $SUDO_CMD mkdir -p "$target_dir"
  run_cmd $SUDO_CMD rsync -av --delete "$dist_dir/" "$target_dir/"
  run_cmd $SUDO_CMD chown -R www-data:www-data "$target_dir" || true
  run_cmd $SUDO_CMD systemctl restart "$WEB_SERVICE"
  run_cmd $SUDO_CMD systemctl --no-pager status "$WEB_SERVICE" || true

  echo "Compilado publicado en: $target_dir"
}

# ==============================================================================
# Menú Angular - Opción 6. Reiniciar Servicio Web
# ==============================================================================
angular_restart_web_service() {
  echo "----- Angular - Reiniciar Servicio Web -----"
  select_web_service
  run_cmd $SUDO_CMD systemctl restart "$WEB_SERVICE"
  run_cmd $SUDO_CMD systemctl --no-pager status "$WEB_SERVICE" || true
}

# ==============================================================================
# Menú Angular - Opción 7. Flujo Continuo Completo
# ==============================================================================
angular_continuous_flow() {
  echo "----- Angular - Flujo Continuo Completo -----"
  select_project || return 1
  select_build_configuration
  select_web_service

  local target_dir
  local dist_dir

  echo "1. Deteniendo servicio web..."
  run_cmd $SUDO_CMD systemctl stop "$WEB_SERVICE" || true

  echo "2. Eliminando compilado anterior..."
  run_cmd rm -rf "$SELECTED_PROJECT/dist"

  echo "3. Instalando dependencias si hace falta..."
  if [[ ! -d "$SELECTED_PROJECT/node_modules" ]]; then
    if [[ -f "$SELECTED_PROJECT/package-lock.json" ]]; then
      run_cmd bash -lc "cd '$SELECTED_PROJECT' && npm ci"
    else
      run_cmd bash -lc "cd '$SELECTED_PROJECT' && npm install"
    fi
  else
    echo "node_modules ya existe. Se omite npm install/npm ci."
  fi

  echo "4. Generando compilado Angular..."
  run_cmd bash -lc "cd '$SELECTED_PROJECT' && node node_modules/@angular/cli/bin/ng build -c=$ANGULAR_CONFIG"

  echo "5. Publicando compilado..."
  dist_dir="$(find_angular_dist_dir "$SELECTED_PROJECT" || true)"
  if [[ -z "${dist_dir:-}" || ! -d "$dist_dir" ]]; then
    echo "ERROR: No se encontró carpeta compilada dentro de dist."
    run_cmd $SUDO_CMD systemctl start "$WEB_SERVICE" || true
    return 1
  fi

  read -r -p "Ruta destino web [/var/www/html/${SELECTED_PROJECT_NAME}]: " target_dir
  target_dir="${target_dir:-/var/www/html/${SELECTED_PROJECT_NAME}}"

  run_cmd $SUDO_CMD mkdir -p "$target_dir"
  run_cmd $SUDO_CMD rsync -av --delete "$dist_dir/" "$target_dir/"
  run_cmd $SUDO_CMD chown -R www-data:www-data "$target_dir" || true

  echo "6. Reiniciando servicio web..."
  run_cmd $SUDO_CMD systemctl restart "$WEB_SERVICE"
  run_cmd $SUDO_CMD systemctl --no-pager status "$WEB_SERVICE" || true
}

# ==============================================================================
# Submenú Angular
# ==============================================================================
show_angular_menu() {
  clear || true
  echo "=============================================="
  echo "        DESPLEGAR PROYECTOS - ANGULAR"
  echo "=============================================="
  echo "1. Detener Aplicación"
  echo "2. Eliminar Compilado"
  echo "3. Instalar Dependencias"
  echo "4. Generar Compilado"
  echo "5. Publicar Compilado en Servicio Web"
  echo "6. Reiniciar Servicio Web"
  echo "7. Flujo Continuo Completo"
  echo "0. Volver"
  echo "=============================================="
}

angular_deploy_menu() {
  local option
  while true; do
    show_angular_menu
    read -r -p "Selecciona una opción: " option
    echo
    case "$option" in
      1) angular_stop_app; pause_menu ;;
      2) angular_delete_build; pause_menu ;;
      3) angular_install_dependencies; pause_menu ;;
      4) angular_generate_build; pause_menu ;;
      5) angular_publish_build; pause_menu ;;
      6) angular_restart_web_service; pause_menu ;;
      7) angular_continuous_flow; pause_menu ;;
      0) return 0 ;;
      *) echo "Opción no válida."; pause_menu ;;
    esac
  done
}


# ==============================================================================
# Menú Principal - Opción 8. Volver a Commit Anterior
# ==============================================================================
select_recent_commit() {
  local project_dir="$1"
  local commits=()
  local option
  local selected_line

  mapfile -t commits < <(git -C "$project_dir" log -n 10 --date=short --pretty=format:'%h | %ad | %s')

  if (( ${#commits[@]} == 0 )); then
    echo "No se encontraron commits recientes en este proyecto."
    return 1
  fi

  echo "Últimos 10 commits disponibles:"
  echo

  if command -v fzf >/dev/null 2>&1; then
    selected_line="$(printf '%s\n' "${commits[@]}" | fzf --prompt='Selecciona commit: ' --height=40% --border)" || return 1
    ROLLBACK_COMMIT="${selected_line%% | *}"
    return 0
  fi

  local i
  for i in "${!commits[@]}"; do
    echo "$((i + 1)). ${commits[$i]}"
  done
  echo "0. Cancelar"
  echo

  while true; do
    read -r -p "Selecciona el commit: " option
    if [[ "$option" == "0" ]]; then
      echo "Operación cancelada."
      return 1
    fi
    if [[ "$option" =~ ^[0-9]+$ ]] && (( option >= 1 && option <= ${#commits[@]} )); then
      selected_line="${commits[$((option - 1))]}"
      ROLLBACK_COMMIT="${selected_line%% | *}"
      return 0
    fi
    echo "Opción inválida. Selecciona un número de la lista."
  done
}

rollback_project_commit() {
  echo "----- 8. Volver a Commit Anterior -----"
  select_project || return 1

  if [[ ! -d "$SELECTED_PROJECT/.git" ]]; then
    echo "ERROR: El proyecto seleccionado no parece ser un repositorio Git."
    return 1
  fi

  echo "Proyecto seleccionado: $SELECTED_PROJECT_NAME"
  echo "Ruta               : $SELECTED_PROJECT"
  echo
  run_cmd git -C "$SELECTED_PROJECT" status --short
  echo

  if [[ -n "$(git -C "$SELECTED_PROJECT" status --porcelain)" ]]; then
    echo "AVISO: El proyecto tiene cambios locales sin confirmar."
    if ! ask_yes_no "¿Deseas continuar con el checkout de todas formas?"; then
      echo "Operación cancelada."
      return 1
    fi
  fi

  echo "Método para seleccionar el commit:"
  echo "1. Seleccionar entre los últimos 10 commits"
  echo "2. Escribir commit manualmente"
  echo "0. Cancelar"
  echo

  local method
  while true; do
    read -r -p "Selecciona una opción: " method
    case "$method" in
      1)
        select_recent_commit "$SELECTED_PROJECT" || return 1
        break
        ;;
      2)
        read -r -p "Escribe el hash del commit: " ROLLBACK_COMMIT
        ROLLBACK_COMMIT="${ROLLBACK_COMMIT// /}"
        if [[ -z "$ROLLBACK_COMMIT" ]]; then
          echo "ERROR: El commit no puede estar vacío."
          return 1
        fi
        break
        ;;
      0)
        echo "Operación cancelada."
        return 1
        ;;
      *) echo "Opción inválida." ;;
    esac
  done

  if ! git -C "$SELECTED_PROJECT" rev-parse --verify "${ROLLBACK_COMMIT}^{commit}" >/dev/null 2>&1; then
    echo "ERROR: El commit '$ROLLBACK_COMMIT' no existe en este repositorio."
    return 1
  fi

  echo
  echo "Commit seleccionado:"
  git -C "$SELECTED_PROJECT" log -1 --oneline "$ROLLBACK_COMMIT"
  echo

  if ask_yes_no "¿Confirmas volver a este commit con git checkout?"; then
    run_cmd git -C "$SELECTED_PROJECT" checkout "$ROLLBACK_COMMIT"
    run_cmd $SUDO_CMD chown -R "$APP_USER:$APP_USER" "$SELECTED_PROJECT"
    echo
    echo "Estado actual del repositorio:"
    run_cmd git -C "$SELECTED_PROJECT" status -sb
    echo
    echo "Commit activo:"
    run_cmd git -C "$SELECTED_PROJECT" log -1 --oneline
    echo
    echo "Nota: quedaste en modo detached HEAD. Para volver a la rama principal puedes usar:"
    echo "git -C '$SELECTED_PROJECT' checkout main"
    echo "o la rama que uses en tu proyecto."
  else
    echo "Operación cancelada."
  fi
}

# ==============================================================================
# Menú Principal - Opción 9. Desplegar Proyectos
# ==============================================================================
deploy_projects_menu() {
  local option
  while true; do
    clear || true
    echo "=============================================="
    echo "        9. Desplegar Proyectos"
    echo "=============================================="
    echo "1. Caso Python"
    echo "2. Caso Angular"
    echo "0. Volver"
    echo "=============================================="
    read -r -p "Selecciona una opción: " option
    echo

    case "$option" in
      1) python_deploy_menu ;;
      2) angular_deploy_menu ;;
      0) return 0 ;;
      *) echo "Opción no válida."; pause_menu ;;
    esac
  done
}

# ==============================================================================
# Menú Principal
# ==============================================================================
show_main_menu() {
  load_config
  clear || true
  echo "=============================================="
  echo "        MENÚ GIT + DESPLIEGUE PROYECTOS"
  echo "=============================================="
  echo "Usuario actual       : $(whoami)"
  echo "Usuario configurado  : $APP_USER"
  echo "Directorio Git       : $GIT_DIR"
  echo "Config               : $CONFIG_FILE"
  echo "=============================================="
  echo "1. Configurar Directorio"
  echo "2. Visualizar Directorio"
  echo "3. Listar Proyectos Descargados"
  echo "4. Descargar Proyecto"
  echo "5. Eliminar Proyectos"
  echo "6. Descargar Cambios"
  echo "7. Cambiar Branch"
  echo "8. Volver a Commit Anterior"
  echo "9. Desplegar Proyectos"
  echo "0. Salir"
  echo "=============================================="
}

main() {
  load_config
  local option

  while true; do
    show_main_menu
    read -r -p "Selecciona una opción: " option
    echo

    case "$option" in
      1) configure_directory; pause_menu ;;
      2) show_directory; pause_menu ;;
      3) list_downloaded_projects; pause_menu ;;
      4) download_project; pause_menu ;;
      5) delete_project; pause_menu ;;
      6) pull_project_changes; pause_menu ;;
      7) change_project_branch; pause_menu ;;
      8) rollback_project_commit; pause_menu ;;
      9) deploy_projects_menu ;;
      0) echo "Saliendo del menú Git + Despliegue."; exit 0 ;;
      *) echo "Opción no válida."; pause_menu ;;
    esac
  done
}

main "$@"
