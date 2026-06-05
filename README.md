# Flujos de configuración para Ubuntu

Este paquete contiene scripts independientes para preparar un servidor Ubuntu en la nube.

## Orden sugerido de ejecución

```bash
chmod +x *.sh
./ubuntu.sh
./srvc_ssh.sh
./srvc_mysql.sh
./srvc_nginx.sh
./lib_git.sh
./lib_pyenv.sh
./lib_nvm.sh
```

## Archivos

- `ubuntu.sh`: actualización del sistema, UFW y apertura de puertos.
- `srvc_ssh.sh`: instalación, arranque, puerto y firewall de SSH.
- `srvc_mysql.sh`: instalación, arranque, puerto, firewall y seguridad inicial de MySQL.
- `srvc_nginx.sh`: instalación, arranque, puerto, firewall y validación de Nginx.
- `lib_git.sh`: instalación y configuración global de Git.
- `lib_pyenv.sh`: instalación de pyenv y una versión de Python.
- `lib_nvm.sh`: instalación de nvm y una versión de Node.js.

## Recomendaciones

Ejecuta primero en un servidor de pruebas, revisa cada comando antes de confirmar cambios de puertos y guarda capturas de pantalla para las evidencias de la actividad.
