#!/bin/bash
set -e  # Si erreur, on stoppe

############################################
######## Variables d'environnement #########
############################################

HARDDISKSIZE=80G
RAMSIZE=8G
CPU=4
VCPU=8

# Taille des volumes logiques
ROOTSIZE=40G
VBOXSIZE=20G
SHAREDSPACE=5G
SECRET=10G

# Utilisateurs et mots de passe
USER1="collegue"
USER2="fils"
BASEPWD="azerty123"

# Nom du disque et partitions
DISK="/dev/sda"
EFI_PART="${DISK}1"       # Partition EFI
LVM_PART="${DISK}2"       # Partition pour LVM

# Nom du VG
VGNAME="vg0"

############################################
########## Fonctions utilitaires ###########
############################################

verif_env() {
    # Vérifie si arch-chroot est présent
    if [ ! -x /usr/bin/arch-chroot ]; then
        echo "[INFO] arch-chroot est introuvable. Tentative d'installation du paquet arch-install-scripts..."
        pacman -Sy --noconfirm arch-install-scripts || {
            echo "[ERREUR] Impossible d'installer arch-install-scripts. Abandon."
            exit 1
        }
        # On revérifie après installation
        if [ ! -x /usr/bin/arch-chroot ]; then
            echo "[ERREUR] La commande arch-chroot est toujours introuvable."
            exit 1
        fi
    fi

    # Vérifie que le disque est détecté
    if ! lsblk "${DISK}" >/dev/null 2>&1; then
        echo "[ERREUR] Le disque ${DISK} n'existe pas ou n'est pas détecté."
        exit 1
    fi

    echo "[INFO] Environnement OK. arch-chroot est disponible."
}

############################################
########## Fonctions du script #############
############################################

part_disk() {
    echo "[INFO] Partitionnement du disque ${DISK} en GPT..."
    # Efface la table de partitions
    wipefs -a "${DISK}"
    sgdisk --zap-all "${DISK}"

    parted "${DISK}" mklabel gpt
    # Partition EFI
    parted "${DISK}" mkpart primary fat32 1MiB 512MiB
    parted "${DISK}" set 1 esp on
    # Partition LVM
    parted "${DISK}" mkpart primary ext4 512MiB 100%
    echo "[INFO] Partitionnement terminé."
}

conf_lvm() {
    echo "[INFO] Configuration de LVM sur ${LVM_PART}..."
    pvcreate "${LVM_PART}"
    vgcreate "${VGNAME}" "${LVM_PART}"

    echo "[INFO] Création des volumes logiques..."
    # lv_root
    lvcreate -L "${ROOTSIZE}" -n lv_root "${VGNAME}"
    # lv_vbox
    lvcreate -L "${VBOXSIZE}" -n lv_vbox "${VGNAME}"
    # lv_shared
    lvcreate -L "${SHAREDSPACE}" -n lv_shared "${VGNAME}"
    # lv_secret (non chiffré ici)
    lvcreate -L "${SECRET}" -n lv_secret "${VGNAME}"

    echo "[INFO] Formatage des volumes root, vbox, shared, secret..."
    mkfs.ext4 "/dev/${VGNAME}/lv_root"
    mkfs.ext4 "/dev/${VGNAME}/lv_vbox"
    mkfs.ext4 "/dev/${VGNAME}/lv_shared"
    mkfs.ext4 "/dev/${VGNAME}/lv_secret"

    echo "[INFO] LVM configuré."
}

mount_disk() {
    echo "[INFO] Montage des partitions..."
    # 1) Monter la racine
    mount "/dev/${VGNAME}/lv_root" /mnt

    # 2) Créer les points de montage
    mkdir -p /mnt/boot
    mkdir -p /mnt/vbox
    mkdir -p /mnt/shared
    mkdir -p /mnt/secret

    # 3) Formater et monter la partition EFI
    mkfs.fat -F32 "${EFI_PART}"
    mkdir -p /boot
    mount "${EFI_PART}" /boot
    mount --bind /boot /mnt/boot

    # 4) Monter vbox, shared et secret
    mount "/dev/${VGNAME}/lv_vbox" /mnt/vbox
    mount "/dev/${VGNAME}/lv_shared" /mnt/shared
    mount "/dev/${VGNAME}/lv_secret" /mnt/secret

    echo "[INFO] Partitions montées avec succès."
}

install_arch() {
    echo "[INFO] Installation du système de base Arch Linux..."
    # Ajout de lvm2 pour mkinitcpio (règles LVM) + sudo
    pacstrap /mnt base linux linux-firmware vim nano lvm2 sudo
    echo "[INFO] Système de base installé."
}

gen_fstab() {
    echo "[INFO] Génération du fichier /etc/fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    echo "[INFO] /etc/fstab généré."
}

conf_system() {
    echo "[INFO] Configuration du système (chroot)..."
    arch-chroot /mnt bash <<EOF
set -e

# Configuration locale, timezone, hostname
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf

echo "KEYMAP=fr" > /etc/vconsole.conf

echo "archlinux" > /etc/hostname
cat <<HST >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   archlinux.localdomain archlinux
HST

# Hooks pour LVM
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf

mkinitcpio -P
EOF
}

add_user() {
    echo "[INFO] Ajout des utilisateurs dans le chroot..."
    arch-chroot /mnt bash <<EOF
set -e
useradd -m -G wheel -s /bin/bash ${USER1}
echo "${USER1}:${BASEPWD}" | chpasswd

useradd -m -G wheel -s /bin/bash ${USER2}
echo "${USER2}:${BASEPWD}" | chpasswd

# Activation du sudo pour %wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOF
}

conf_shared_folder() {
    echo "[INFO] Configuration du dossier partagé..."
    arch-chroot /mnt bash <<EOF
chown ${USER1}:${USER2} /shared
chmod 770 /shared
EOF
}

install_grub() {
    echo "[INFO] Installation de GRUB (UEFI) dans le chroot..."
    arch-chroot /mnt bash <<EOF
set -e
pacman -S --noconfirm grub efibootmgr

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF
}

install_hyprland() {
    echo "[INFO] Installation de Hyprland et dépendances (chroot)..."
    arch-chroot /mnt bash <<EOF
set -e
pacman -S --noconfirm hyprland waybar rofi dunst kitty swaybg swaylock swayidle pamixer
EOF
}

install_vbox() {
    echo "[INFO] Installation de VirtualBox (chroot)..."
    arch-chroot /mnt bash <<EOF
pacman -S --noconfirm virtualbox
systemctl enable vboxweb.service
EOF
}

install_firefox() {
    echo "[INFO] Installation de Firefox (chroot)..."
    arch-chroot /mnt pacman -S --noconfirm firefox
}

install_cdev_env() {
    echo "[INFO] Installation de l'environnement de dev C (chroot)..."
    arch-chroot /mnt pacman -S --noconfirm gcc make gdb vim
}

install_system() {
    echo "[INFO] Installation d'outils système (chroot)..."
    arch-chroot /mnt bash <<EOF
pacman -S --noconfirm htop neofetch
EOF
}

gen_logs() {
    echo "[INFO] Récupération de quelques logs depuis le chroot..."
    arch-chroot /mnt bash <<EOF
LOG_FILE="/var/log/installation_log.txt"
{
  echo "=== lsblk -f ==="
  lsblk -f

  echo "=== cat /etc/passwd /etc/group /etc/fstab ==="
  cat /etc/passwd
  cat /etc/group
  cat /etc/fstab

  echo "=== echo \$HOSTNAME ==="
  echo \$HOSTNAME

  echo "=== grep -i installed /var/log/pacman.log ==="
  grep -i installed /var/log/pacman.log
} > "\$LOG_FILE"
EOF
    echo "[INFO] Logs générés dans /var/log/installation_log.txt du nouveau système."
}

clean() {
    echo "[INFO] Nettoyage et démontage des partitions..."
    arch-chroot /mnt pacman -Scc --noconfirm || true

    umount -R /mnt || true

    echo "[INFO] Nettoyage terminé."
}

restart() {
    echo -n "[INFO] Redémarrage dans 5 secondes... "
    for i in {5..1}; do
        echo -ne "\r[INFO] Redémarrage dans $i secondes...   "
        sleep 1
    done
    echo -e "\r[INFO] Redémarrage maintenant...    "
    reboot
}

############################################
######## Fonctions Étapes du script ########
############################################

part_and_lvm() { # (Sajed)
    verif_env
    part_disk
    conf_lvm
}

install_sys() { # (Célian)
    mount_disk
    install_arch
    gen_fstab
}

config_sys() { # (Sajed)
    conf_system
    add_user
    conf_shared_folder
    install_grub
}

install_soft() { # (Célian)
    install_hyprland
    install_vbox
    install_firefox
    install_cdev_env
    install_system
}

post_install() { # (Célian)
    gen_logs
    clean
    restart
}

############################################
############### Main script ################
############################################

# Rappel : tout /dev/sda sera effacé.
echo "=== Script d'installation Arch (UEFI + LVM) ==="
echo "CE SCRIPT EFFACE LE DISQUE ${DISK} ENTIEREMENT."
read -rp "Appuyez sur [Entrée] pour continuer ou Ctrl+C pour annuler..."

part_and_lvm
install_sys
config_sys
install_soft
post_install
