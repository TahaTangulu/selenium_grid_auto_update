#!/bin/bash

# Selenium Grid Otomatik Güncelleme - Cron Job Kurulum Scripti
# Bu script haftalık otomatik güncelleme için cron job oluşturur
# Sadece Bash kullanır, Python gerektirmez

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_UPDATE_SCRIPT="${SCRIPT_DIR}/auto_update.sh"
CRON_LOG="${SCRIPT_DIR}/cron.log"

# Renkli çıktı için
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging fonksiyonu
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[HATA]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[UYARI]${NC} $1"
}

info() {
    echo -e "${BLUE}[BİLGİ]${NC} $1"
}

# Cron job oluşturma fonksiyonu
create_cron_job() {
    local update_script="$1"
    local cron_schedule="$2"
    
    # Cron job komutu
    local cron_command="$cron_schedule $update_script >> $CRON_LOG 2>&1"
    
    # Mevcut cron job'ları kontrol et
    if crontab -l 2>/dev/null | grep -q "$update_script"; then
        warning "Bu script için zaten bir cron job mevcut!"
        echo "Mevcut cron job:"
        crontab -l | grep "$update_script"
        return 1
    fi
    
    # Yeni cron job ekle
    (crontab -l 2>/dev/null; echo "$cron_command") | crontab -
    
    log "Cron job başarıyla oluşturuldu!"
    log "Zamanlama: $cron_schedule"
    log "Script: $update_script"
    log "Log dosyası: $CRON_LOG"
}

# Cron job kaldırma fonksiyonu
remove_cron_job() {
    local update_script="$1"
    
    # Mevcut cron job'ları al ve bu script'i filtrele
    local temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "$update_script" > "$temp_cron"
    
    # Yeni crontab'ı yükle
    crontab "$temp_cron"
    rm "$temp_cron"
    
    log "Cron job kaldırıldı!"
}

# Cron job listeleme fonksiyonu
list_cron_jobs() {
    log "Mevcut cron job'lar:"
    if crontab -l 2>/dev/null | grep -q "$AUTO_UPDATE_SCRIPT"; then
        crontab -l | grep "$AUTO_UPDATE_SCRIPT"
    else
        warning "Bu script için cron job bulunamadı"
    fi
}

# Selenium Grid durumunu kontrol et
check_grid_status() {
    info "Selenium Grid durumu kontrol ediliyor..."
    
    # Docker Compose dosyasının varlığını kontrol et
    local compose_file="${SCRIPT_DIR}/docker-compose.yml"
    if [[ ! -f "$compose_file" ]]; then
        error "Docker Compose dosyası bulunamadı: $compose_file"
        return 1
    fi
    
    # Docker'ın çalışıp çalışmadığını kontrol et
    if ! docker info >/dev/null 2>&1; then
        error "Docker çalışmıyor. Docker servisini başlatın."
        return 1
    fi
    
    # Selenium Grid servislerinin durumunu kontrol et
    if docker compose -f "$compose_file" ps | grep -q "Up"; then
        log "Selenium Grid çalışıyor"
        echo ""
        docker compose -f "$compose_file" ps
        echo ""
        
        # Hub'ın erişilebilir olup olmadığını kontrol et
        if curl -s -f "http://localhost:4444/status" >/dev/null 2>&1; then
            log "Selenium Hub erişilebilir (http://localhost:4444)"
        else
            warning "Selenium Hub erişilemiyor"
        fi
        
        return 0
    else
        warning "Selenium Grid çalışmıyor"
        return 1
    fi
}

# Test güncelleme fonksiyonu
test_update() {
    info "Test güncelleme çalıştırılıyor..."
    
    # Script'in çalıştırılabilir olduğunu kontrol et
    if [[ ! -x "$AUTO_UPDATE_SCRIPT" ]]; then
        error "Güncelleme scripti çalıştırılabilir değil: $AUTO_UPDATE_SCRIPT"
        return 1
    fi
    
    # Test çalıştır
    if "$AUTO_UPDATE_SCRIPT"; then
        log "Test başarılı!"
        return 0
    else
        error "Test başarısız!"
        return 1
    fi
}

# Log dosyalarını göster
show_logs() {
    info "Log dosyaları:"
    
    local log_files=(
        "$CRON_LOG"
        "${SCRIPT_DIR}/auto_update.log"
        "${SCRIPT_DIR}/selenium_grid_update.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            echo "  - $log_file ($(wc -l < "$log_file") satır)"
        else
            echo "  - $log_file (dosya yok)"
        fi
    done
    
    echo ""
    info "Son log kayıtları (cron.log):"
    if [[ -f "$CRON_LOG" ]]; then
        tail -10 "$CRON_LOG"
    else
        warning "Cron log dosyası bulunamadı"
    fi
}

# Ana fonksiyon
main() {
    log "Selenium Grid Otomatik Güncelleme - Cron Job Kurulumu"
    
    # Script dosyasının varlığını kontrol et
    if [[ ! -f "$AUTO_UPDATE_SCRIPT" ]]; then
        error "Otomatik güncelleme scripti bulunamadı: $AUTO_UPDATE_SCRIPT"
        exit 1
    fi
    
    # Script'i çalıştırılabilir yap
    chmod +x "$AUTO_UPDATE_SCRIPT"
    
    # Komut satırı argümanlarını kontrol et
    case "${1:-}" in
        "install")
            echo "Güncelleme sıklığını seçin:"
            echo "1) Her Pazar günü saat 02:00 (önerilen)"
            echo "2) Her Pazartesi günü saat 02:00"
            echo "3) Her gün saat 02:00"
            echo "4) Her 6 saatte bir"
            echo "5) Her 12 saatte bir"
            echo "6) Özel zamanlama (cron formatında)"
            
            read -p "Seçiminiz (1-6): " choice
            
            case "$choice" in
                1)
                    cron_schedule="0 2 * * 0"  # Her Pazar 02:00
                    ;;
                2)
                    cron_schedule="0 2 * * 1"  # Her Pazartesi 02:00
                    ;;
                3)
                    cron_schedule="0 2 * * *"  # Her gün 02:00
                    ;;
                4)
                    cron_schedule="0 */6 * * *"  # Her 6 saatte bir
                    ;;
                5)
                    cron_schedule="0 */12 * * *"  # Her 12 saatte bir
                    ;;
                6)
                    echo "Cron formatı: dakika saat gün ay hafta_günü"
                    echo "Örnek: 0 2 * * 0 (Her Pazar 02:00)"
                    echo "Örnek: 0 */6 * * * (Her 6 saatte bir)"
                    read -p "Cron zamanlaması: " cron_schedule
                    ;;
                *)
                    error "Geçersiz seçim"
                    exit 1
                    ;;
            esac
            
            create_cron_job "$AUTO_UPDATE_SCRIPT" "$cron_schedule"
            ;;
            
        "remove")
            remove_cron_job "$AUTO_UPDATE_SCRIPT"
            ;;
            
        "list")
            list_cron_jobs
            ;;
            
        "test")
            test_update
            ;;
            
        "status")
            check_grid_status
            ;;
            
        "logs")
            show_logs
            ;;
            
        "start")
            info "Selenium Grid başlatılıyor..."
            docker compose -f "${SCRIPT_DIR}/docker-compose.yml" up -d
            log "Selenium Grid başlatıldı"
            ;;
            
        "stop")
            info "Selenium Grid durduruluyor..."
            docker compose -f "${SCRIPT_DIR}/docker-compose.yml" down
            log "Selenium Grid durduruldu"
            ;;
            
        "restart")
            info "Selenium Grid yeniden başlatılıyor..."
            docker compose -f "${SCRIPT_DIR}/docker-compose.yml" restart
            log "Selenium Grid yeniden başlatıldı"
            ;;
            
        *)
            echo "Kullanım: $0 {install|remove|list|test|status|logs|start|stop|restart}"
            echo ""
            echo "Komutlar:"
            echo "  install  - Otomatik güncelleme cron job'ı oluştur"
            echo "  remove   - Cron job'ı kaldır"
            echo "  list     - Mevcut cron job'ları listele"
            echo "  test     - Güncelleme scriptini test et"
            echo "  status   - Selenium Grid durumunu kontrol et"
            echo "  logs     - Log dosyalarını göster"
            echo "  start    - Selenium Grid'i başlat"
            echo "  stop     - Selenium Grid'i durdur"
            echo "  restart  - Selenium Grid'i yeniden başlat"
            echo ""
            echo "Örnekler:"
            echo "  $0 install    # Cron job kur"
            echo "  $0 test       # Test çalıştır"
            echo "  $0 status     # Durum kontrol et"
            echo "  $0 logs       # Logları göster"
            exit 1
            ;;
    esac
}

# Script'i çalıştır
main "$@" 