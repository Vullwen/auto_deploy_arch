#!/bin/bash

set -e # Si erreur -> stop

############################################
######## Variables d'environnement #########
############################################

HARDDISKSIZE=80G
RAMSIZE=8G
ENCRYPTEDSIZE=10G
SHAREDSPACE=5G
CPU=4
VCPU=8


USER1="collegue"
USER2="fils"
BASEPWD="azerty123"

ARCHLINK=""
HYPRLANDLINK=""
VBOXLINK=""
FIREFOXLINK=""

############################################
########## Fonctions utilitaires ###########
############################################

show_progress() {
    # Si pas la flemme
}

############################################
########## Fonctions du script #############
############################################

verif_env() {
    if [ ! -f /usr/bin/arch-chroot ]; then
        echo "Ce script doit être lancé dans un environnement ArchLinux."
        exit 1
    fi

    if ! lsblk | grep -q "/dev/sda"; then
        echo "Le disque /dev/sda n'existe pas."
        exit 1
    fi

    echo "[INFO] Vérification de l'environnement: OK"
}

part_disk() {
    parted /dev/sda mklabel gpt # Création de la table de partition
    parted /dev/sda mkpart primary fat32 1MiB 512MiB # Création de la partition EFI
    parted /dev/sda set 1 esp on # Activation du flag esp sur la partition EFI
    parted /dev/sda mkpart primary ext4 512MiB 100% # Création de la partition racine

}

luks_disk() {
    # Chiffrement de la partition racine
    echo -n "Entrez une passphrase pour chiffrer la partition: "
    read -s PASSPHRASE
    echo

    # Chiffrement de la partition
    echo "$PASSPHRASE" | cryptsetup luksFormat /dev/sda2 -
    echo "$PASSPHRASE" | cryptsetup open /dev/sda2 cryptroot -

    # Création du système de fichier
    mkfs.ext4 /dev/mapper/cryptroot
}

conf_lvm() {
    # Configuration de LVM
    pvcreate /dev/mapper/cryptroot
    vgcreate vg0 /dev/mapper/cryptroot

    # Création des volumes logiques
    lvcreate -L ${ENCRYPTEDSIZE} -n lv_root vg0
    lvcreate -L ${VBOXLINK} -n lv_vbox vg0
    lvcreate -L ${SHAREDSPACE} -n lv_shared vg0

    # Création des systèmes de fichiers
    mkfs.ext4 /dev/vg0/lv_root
    mkfs.ext4 /dev/vg0/lv_vbox
    mkfs.ext4 /dev/vg0/lv_shared
}

mount_disk() {
    echo "[INFO] Montage des partitions..."

    # Créer les points de montage
    mkdir -p /mnt/boot/efi
    mkdir -p /mnt/shared
    mkdir -p /mnt/vbox

    # Monter les partitions
    mount /dev/mapper/vg0-lv_root /mnt
    mount /dev/sda1 /mnt/boot/efi
    mount /dev/vg0/lv_shared /mnt/shared
    mount /dev/vg0/lv_vbox /mnt/vbox

    echo "[INFO] Partitions montées avec succès."
}

install_arch() {
    echo "[INFO] Installation du système de base Arch Linux..."

    # Installation des paquets de base
    pacstrap /mnt base linux linux-firmware vim nano

    # Génération du fstab
    genfstab -U /mnt >> /mnt/etc/fstab

    echo "[INFO] Installation du système de base terminée."
}


gen_fstab() {
    echo "[INFO] Génération du fichier /etc/fstab..."

    # Génération du fichier fstab
    genfstab -U /mnt >> /mnt/etc/fstab

    echo "[INFO] Fichier /etc/fstab généré avec succès."
}


conf_system() {
    # Configuration du hostname
    echo "archlinux" > /etc/hostname
    echo "127.0.0.1 localhost" >> /etc/hosts
    echo "::1       localhost" >> /etc/hosts
    echo "127.0.1.1 archlinux.localdomain archlinux" >> /etc/hosts

    # Configuration du timezone
    ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
    hwclock --systohc

    # Configuration de la langue
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=fr_FR.UTF-8" > /etc/locale.conf

    # Configuration du clavier
    echo "KEYMAP=fr" > /etc/vconsole.conf
}

add_user() {
    # Config sudo
    useradd -m -G wheel -s /bin/bash $USER1
    echo "$USER1:$BASEPWD" | chpasswd

    useradd -m -G wheel -s /bin/bash $USER2
    echo "$USER2:$BASEPWD" | chpasswd

    # Configuration de sudo pour permettre aux utilisateurs du groupe wheel d'utiliser sudo
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
}

conf_share_folder() {
    mkdir -p /mnt/shared
    mount /dev/vg0/lv_shared /mnt/shared
    chmod 770 /mnt/shared
    chown $USER1:$USER2 /mnt/shared
}

install_grub() {
    # Installation de GRUB en UEFI
    pacman -S --noconfirm grub efibootmgr

    # Monte la partition EFI
    mkdir -p /mnt/boot/efi
    mount /dev/sda1 /mnt/boot/efi

    # Installation de GRUB sur la partition EFI
    grub-install --target=x86_64-efi --efi-directory=/mnt/boot/efi --bootloader-id=GRUB

    # Génération du fichier de configuration de GRUB
    grub-mkconfig -o /mnt/boot/grub/grub.cfg
}

install_hyprland() {
    echo "[INFO] Installation de Hyprland et de ses dépendances..."

    pacman -Syu --noconfirm

    # Installation de yay si ce n'est pas déjà fait
    if ! command -v yay &> /dev/null; then
        pacman -S --needed base-devel git
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si
    fi

    ## Installation d'une config sympa https://github.com/1amSimp1e/dots/tree/late-night-%F0%9F%8C%83
    yay -S hyprland-git
    yay -S waybar-hyprland rofi dunst kitty swaybg swaylock-fancy-git swayidle pamixer light brillo
    yay -S ttf-font-awesome
    fc-cache -fv
    git clone -b late-night-🌃 https://github.com/iamverysimp1e/dots
    cd dots
    cp -r ./configs/* ~/.config/
}



install_vbox() {
    # Installation de VirtualBox
    echo "[INFO] Installation de VirtualBox..."

    # Installation de VirtualBox et des modules du noyau
    pacman -S --noconfirm virtualbox

    # Activation et démarrage du service VirtualBox
    systemctl enable vboxdrv.service
    systemctl start vboxdrv.service

    echo "[INFO] VirtualBox installé avec succès."
}


install_firefox() {
    # Installation de Firefox
    echo "[INFO] Installation de Firefox..."

    # Installation de Firefox
    pacman -S --noconfirm firefox

    echo "[INFO] Firefox installé avec succès."
}


install_cdev_env() {
    # Installation de l'environnement de développement en C
    echo "[INFO] Installation de l'environnement de développement en C..."

    # Installation des outils de développement
    pacman -S --noconfirm gcc make gdb vim

    echo "[INFO] Environnement de développement en C installé avec succès."
}


install_system() {
    # Installation des outils système
    echo "[INFO] Installation des outils système..."

    # Installation des outils
    pacman -S --noconfirm htop neofetch

    # Installation de pacman-contrib depuis l'AUR
    echo "[INFO] Installation de pacman-contrib depuis l'AUR..."
    git clone https://aur.archlinux.org/pacman-contrib.git
    cd pacman-contrib
    makepkg -si --noconfirm
    cd ..

    echo "[INFO] Outils système installés avec succès."
}

gen_logs() {
    echo "[INFO] Génération des logs..."

    LOG_FILE="/var/log/installation_log.txt" # Création du fichier de log

    {
        echo "=== lsblk -f ==="
        lsblk -f

        echo "=== cat /etc/passwd /etc/group /etc/fstab /etc/mtab ==="
        cat /etc/passwd /etc/group /etc/fstab /etc/mtab

        echo "=== echo \$HOSTNAME ==="
        echo $HOSTNAME

        echo "=== grep -i installed /var/log/pacman.log ==="
        grep -i installed /var/log/pacman.log
    } > "$LOG_FILE" # Execution des commandes et reponse envoyées dans le fichier de logs

    echo "[INFO] Logs générés dans $LOG_FILE"
}


clean() {
    echo "[INFO] Nettoyage des fichiers temporaires et démontage des partitions..."

    umount -R /mnt # On demonte les partitions sur /mnt
    rm -rf /mnt/* # Suppression des fichiers temps
    pacman -Scc --noconfirm # Suppression du cache de pacman

    echo "[INFO] Nettoyage terminé."
}

restart() {
    echo -n "[INFO] Redémarrage dans 10 secondes... "
    for i in {10..1}; do
        echo -ne "\r[INFO] Redémarrage dans $i secondes...   "
        sleep 1
    done
    echo -e "\r[INFO] Redémarrage maintenant...    "
    reboot
}


############################################
######## Fonctions Etapes du script ########
############################################

part_and_chiffr() { # Sajed
    verif_env
    part_disk
    luks_disk
    conf_lvm
}

install_sys() { # Célian
    mount_disk
    install_arch
    gen_fstab
}

config_sys() { # Sajed
    conf_system
    add_user
    conf_shard_folder
    install_grub
    
}

install_soft() { # Célian
    install_hyprland
    install_vbox
    install_firefox
    install_cdev_env
    install_system
}

post_install() { # Célian
    gen_logs
    clean
    restart
}

############################################
############### Main script ################
############################################

part_and_chiffr
install_sys
config_sys
install_soft
post_install