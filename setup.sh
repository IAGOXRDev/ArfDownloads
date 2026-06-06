#!/bin/bash

# Ruta del archivo de configuración de red en AntiX
INTERFAZ_FILE="/etc/network/interfaces"

# =====================================================================
# PARTE 1: INSTALADOR (Se ejecuta una sola vez con tu comando curl | sudo bash)
# =====================================================================
if [ "$(id -u)" -eq 0 ]; then
    echo "Instalando el menú de red en el inicio de la VM..."
    
    # Detectar el usuario real (iagoxr)
    REAL_USER=${SUDO_USER:-$USER}
    USER_HOME=$(eval echo ~$REAL_USER)

    # 1. Guardar el script en la carpeta del usuario
    curl -sSL https://raw.githubusercontent.com/IAGOXRDev/ArfDownloads/main/setup.sh -o "$USER_HOME/menu_red.sh"
    chmod +x "$USER_HOME/menu_red.sh"
    chown $REAL_USER:$REAL_USER "$USER_HOME/menu_red.sh"

    # 2. Configurar el autoarranque gráfico exclusivo para herbstluftwm
    HLWM_CONFIG_DIR="$USER_HOME/.config/herbstluftwm"
    mkdir -p "$HLWM_CONFIG_DIR"

    # Si no existe el archivo autostart de herbstluftwm, creamos uno básico
    if [ ! -f "$HLWM_CONFIG_DIR/autostart" ]; then
        # Intentamos copiar el de plantilla de AntiX
        if [ -f /etc/xdg/herbstluftwm/autostart ]; then
            cp /etc/xdg/herbstluftwm/autostart "$HLWM_CONFIG_DIR/autostart"
        else
            echo "#!/bin/bash" > "$HLWM_CONFIG_DIR/autostart"
        fi
        chmod +x "$HLWM_CONFIG_DIR/autostart"
        chown -R $REAL_USER:$REAL_USER "$HLWM_CONFIG_DIR"
    fi

    # Inyectamos la orden para que herbstluftwm abra UNA terminal ejecutando el menú en la VM
    if ! grep -q "menu_red.sh" "$HLWM_CONFIG_DIR/autostart"; then
        echo -e "\n# Abrir una terminal con el menú de red en la pantalla de la VM\ndesktop-defaults-run-terminal --command \"$USER_HOME/menu_red.sh\" &" >> "$HLWM_CONFIG_DIR/autostart"
    fi

    # 3. LIMPIEZA IMPORTANTE: Quitamos el script de ~/.bashrc si se había quedado ahí de antes,
    # para evitar que te salte doble por SSH o que corrompa la consola normal.
    if [ -f "$USER_HOME/.bashrc" ]; then
        sed -i '/menu_red.sh/d' "$USER_HOME/.bashrc"
    fi

    echo "¡Instalación completada con éxito!"
    echo "A partir de ahora, al arrancar la VM en herbstluftwm, se abrirá una terminal con el menú en tu pantalla."
    exit 0
fi

# =====================================================================
# PARTE 2: EL MENÚ INTERACTIVO (Lo que se abrirá automáticamente dentro de la terminal)
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
    
    # Escuchamos la entrada estándar de la ventana de la terminal activa
    read -p "Select an option [1-4]: " OPTION

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
            echo "Cerrando ventana..."
            exit 0
            ;;
        *)
            echo "Opción no válida: '$OPTION'"
            sleep 1
            ;;
    esac
done
