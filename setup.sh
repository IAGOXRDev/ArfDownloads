#!/bin/bash

# 1. Asegurar que el script se ejecute como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (usando sudo)."
  exit 1
fi

echo "=== 1. Instalando y configurando OpenSSH Server ==="
# Actualizar lista de paquetes e instalar SSH de forma silenciosa
apt update && apt install -y openssh-server

# Asegurar que el servicio esté activo y arranque con el sistema
systemctl enable --now ssh

echo "=== 2. Detectando IP actual de la VM ==="
# Detectar la IP actual de la interfaz eth0
IP_ACTUAL=$(ip -o -4 addr show dev eth0 | awk '{print $4}')

if [ -z "$IP_ACTUAL" ]; then
  echo "Error: No se pudo detectar una IP activa en la interfaz eth0."
  exit 1
fi

echo "=== 3. Actualizando configuración de Netplan ==="
# Sobrescribir el archivo de Netplan
cat << EOF > /etc/netplan/01-netcfg.yaml
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - $IP_ACTUAL
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF

# Aplicar los cambios
netplan apply

# Limpiar posibles archivos temporales molestos de nano si existieran
if [ -f /etc/netplan/.01-netcfg.yaml.swp ]; then
  rm /etc/netplan/.01-netcfg.yaml.swp
fi

echo "=================================================="
echo "          ¡PROCESO COMPLETADO CON ÉXITO!          "
echo "=================================================="
echo " La IP estática configurada en la VM es:"
echo " >> $IP_ACTUAL <<"
echo " El servicio SSH ya está activo en esta IP."
echo "=================================================="