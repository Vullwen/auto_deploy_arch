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
    # Monte les partitions sur /mnt
}

install_arch() {
    # Installation de ArchLinux
}

gen_fstab() {
    # Gen /etc/fstab pour mount auto
}

conf_system() {
    #configure les hostname, timezone, langue, clavier
}

add_user() {
    # Création des deux users: collegue et fils 
    # Config sudo
}

conf_share_folder() {
    # Création du dossier partagé entre les deux users, 5go
}

install_grub() {
    # Installation de grub en UEFI
}

install_hyprland() {
    # Installation de Hyprland et setup
}

install_vbox() {
    # Installation de VirtualBox
}

install_firefox() {
    # Installation de firefox
}

install_cdev_env() {
    # Installation de l'environnement de dev en C
    # gcc, make, gdb, vim
}

install_system() {
    # Installation de htop, neofetch, pacman-contrib
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