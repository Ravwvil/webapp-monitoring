#!/bin/bash
# =============================================================================
# Скрипт установки и обновления системы мониторинга
# Запускать с правами root
# =============================================================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Директория установки
# По умолчанию — директория репозитория (SOURCE_DIR). Можно переопределить
# через переменную окружения `INSTALL_DIR` при запуске установщика.
INSTALL_DIR="${INSTALL_DIR:-$SOURCE_DIR}"

# Директория с исходными файлами
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v go &> /dev/null; then
        log_error "Go is not installed. Please install Go first."
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed. Please install curl first."
        exit 1
    fi
    
    log_info "All dependencies are satisfied"
}

create_directories() {
    log_info "Creating directories..."
    
    mkdir -p "$INSTALL_DIR/app"
    mkdir -p "$INSTALL_DIR/scripts"
    mkdir -p "$INSTALL_DIR/logs"
    
    log_info "Directories created"
}

copy_files() {
    log_info "Copying files..."
    
    # Если INSTALL_DIR совпадает с SOURCE_DIR — мы работаем прямо в клонированном репо,
    # копирование не требуется. Иначе — копируем файлы в целевую директорию.
    if [[ "$INSTALL_DIR" == "$SOURCE_DIR" ]]; then
        log_info "INSTALL_DIR == SOURCE_DIR; using files in-place (no copy)"
    else
        # Копируем файлы приложения и скрипты
        cp -r "$SOURCE_DIR/app" "$INSTALL_DIR/"
        cp -r "$SOURCE_DIR/scripts" "$INSTALL_DIR/"
    fi

    # Убеждаемся, что скрипты исполняемые (если они существуют в INSTALL_DIR)
    if [[ -f "$INSTALL_DIR/scripts/monitor.sh" ]]; then
        chmod +x "$INSTALL_DIR/scripts/monitor.sh"
    fi
    if [[ -f "$INSTALL_DIR/scripts/config.sh" ]]; then
        chmod +x "$INSTALL_DIR/scripts/config.sh"
    fi

    log_info "Files copied / verified"
}

# Компиляция Go приложения
build_app() {
    log_info "Building Go application..."
    
    cd "$INSTALL_DIR/app"
    go build -o webapp main.go
    
    log_info "Application built successfully"
}

# Установка systemd сервисов
install_systemd_services() {
    log_info "Installing systemd services..."
    
    # Копируем unit файлы, заменяя в них путь /opt/webapp-monitoring на фактический INSTALL_DIR
    # (если в юнитах есть абсолютные пути). Это позволяет инсталлировать из любой директории.
    for unit in webapp.service webapp-monitor.service webapp-monitor.timer; do
        if [[ -f "$SOURCE_DIR/systemd/$unit" ]]; then
            sed "s|/opt/webapp-monitoring|$INSTALL_DIR|g" "$SOURCE_DIR/systemd/$unit" > "/etc/systemd/system/$unit"
        fi
    done
    
    # Перезагружаем конфигурацию systemd
    systemctl daemon-reload
    
    # Включаем и запускаем сервисы
    systemctl enable webapp.service
    systemctl enable webapp-monitor.timer
    
    systemctl start webapp.service
    systemctl start webapp-monitor.timer
    
    log_info "Systemd services installed and started"
}

show_status() {
    log_info "Installation complete!"
    echo ""
    echo "=== Status ==="
    echo "Application service: $(systemctl is-active webapp.service)"
    echo "Monitor timer: $(systemctl is-active webapp-monitor.timer)"
    echo ""
    echo "=== Useful commands ==="
    echo "View app logs:      journalctl -u webapp.service -f"
    echo "View monitor logs:  tail -f $INSTALL_DIR/logs/monitor.log"
    echo "Restart app:        systemctl restart webapp.service"
    echo "Check app health:   curl http://localhost:8080/health"
    echo ""
}

main() {
    echo "=== Webapp Monitoring System Installer ==="
    echo ""
    
    check_root
    check_dependencies
    create_directories
    copy_files
    build_app
    install_systemd_services
    show_status
}

main "$@"