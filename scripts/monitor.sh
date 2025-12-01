#!/bin/bash
# =============================================================================
# Скрипт мониторинга веб-приложения
# Проверяет доступность приложения и перезапускает его при сбое
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$(dirname "$LOG_FILE")"
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    echo "[$timestamp] [$level] $message"
}

# Функция проверки доступности приложения
# Возвращает 0 если приложение доступно, 1 если нет
check_app_health() {
    local response
    local http_code
    
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$HEALTH_CHECK_TIMEOUT" \
        "$HEALTH_CHECK_URL" 2>/dev/null)
    
    if [[ "$http_code" == "200" ]]; then
        return 0
    else
        return 1
    fi
}

start_app() {
    log_message "INFO" "Starting application..."
    
    if [[ ! -f "$APP_BINARY" ]]; then
        log_message "ERROR" "Application binary not found: $APP_BINARY"
        
        if [[ -f "$APP_SOURCE" ]]; then
            log_message "INFO" "Compiling application from source..."
            cd "$(dirname "$APP_SOURCE")" && go build -o "$APP_BINARY" "$APP_SOURCE"
            if [[ $? -ne 0 ]]; then
                log_message "ERROR" "Failed to compile application"
                return 1
            fi
        else
            log_message "ERROR" "Source file not found: $APP_SOURCE"
            return 1
        fi
    fi
    
    export APP_PORT="$APP_PORT"
    nohup "$APP_BINARY" >> "$APP_LOG_FILE" 2>&1 &
    local pid=$!
    
    # Сохраняем PID в файл
    echo "$pid" > "$PID_FILE"
    
    log_message "INFO" "Application started with PID: $pid"
    
    # Даем приложению время на запуск
    sleep 2
    
    # Проверяем, запустилось ли приложение
    if check_app_health; then
        log_message "INFO" "Application is now healthy"
        return 0
    else
        log_message "WARNING" "Application started but health check failed"
        return 1
    fi
}

stop_app() {
    log_message "INFO" "Stopping application..."
    
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            sleep 1
            # Если процесс еще работает, убиваем принудительно
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid"
            fi
            log_message "INFO" "Application stopped (PID: $pid)"
        fi
        rm -f "$PID_FILE"
    fi
    
    # Также убиваем процессы по порту (на случай зависших)
    local pids=$(lsof -t -i:"$APP_PORT" 2>/dev/null)
    if [[ -n "$pids" ]]; then
        echo "$pids" | xargs kill -9 2>/dev/null
        log_message "INFO" "Killed processes on port $APP_PORT"
    fi
}

restart_app() {
    log_message "INFO" "Restarting application..."
    stop_app
    sleep 1
    start_app
}

main() {
    log_message "INFO" "Monitor check started"
    
    if check_app_health; then
        log_message "INFO" "Application is healthy at $HEALTH_CHECK_URL"
    else
        log_message "WARNING" "Application is NOT responding at $HEALTH_CHECK_URL"
        log_message "INFO" "Attempting to restart application..."
        
        restart_app
        
        if check_app_health; then
            log_message "INFO" "Application successfully restarted"
        else
            log_message "ERROR" "Failed to restart application"
        fi
    fi
}

main
