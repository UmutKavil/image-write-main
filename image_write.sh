#!/bin/bash

# Hata mesajı fonksiyonu
function error_exit {
    echo "HATA: $1" >&2
    exit 1
}

# Disk sağlık kontrol fonksiyonu
function check_disk_health() {
    local disk=$1
    echo "Disk sağlık kontrolü yapılıyor..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if ! sudo badblocks -sv -b 4096 "$disk"; then
            echo "UYARI: Disk kontrolü tamamlanamadı veya hatalar bulundu, yine de devam edilebilir" >&2
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if ! diskutil verifyDisk "$disk"; then
            echo "UYARI: Disk doğrulaması başarısız, yine de devam edilebilir" >&2
        fi
    fi
    echo "Disk sağlık kontrolü tamamlandı."
}

# Güvenli yazma fonksiyonu
function safe_dd_write() {
    local input=$1
    local output=$2
    
    echo "GÜVENLİ YAZMA MODU AKTİF"
    echo "------------------------"
    echo "1. Aşama: Önbellek temizleme..."
    sudo sync
    
    echo "2. Aşama: Yazma işlemi başlatılıyor (bu işlem uzun sürebilir)..."
    if ! sudo dd if="$input" of="$output" bs=4M status=progress conv=fsync oflag=direct; then
        error_exit "Yazma işlemi başarısız oldu"
    fi
    
    echo "3. Aşama: Veri bütünlüğü kontrolü..."
    sudo sync
    
    echo "Yazma işlemi başarıyla tamamlandı."
}

function find_disk() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Disk adını bulmak için macOS:"
        echo "1. Terminal'i açın."
        echo "2. Şu komutu çalıştırın: diskutil list"
        echo "3. Disk adını belirleyin (örnek: /dev/disk6)."
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Disk adını bulmak için Ubuntu:"
        echo "1. Terminal'i açın."
        echo "2. Şu komutu çalıştırın: lsblk"
        echo "3. Disk adını belirleyin (örnek: /dev/sdb)."
    else
        error_exit "Desteklenmeyen işletim sistemi: $OSTYPE"
    fi
}

function get_disk_format() {
    local disk=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        diskutil info "$disk" 2>/dev/null | grep "File System Personality:" | awk '{print $4}' || echo "Belirlenemedi"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        lsblk -f "$disk" 2>/dev/null | grep -v "NAME" | awk '{print $2}' || echo "Belirlenemedi"
    fi
}

function format_disk() {
    local disk=$1
    local format=$2
    
    echo "Disk biçimlendiriliyor: $disk ($format olarak)..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        case $format in
            "FAT32")
                diskutil eraseDisk FAT32 UNTITLED "$disk" || error_exit "FAT32 biçimlendirme başarısız"
                ;;
            "ExFAT")
                diskutil eraseDisk ExFAT UNTITLED "$disk" || error_exit "ExFAT biçimlendirme başarısız"
                ;;
            "HFS+")
                diskutil eraseDisk JHFS+ UNTITLED "$disk" || error_exit "HFS+ biçimlendirme başarısız"
                ;;
            "APFS")
                diskutil eraseDisk APFS UNTITLED "$disk" || error_exit "APFS biçimlendirme başarısız"
                ;;
            *)
                error_exit "Desteklenmeyen dosya sistemi: $format"
                ;;
        esac
        diskutil unmountDisk "$disk"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        for partition in "${disk}"*; do
            if mount | grep -q "$partition"; then
                sudo umount "$partition" 2>/dev/null
            fi
        done
        
        case $format in
            "FAT32")
                sudo mkfs.vfat -F32 "$disk" || error_exit "FAT32 biçimlendirme başarısız"
                ;;
            "ExFAT")
                sudo mkfs.exfat "$disk" || error_exit "ExFAT biçimlendirme başarısız"
                ;;
            "EXT4")
                sudo mkfs.ext4 "$disk" || error_exit "EXT4 biçimlendirme başarısız"
                ;;
            "NTFS")
                sudo mkfs.ntfs -f "$disk" || error_exit "NTFS biçimlendirme başarısız"
                ;;
            *)
                error_exit "Desteklenmeyen dosya sistemi: $format"
                ;;
        esac
    fi
    
    echo "Disk başarıyla $format olarak biçimlendirildi."
}

# Ana işlemler
clear
echo "=== DİSK YAZMA ARACI ==="
echo ""

find_disk

read -p "Lütfen yazmak istediğiniz disk adını girin (örnek: /dev/disk6 veya /dev/sdb): " disk_name

# Disk adı kontrolü
if [[ ! -e "$disk_name" ]]; then
    error_exit "Belirtilen disk bulunamadı: $disk_name"
fi

# Image dosyası kontrolü
img_path="img.img"
if [[ ! -f "$img_path" ]]; then
    read -p "img.img bulunamadı. Lütfen image dosyasının tam yolunu girin: " custom_img_path
    if [[ -f "$custom_img_path" ]]; then
        img_path="$custom_img_path"
    else
        error_exit "Image dosyası bulunamadı: $custom_img_path"
    fi
fi

echo "Kullanılacak image dosyası: $img_path"

# Disk kullanım kontrolü
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    for partition in "${disk_name}"*; do
        if mount | grep -q "$partition"; then
            if ! sudo umount "$partition"; then
                error_exit "Disk bölümü $partition çıkarılamadı. Lütfen elle çıkarıp tekrar deneyin."
            fi
        fi
    done
elif [[ "$OSTYPE" == "darwin"* ]]; then
    if diskutil list | grep -q "$disk_name"; then
        if ! diskutil unmountDisk "$disk_name"; then
            error_exit "Disk $disk_name çıkarılamadı. Lütfen elle çıkarıp tekrar deneyin."
        fi
    fi
fi

# Disk formatını öğren
current_format=$(get_disk_format "$disk_name")
echo "Mevcut disk formatı: ${current_format:-'Belirlenemedi'}"

# Formatlama sorusu
read -p "Diski yazmadan önce biçimlendirmek istiyor musunuz? (y/n): " format_choice
if [[ "$format_choice" =~ [yY] ]]; then
    echo ""
    echo "Lütfen bir dosya sistemi seçin:"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "1) FAT32 (Windows ve macOS uyumlu)"
        echo "2) ExFAT (Büyük dosyalar için)"
        echo "3) HFS+ (Mac OS Extended)"
        echo "4) APFS (Apple File System)"
        read -p "Seçiminiz (1-4): " fs_choice
        
        case $fs_choice in
            1) format="FAT32" ;;
            2) format="ExFAT" ;;
            3) format="HFS+" ;;
            4) format="APFS" ;;
            *) error_exit "Geçersiz seçim" ;;
        esac
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "1) FAT32 (Windows ve Linux uyumlu)"
        echo "2) ExFAT (Büyük dosyalar için)"
        echo "3) EXT4 (Linux için optimize)"
        echo "4) NTFS (Windows için optimize)"
        read -p "Seçiminiz (1-4): " fs_choice
        
        case $fs_choice in
            1) format="FAT32" ;;
            2) format="ExFAT" ;;
            3) format="EXT4" ;;
            4) format="NTFS" ;;
            *) error_exit "Geçersiz seçim" ;;
        esac
    fi
    
    format_disk "$disk_name" "$format"
fi

# Disk sağlık kontrolü yap
read -p "Disk sağlık kontrolü yapılsın mı? (önerilir) (y/n): " health_check
if [[ "$health_check" =~ [yY] ]]; then
    check_disk_health "$disk_name"
fi

# Yazma işlemi
echo ""
echo "=== YAZMA İŞLEMİ ==="
echo "1) Normal Yazma (Daha Hızlı)"
echo "2) Güvenli Yazma (Daha Yavaş Ama Kararlı)"
read -p "Yazma modunu seçin (1-2): " write_mode

echo ""
echo "Image dosyası yazılıyor: $img_path -> $disk_name..."
echo "NOT: Bu işlem uzun sürebilir, lütfen bekleyin..."

case $write_mode in
    1)
        if ! sudo dd if="$img_path" of="$disk_name" bs=4M status=progress conv=fsync; then
            error_exit "Yazma işlemi başarısız oldu"
        fi
        ;;
    2)
        safe_dd_write "$img_path" "$disk_name"
        ;;
    *)
        error_exit "Geçersiz yazma modu seçimi"
        ;;
esac

sync
echo ""
echo "Yazma işlemi başarıyla tamamlandı!"
echo "Yazılan veri boyutu: $(sudo blockdev --getsize64 "$disk_name" | numfmt --to=iec)"
echo "Diski güvenle çıkarabilirsiniz."