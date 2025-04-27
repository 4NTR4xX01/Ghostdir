#!/bin/bash

verde='\033[0;32m'
rojo='\033[0;31m'
amarillo='\033[1;33m'
cyan='\033[0;36m'
reset='\033[0m'

echo -e "${rojo}


 ▄▀▀▀▀▄   ▄▀▀▄ ▄▄   ▄▀▀▀▀▄   ▄▀▀▀▀▄  ▄▀▀▀█▀▀▄  ▄▀▀█▄▄   ▄▀▀█▀▄    ▄▀▀▄▀▀▀▄ 
█        █  █   ▄▀ █      █ █ █   ▐ █    █  ▐ █ ▄▀   █ █   █  █  █   █   █ 
█    ▀▄▄ ▐  █▄▄▄█  █      █    ▀▄   ▐   █     ▐ █    █ ▐   █  ▐  ▐  █▀▀█▀  
█     █ █   █   █  ▀▄    ▄▀ ▀▄   █     █        █    █     █      ▄▀    █  
▐▀▄▄▄▄▀ ▐  ▄▀  ▄▀    ▀▀▀▀    █▀▀▀    ▄▀        ▄▀▄▄▄▄▀  ▄▀▀▀▀▀▄  █     █   
▐         █   █              ▐      █         █     ▐  █       █ ▐     ▐   
          ▐   ▐                     ▐         ▐        ▐       ▐           
                                    by: 4NTR4xX
${reset}"

if [ -z "$1" ]; then
    echo -e "${amarillo}Uso: $0 <dominio.com>${reset}"
    exit 1
fi

DOMINIO=$1
OUTPUT_DIR="enumeracion_$DOMINIO"
mkdir -p "$OUTPUT_DIR"

echo -e "${cyan}[*] Iniciando enumeración pasiva para: $DOMINIO${reset}"
sleep 1

# --- Funciones ---

function recolectar_wayback() {
    echo -e "${verde}[+] Recolectando desde Wayback Machine...${reset}"
    waybackurls "$DOMINIO" 2>/dev/null > "$OUTPUT_DIR/wayback.txt"
}

function recolectar_gau() {
    echo -e "${verde}[+] Recolectando desde gau...${reset}"
    gau "$DOMINIO" 2>/dev/null > "$OUTPUT_DIR/gau.txt"
}

function recolectar_commoncrawl() {
    echo -e "${verde}[+] Recolectando desde Common Crawl...${reset}"
    curl -s "http://index.commoncrawl.org/CC-MAIN-2023-40-index?url=*.$DOMINIO&output=json" | jq -r '.url' > "$OUTPUT_DIR/commoncrawl.txt"
}

function recolectar_crtsh() {
    echo -e "${verde}[+] Recolectando subdominios de crt.sh...${reset}"
    curl -s "https://crt.sh/?q=%25.$DOMINIO&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u > "$OUTPUT_DIR/crtsh_subdomains.txt"
}

function recolectar_amass() {
    echo -e "${verde}[+] Recolectando subdominios con amass (pasivo)...${reset}"
    timeout 180s amass enum -passive -d "$DOMINIO" 2>/dev/null > "$OUTPUT_DIR/amass_subdomains.txt"
}

function procesar_urls() {
    echo -e "${cyan}[*] Procesando y extrayendo rutas únicas...${reset}"
    cat "$OUTPUT_DIR"/*.txt | sort -u | grep "^http" | \
    sed -E 's|https?://[^/]+||' | \
    grep "/" | sort -u > "$OUTPUT_DIR/directorios_finales.txt"
}

function detectar_archivos_sensibles() {
    echo -e "${cyan}[*] Buscando archivos sensibles...${reset}"
    grep -Ei "\.(bak|zip|tar\.gz|sql|env|git|db|config|backup|old)" "$OUTPUT_DIR/directorios_finales.txt" > "$OUTPUT_DIR/archivos_sensibles.txt"
}

function exportar_csv() {
    echo -e "${cyan}[*] Exportando resultados a CSV...${reset}"
    echo "Directorio" > "$OUTPUT_DIR/directorios.csv"
    cat "$OUTPUT_DIR/directorios_finales.txt" >> "$OUTPUT_DIR/directorios.csv"
}

function exportar_html() {
    echo -e "${cyan}[*] Exportando resultados a HTML interactivo...${reset}"
    {
        echo "<html><head><title>Enumeración de $DOMINIO</title></head><body><h1>Resultados para $DOMINIO</h1><ul>"
        for url in $(cat "$OUTPUT_DIR/directorios_finales.txt"); do
            echo "<li><a href='https://$DOMINIO$url' target='_blank'>$url</a></li>"
        done
        echo "</ul></body></html>"
    } > "$OUTPUT_DIR/directorios.html"
}

function crear_wordlist() {
    echo -e "${cyan}[*] Creando wordlist para fuzzing...${reset}"
    cat "$OUTPUT_DIR/directorios_finales.txt" | sed 's/^\///' | sed 's/\/$//' | awk -F'/' '{print $NF}' | sort -u > "$OUTPUT_DIR/directorio_wordlist.txt"
}

# --- Ejecución ---

recolectar_wayback
recolectar_gau
recolectar_commoncrawl
recolectar_crtsh
recolectar_amass
procesar_urls
detectar_archivos_sensibles
exportar_csv
exportar_html
crear_wordlist

echo -e "${verde}[+] Enumeración completada exitosamente.${reset}"
echo -e "${amarillo}[*] Resultados guardados en carpeta: $OUTPUT_DIR${reset}"
echo -e "${cyan}[*] Archivos generados:${reset}"
ls "$OUTPUT_DIR"