#!/bin/bash

# Ruta del archivo de configuración de red en AntiX
INTERFAZ_FILE="/etc/network/interfaces"

# =====================================================================
# PARTE 1: INSTALADOR (Solo se ejecuta si entras con sudo desde el curl)
# =====================================================================
if [ "$(id -u)" -eq 0 ]; then
    echo "Instalando el menú de red en el inicio de la VM..."
    
    # Detectar el usuario real que lanzó el sudo (iagoxr)
    REAL_USER=${SUDO_USER:-$USER}
    USER_HOME=$(eval echo ~$REAL_USER)

    # Descargar el script definitivo en la carpeta del usuario
    curl -sSL https://raw.githubusercontent.com/IAGOXRDev/ArfDownloads/main/setup.sh -o "$USER_HOME/menu_red.sh"
    chmod +x "$USER_HOME/menu_red.sh"
    chown $REAL_USER:$REAL_USER "$USER_HOME/menu_red.sh"

    # Añadirlo al .bashrc de forma limpia si no está ya
    if ! grep -q "menu_red.sh" "$USER_HOME/.bashrc"; then
        echo -e "\n# Lanzar menu de red al iniciar\nif [ -f ~/menu_red.sh ]; then\n    ~/menu_red.sh\nfi" >> "$USER_HOME/.bashrc"
    fi

    echo "¡Instalación completada con éxito!"
    echo "Cierra esta terminal y vuelve a entrar por SSH para probarlo."
    exit 0
fi

# =====================================================================
# PARTE 2: EL MENÚ INTERACTIVO (Solo se ejecuta al iniciar sesión)
# =====================================================================
while true; do
    clear
    CURRENT_IP=$(ip route get 1 2>/dev/null | awk '{print $7;exit}')
    [ -z "$CURRENT_IP" ] && CURRENT_IP="Sin conexión"

    if grep -q "iface .* static" "$INTERFAZ_FILE" 2>/dev/null; then
        STATUS="Enabled"
    else
        STATUS="Disabled"
    fi

    echo "================================================="
    echo " [Your IP: $CURRENT_IP][IPStatic Status: $STATUS]"
    echo "================================================="
    echo ""
    echo "1. Restart VM"
    echo "2. Apply StaticIP"
    echo "3. Remove StaticIP"
    echo "4. Exit Menu"
    echo ""
    
    # El truco: Forzamos a 'read' a escuchar el teclado real (/dev/tty) 
    # por si queda algún rastro del pipe de internet de curl
    read -p "Select an option [1-4]: " OPTION < /dev/tty

    case $OPTION in
        1)
            echo "Reiniciando la máquina..."
            sleep 1
            sudo reboot
            ;;
        2)
            echo "Aplicando configuración de IP Estática..."
            sudo cp "$INTERFAZ_FILE" "${INTERFAZ_FILE}.bak"
            IFACE=$(ip route show default | awk '{print $5}')
            GATEWAY=$(ip route show default | awk '{print $3}')
            
            sudo bash -c "cat <<EOF > $INTERFAZ_FILE
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet static
    address $CURRENT_IP
    netmask 255.255.255.0
    gateway $GATEWAY
    dns-nameservers 8.8.8.8 1.1.1.1
EOF"
            sudo ifdown $IFACE && sudo ifup $IFACE
            echo "¡IP Estática aplicada!"
            sleep 2
            ;;
        3)
            echo "Removiendo configuración estática (DHCP)..."
            IFACE=$(ip route show default | awk '{print $5}')
            [ -z "$IFACE" ] && IFACE=$(awk '/iface/ {print $2}' $INTERFAZ_FILE | grep -v "lo" | head -n 1)

            sudo bash -c "cat <<EOF > $INTERFAZ_FILE
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet dhcp
EOF"
            sudo ifdown $IFACE && sudo ifup $IFACE
            echo "¡Volviendo a DHCP!"
            sleep 2
            ;;
        4)
            echo "Saliendo al shell..."
            break
            ;;
        *)
            echo "Opción no válida: '$OPTION'"
            sleep 1
            ;;
    esac
done
