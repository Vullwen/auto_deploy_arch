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
########## Fonctions du script #############
############################################

verif_env() {
    # Verif que on est bien en mode live arch et que le disque existe
}

part_disk() {
    # Partitionne le disque en UEFI (esp + luks)
}

luks_disk() {
    # Chiffrement de la partition
}

conf_lvm() {
    # Création des volumes logique: 
    # Sys /
    # Partitiion chiffrée de 10go
    # Espace pour vbox
    # Espace pour le dossier partagé
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
    # Génère un fichier de log avec les commandes demandées
}

clean() {
    # Nettoyage des fichiers temporaires et des trucs useless, démontage des partitions
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