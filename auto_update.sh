#!/bin/bash

# Selenium Grid Otomatik Güncelleme Scripti
# Bu script haftalık olarak Selenium Grid'i günceller
# Sadece Bash kullanır, Python gerektirmez

set -euo pipefail

# Script konfigürasyonu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/auto_update.log"
LOCK_FILE="${SCRIPT_DIR}/update.lock"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
BACKUP_DIR="${SCRIPT_DIR}/backups"

# Renkli çıktı için
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging fonksiyonu
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[HATA]${NC} $1" | tee -a "$LOG_FILE" >&2
}

warning() {
    echo -e "${YELLOW}[UYARI]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[BİLGİ]${NC} $1" | tee -a "$LOG_FILE"
}

# Hata yönetimi
cleanup() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        log "Lock dosyası temizlendi"
    fi
}

# Script sonlandığında cleanup yap
trap cleanup EXIT

# Mevcut sürümü tespit et
get_current_version() {
    local service_name="$1"
    local image_name="$2"
    
    # Compose dosyasından direkt oku
    local compose_image
    compose_image=$(grep "image: $image_name:" "$COMPOSE_FILE" | head -1 | awk '{print $2}' | cut -d':' -f2)
    
    if [[ -n "$compose_image" ]]; then
        echo "$compose_image"
    else
        echo "latest"
    fi
}

# En son sürümü bul
get_latest_version() {
    local image_name="$1"
    
    # Docker Hub'dan en son tag'leri çek
    local latest_tags
    latest_tags=$(curl -s "https://registry.hub.docker.com/v2/repositories/$image_name/tags/?page_size=10&ordering=last_updated" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -5)
    
    if [[ -n "$latest_tags" ]]; then
        # En son sürümü al
        echo "$latest_tags" | head -1
    else
        echo "latest"
    fi
}

# Docker image versiyonlarını karşılaştır
check_image_updates() {
    local service_name="$1"
    local image_name="$2"
    
    info "Checking for updates for $service_name..."
    
    # Mevcut sürümü al
    local current_version
    current_version=$(get_current_version "$service_name" "$image_name")
    
    # En son sürümü al
    local latest_version
    latest_version=$(get_latest_version "$image_name")
    
    log "Current version: $current_version"
    log "Latest version: $latest_version"
    
    # Sürümleri karşılaştır
    if [[ "$current_version" != "$latest_version" ]]; then
        log "Update available for $service_name: $current_version -> $latest_version"
        
        # Compose dosyasını güncelle
        update_compose_file "$service_name" "$image_name" "$latest_version"
        
        return 0  # Güncelleme mevcut
    else
        info "No update available for $service_name (already at $current_version)"
        return 1  # Güncelleme yok
    fi
}

# Compose dosyasını güncelle
update_compose_file() {
    local service_name="$1"
    local image_name="$2"
    local new_version="$3"
    
    log "Updating compose file for $service_name to version $new_version"
    
    # Geçici dosya oluştur
    local temp_file
    temp_file=$(mktemp)
    
    # Compose dosyasını oku ve güncelle
    sed "s|image: $image_name:[^[:space:]]*|image: $image_name:$new_version|g" "$COMPOSE_FILE" > "$temp_file"
    
    # Geçici dosyayı asıl dosyaya kopyala
    mv "$temp_file" "$COMPOSE_FILE"
    
    log "Compose file updated successfully"
}

# Mevcut durumu yedekle
backup_current_state() {
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${BACKUP_DIR}/backup_selenium_grid_${timestamp}.yml"
    
    # Backup dizinini oluştur
    mkdir -p "$BACKUP_DIR"
    
    # Docker compose config'i yedekle
    if docker compose -f "$COMPOSE_FILE" config > "$backup_file" 2>/dev/null; then
        # Mevcut image versiyonlarını da yedekle
        local image_backup_file="${BACKUP_DIR}/images_${timestamp}.txt"
        docker compose -f "$COMPOSE_FILE" images > "$image_backup_file" 2>/dev/null || true
        
        log "Current state backed up to: $backup_file"
        log "Image versions backed up to: $image_backup_file"
        return 0
    else
        error "Backup failed"
        return 1
    fi
}

# Servisleri durdur
stop_services() {
    log "Stopping Selenium Grid services..."
    if docker compose -f "$COMPOSE_FILE" down; then
        log "Services stopped successfully"
        return 0
    else
        error "Failed to stop services"
        return 1
    fi
}

# Servisleri başlat
start_services() {
    log "Starting Selenium Grid services..."
    if docker compose -f "$COMPOSE_FILE" up -d; then
        log "Services started successfully"
        return 0
    else
        error "Failed to start services"
        return 1
    fi
}

# Servislerin hazır olmasını bekle
wait_for_services_ready() {
    local timeout=${1:-60}
    local elapsed=0
    local interval=5
    
    log "Waiting for services to be ready (timeout: ${timeout}s)..."
    
    while [[ $elapsed -lt $timeout ]]; do
        # Hub'ın hazır olup olmadığını kontrol et
        if curl -s -f "http://localhost:4444/status" >/dev/null 2>&1; then
            log "Selenium Grid is ready!"
            return 0
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    warning "Services did not become ready within timeout period"
    return 1
}

# Eski image'ları temizle
cleanup_old_images() {
    log "Cleaning up old Docker images..."
    
    # Kullanılmayan image'ları sil
    if docker image prune -f >/dev/null 2>&1; then
        # Selenium image'larının eski versiyonlarını sil (latest hariç)
        local selenium_images=("selenium/hub" "selenium/node-chrome" "selenium/node-firefox" "selenium/node-edge")
        
        for image in "${selenium_images[@]}"; do
            # En son versiyon hariç tüm versiyonları sil
            docker images "$image" --format "{{.ID}}" | tail -n +2 | xargs -r docker rmi -f 2>/dev/null || true
        done
        
        log "Old images cleaned up"
        return 0
    else
        warning "Image cleanup failed"
        return 1
    fi
}

# Güncelleme kontrolü yap
check_for_updates() {
    local updates_available=false
    
    # Kontrol edilecek image'lar
    local images_to_check=(
        "selenium-hub:selenium/hub"
        "chrome:selenium/node-chrome"
        "firefox:selenium/node-firefox"
        "edge:selenium/node-edge"
    )
    
    for image_pair in "${images_to_check[@]}"; do
        local service_name="${image_pair%:*}"
        local image_name="${image_pair#*:}"
        
        if check_image_updates "$service_name" "$image_name"; then
            updates_available=true
        fi
    done
    
    if [[ "$updates_available" == "true" ]]; then
        log "Updates are available"
        return 0
    else
        log "No updates available"
        return 1
    fi
}

# Ana güncelleme fonksiyonu
update_selenium_grid() {
    log "Starting Selenium Grid update process..."
    
    # 1. Mevcut durumu yedekle
    if ! backup_current_state; then
        error "Backup failed, aborting update"
        return 1
    fi
    
    # 2. Güncelleme kontrolü
    if ! check_for_updates; then
        log "No updates needed, all services are up to date"
        return 0
    fi
    
    # 3. Servisleri durdur
    if ! stop_services; then
        error "Failed to stop services"
        return 1
    fi
    
    # 4. Servisleri yeniden başlat (yeni image'lar ile)
    if ! start_services; then
        error "Failed to start services"
        return 1
    fi
    
    # 5. Servislerin hazır olmasını bekle
    if ! wait_for_services_ready; then
        warning "Services may not be fully ready"
    fi
    
    # 6. Eski image'ları temizle
    cleanup_old_images
    
    log "Selenium Grid update completed successfully!"
    return 0
}

# Ana fonksiyon
main() {
    log "Selenium Grid automatic update starting..."
    
    # Lock dosyası kontrolü (aynı anda birden fazla güncelleme çalışmasını engelle)
    if [[ -f "$LOCK_FILE" ]]; then
        error "Another update process is already running. Lock file: $LOCK_FILE"
        exit 1
    fi
    
    # Lock dosyası oluştur
    echo "$$" > "$LOCK_FILE"
    log "Lock file created"
    
    # Gerekli dosyaların varlığını kontrol et
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    # Docker'ın çalışıp çalışmadığını kontrol et
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running. Please start Docker service."
        exit 1
    fi
    
    # Docker Compose'un çalışıp çalışmadığını kontrol et
    if ! docker compose version >/dev/null 2>&1; then
        error "Docker Compose not found or not working."
        exit 1
    fi
    
    # Selenium Grid'in çalışıp çalışmadığını kontrol et
    if ! docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        warning "Selenium Grid is not running. Starting services..."
        docker compose -f "$COMPOSE_FILE" up -d
        sleep 30  # Servislerin başlaması için bekle
    fi
    
    # Güncelleme işlemini çalıştır
    if update_selenium_grid; then
        log "Update completed successfully!"
        
        # Başarılı güncelleme sonrası servis durumunu kontrol et
        sleep 10
        if docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
            log "All services are running successfully"
        else
            warning "Some services may not be running"
        fi
        
    else
        error "Update failed!"
        exit 1
    fi
    
    log "Automatic update process completed"
}

# Script'i çalıştır
main "$@" 