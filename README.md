# Flujos de configuración para Ubuntu

Este paquete contiene scripts independientes para preparar un servidor Ubuntu en la nube.

## Orden sugerido de ejecución

```bash
# Dar permisos de ejecución a todos los scripts
chmod +x default/*.sh library/*.sh service/*.sh

# 1. Configuración base del sistema y firewall
./default/system.sh
./default/firewall.sh

# 2. Servicios esenciales
./service/srvc_ssh.sh
./service/srvc_mysql.sh
./service/srvc_nginx.sh

# 3. Librerías y entornos de desarrollo
./library/lib_git.sh
./library/lib_pyenv.sh
./library/lib_nvm.sh
```

## Archivos y Rutas

### 📁 default/ (Configuración Base)
- `system.sh`: Administración de tareas básicas del SO (actualizaciones, limpieza y consultas).
- `firewall.sh`: Administración interactiva del firewall UFW (puertos, reglas y estado).

### 📁 service/ (Servicios)
- `srvc_ssh.sh`: Instalación y gestión del servicio SSH (puerto, firewall y logs).
- `srvc_mysql.sh`: Instalación y gestión de MySQL Server (puerto, firewall y seguridad).
- `srvc_nginx.sh`: Instalación y gestión de Nginx (puerto, firewall y validación).

### 📁 library/ (Librerías y Entornos)
- `lib_git.sh`: Instalación y configuración global de Git (usuario, email y credenciales).
- `lib_pyenv.sh`: Gestión de pyenv y versiones de Python.
- `lib_nvm.sh`: Gestión de NVM y versiones de Node.js.

## Recomendaciones

Ejecuta primero en un servidor de pruebas, revisa cada comando antes de confirmar cambios de puertos y guarda capturas de pantalla para las evidencias de la actividad.
