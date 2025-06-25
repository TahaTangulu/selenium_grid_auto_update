# Selenium Grid Otomatik Güncelleme Sistemi

Bu proje, Docker Compose ile çalışan Selenium Grid'i otomatik olarak güncelleyen bir sistemdir. Sadece Bash scriptleri kullanır, Python gerektirmez.

## Özellikler

- ✅ **Tamamen Bash tabanlı** - Python bağımlılığı yok
- ✅ **Otomatik güncelleme** - Docker Hub'dan en son Selenium image'larını çeker
- ✅ **Cron job desteği** - Haftalık veya istediğin sıklıkta otomatik çalışma
- ✅ **Yedekleme sistemi** - Güncelleme öncesi mevcut durumu yedekler
- ✅ **Log yönetimi** - Detaylı loglama ve hata takibi
- ✅ **Güvenlik** - Lock dosyası ile aynı anda birden fazla güncelleme engellenir
- ✅ **Durum kontrolü** - Servislerin çalışıp çalışmadığını kontrol eder

## Dosya Yapısı

```
selenium_grid_latest/
├── docker-compose.yml      # Selenium Grid Docker Compose konfigürasyonu
├── auto_update.sh          # Ana güncelleme scripti
├── setup_cron.sh           # Cron job kurulum ve yönetim scripti
├── backups/                # Yedekleme dosyaları (otomatik oluşturulur)
├── auto_update.log         # Güncelleme logları
└── cron.log               # Cron job logları
```

## Kurulum

### 1. Dosyaları İndir
```bash
# Proje dizinine git
cd /path/to/selenium_grid_latest

# Scriptleri çalıştırılabilir yap
chmod +x auto_update.sh setup_cron.sh
```

### 2. Selenium Grid'i Başlat
```bash
# İlk kez başlatma
docker compose up -d

# Durumu kontrol et
./setup_cron.sh status
```

### 3. Otomatik Güncelleme Kur
```bash
# Cron job kurulumu
./setup_cron.sh install

# Kurulum seçenekleri:
# 1) Her Pazar günü saat 02:00 (önerilen)
# 2) Her Pazartesi günü saat 02:00
# 3) Her gün saat 02:00
# 4) Her 6 saatte bir
# 5) Her 12 saatte bir
# 6) Özel zamanlama
```

## Kullanım

### Manuel Güncelleme
```bash
# Güncelleme scriptini manuel çalıştır
./auto_update.sh
```

### Cron Job Yönetimi
```bash
# Cron job'ları listele
./setup_cron.sh list

# Cron job'ı kaldır
./setup_cron.sh remove

# Test çalıştır
./setup_cron.sh test
```

### Selenium Grid Yönetimi
```bash
# Durumu kontrol et
./setup_cron.sh status

# Başlat
./setup_cron.sh start

# Durdur
./setup_cron.sh stop

# Yeniden başlat
./setup_cron.sh restart
```

### Log Yönetimi
```bash
# Log dosyalarını göster
./setup_cron.sh logs

# Log dosyalarını manuel kontrol et
tail -f auto_update.log
tail -f cron.log
```

## Gereksinimler

- **Docker** - En son versiyon
- **Docker Compose** - En son versiyon
- **Bash** - 4.0 veya üzeri
- **curl** - HTTP istekleri için
- **cron** - Otomatik çalışma için

## Selenium Grid Erişim

Güncelleme sonrası Selenium Grid şu adreslerden erişilebilir:

- **Hub Console**: http://localhost:4444
- **Hub Status**: http://localhost:4444/status
- **Grid Console**: http://localhost:4444/ui

## Güvenlik

- Script çalışırken `update.lock` dosyası oluşturulur
- Aynı anda birden fazla güncelleme çalışması engellenir
- Güncelleme öncesi otomatik yedekleme yapılır
- Hata durumunda rollback için yedekler saklanır

## Sorun Giderme

### Selenium Grid Başlamıyor
```bash
# Docker loglarını kontrol et
docker compose logs

# Servisleri yeniden başlat
./setup_cron.sh restart
```

### Güncelleme Başarısız
```bash
# Log dosyalarını kontrol et
./setup_cron.sh logs

# Manuel test çalıştır
./setup_cron.sh test
```

### Cron Job Çalışmıyor
```bash
# Cron servisini kontrol et
sudo systemctl status cron

# Cron job'ları listele
crontab -l
```

## Yedekleme

Yedekleme dosyaları `backups/` dizininde saklanır:
- `backup_selenium_grid_YYYYMMDD_HHMMSS.yml` - Docker Compose konfigürasyonu
- `images_YYYYMMDD_HHMMSS.txt` - Image versiyonları

## Log Dosyaları

- `auto_update.log` - Güncelleme işlem logları
- `cron.log` - Cron job çalışma logları
- `update.lock` - Güncelleme kilidi (geçici)

## Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Commit yapın (`git commit -m 'Add amazing feature'`)
4. Push yapın (`git push origin feature/amazing-feature`)
5. Pull Request oluşturun

## Lisans

Bu proje MIT lisansı altında lisanslanmıştır.

## Destek

Sorunlarınız için:
1. Log dosyalarını kontrol edin
2. `./setup_cron.sh status` ile durumu kontrol edin
3. GitHub Issues'da sorun bildirin 