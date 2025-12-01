#!/bin/bash
# =============================================================================
# Конфигурационный файл для системы мониторинга
# Все параметры можно изменять для настройки под конкретное окружение
# =============================================================================

# По умолчанию используем директорию репозитория (родительскую для scripts)
# Можно переопределить внешней переменной окружения, например:
#   BASE_DIR=/home/you/webapp-monitoring ./scripts/monitor.sh
DEFAULT_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_DIR="${BASE_DIR:-$DEFAULT_BASE_DIR}"

APP_SOURCE="${BASE_DIR}/app/main.go"
APP_BINARY="${BASE_DIR}/app/webapp"
PID_FILE="${BASE_DIR}/app/webapp.pid"

APP_PORT="8080"
HEALTH_CHECK_URL="http://localhost:${APP_PORT}/health"
HEALTH_CHECK_TIMEOUT="5"

LOG_FILE="${BASE_DIR}/logs/monitor.log"
APP_LOG_FILE="${BASE_DIR}/logs/app.log"

MONITOR_INTERVAL="30"
