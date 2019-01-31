#!/bin/bash
#
# a simple remote command execution script
#
# @author Zhao ZHANG <zo.zhang@gmail.com>
# Usage: ./zorecom.sh
#
remote_host_list=("z18013171 Fg.123456 10.203.9.106 22 d18025352 test 10.203.9.107 22")
select_host_list=()
host_vm_list=()

###
##======================= Helper Functions =============================##
###

#Get vm info by expression régulée
function get_vm_field_info()
{
  temp_vm_info=$1
  temp_vm_field=$2

  $(cat "$temp_vm_info" | "awk '{match(\$0, /$temp_vm_field=\"(.[^\"]+?)/, matchs);print matchs[1]}'")
}

#Get host base info: username,password,ip,port
function get_host_info()
{
  username=$(echo $1 | cut -d " " -f 1)
  password=$(echo $1 | cut -d " " -f 2)
  ip=$(echo $1 | cut -d " " -f 3)
  port=$(echo $1 | cut -d " " -f 4)
}

#Execute a remote command by host
function excute_remote_command()
{
  ssh -o "StrictHostKeyChecking no" $1 $2
}

#Convert a string to an array with a limit of 4 bits by default
function string_convert_array()
{
  i=1
  j=0
  pos=$2
  return_array=()
  while((1==1))
  do
    split=`echo $1|cut -d ' ' -f$i`
    if [ "$split" != "" ]
    then
        if [ $( expr $i % $pos ) ==  0 ]
        then
          return_array[j]+=" $split"
          ((j++))
        else
          return_array[j]+=" $split"
        fi
        ((i++))
    else
        break
    fi
  done
}
###
##======================= Helper Functions =============================##
###

###
##======================= Dialog Functions =============================##
###
# Show a warning notification
function show_notification()
{
  notify-send "$1"
}

# Show a warning dialog
function show_warning_dialog()
{
  zenity --info --title="Warning Info" --text="$1"
}

# Show host list dialog for add a remote service
function add_host_list_dialog()
{
     remote_host=$(zenity --forms --title="Ajoute des serveurs" --text="Saisissez vos serveurs" --separator=" " --add-entry="Utilisateurs"  --add-password="Mot de passe"  --add-entry="IP address" --add-entry="Port")

     if [ $? != "0" ]
     then
        show_command_menu_dialog
        exit 1
     fi

     remote_host_list=("${remote_host_list[@]}" "$remote_host" )
     show_notification "Serveur ajouté avec succès"
}

# Show select host list
function select_host_list_dialog()
{
  if [ "0" ==  ${#remote_host_list[0]} ];
   then
      show_warning_dialog "Veuillez ajoutez le serveur pour continuer"
      add_host_list_dialog
   else

     select_host=$(zenity --height=300 --list --title="Sélectez les serveurs" --separator=" " --multiple --print-column=ALL --hide-column=2 --column="Utilisateur" --column="Password" --column="IP" --column="Port" ${remote_host_list[@]})

     if [ $? != "0" ]
     then
        show_command_menu_dialog
        exit 1
     fi

     #convert full string to array
     string_convert_array "${select_host}" "4"

     #save selected host to list
     for ((i=0;i<${#return_array[@]};i++))
     do
       select_host_list=("${select_host_list[@]}" "${return_array[$i]}")
     done
 fi
}

# Delete all vm
function delete_all_vm_dialog()
{
   if zenity --question  --text="Êtes-vous sûr de vouloir supprimer tout les vms?"
   then
      delete_all_vm
   fi
}

# View all vm of host selected
function get_all_vm_dialog()
{
  select_host_list_dialog

  # get remote vm by host
  if [ "0" ==  ${#select_host_list[0]} ];
   then
      show_warning_dialog "Veuillez sélectionner le serveur cible pour exécuter la commande"
      get_all_vm_dialog
   else
      host_vm_list=()

      for host in "${select_host_list[@]}"
      do
       get_host_info "$host"
       temp_vms_info=$(excute_remote_command "$username@$ip -p $port" "VBoxManage list vms &")

       string_convert_array "$temp_vms_info" "2"

       if [ "${#return_array[@]}" > "1" ];
       then
         for vm in "${return_array[@]}"
         do
           vm_id=$(echo $vm | cut -d " " -f2)
           temp_vms_info=$(excute_remote_command "$username@$ip -p $port" "VBoxManage showvminfo $vm_id --machinereadable &")

           vm_name=$(echo "$temp_vms_info" | awk '{match($0, /name="(.[^"]+?)/, matchs);print matchs[1]}')
           cpus=$(echo "$temp_vms_info" | awk '{match($0, /cpus=(.[^ ]+?)/, matchs);print matchs[1]}')
           ostype=$(echo "$temp_vms_info" | awk '{match($0, /ostype="(.[^"]+?)/, matchs);print matchs[1]}' | sed 's/\s/_/g')
           VMState=$(echo "$temp_vms_info" | awk '{match($0, /VMState="(.[^"]+?)/, matchs);print matchs[1]}')
           memory=$(echo "$temp_vms_info" | awk '{match($0, /memory=(.[^ ]+?)/, matchs);print matchs[1]}')
           host_vm_list=("${host_vm_list[@]}" "$vm_name $VMState $ostype $cpus $memory"MB" $ip" )
         done
        else
          show_warning_dialog "Il n'y aucune machine."
        fi
     done

     if [ "${#host_vm_list[@]}" > "1" ];
     then

       all_vm_selected_list=$(zenity --width=800 --height=650 --list  --multiple --print-column=ALL --title="List les vms" --separator=" " --column="Nom" --column="Etat" --column="Systéme" --column="Nombre du cpu" --column="Taille Mémeoire" --column="Machine Hôte" ${host_vm_list[@]})

        if [ $? != "0" ]
        then
           select_host_list=()
           show_command_menu_dialog
           exit 1
        fi

      else
        show_warning_dialog "Il n'y aucune machine."
      fi
   fi
}

# Start, stop, restart, shut down a virtual machine
function manipulate_one_vm_dialog()
{
  select_host_list_dialog

  # get remote vm by host
  if [ "0" ==  ${#select_host_list[0]} ];
   then
      show_warning_dialog "Veuillez sélectionner le serveur cible pour exécuter la commande"
      manipulate_one_vm_dialog $1
   else

      get_all_vm_dialog

      if [ "${#all_vm_selected_list[@]}" > "1" ];
       then

         select_vm_list=()
         #convert full string to array
         string_convert_array "${all_vm_selected_list}" "6"

         #save selected host to list
         for ((i=0;i<${#return_array[@]};i++))
         do
           select_vm_list=("${select_vm_list[@]}" "${return_array[$i]}")
         done

          # case "$1" in
          #   "start")
          #   ;;
          #
          #   "pause")
          #   ;;
          #
          #   "stop")
          #   ;;
          #
          #   "restart")
          #   ;;
          # esac

      else
        show_warning_dialog "Il n'y aucune machine."
      fi
 
   fi
}

# Show VirutalBox Manage command list menu
function show_command_menu_dialog()
{
  # add menu comand
  vm_action_list=("Ajoutez une machine hôte" "ADD_HOST" \
                  "Retirez les machines hôtes et supprimer toutes les VM" "GET_ALL_HOST" \
                  "Déployer une VM sur une machine hôte" "DEPLOYE_VM" \
                  "Consultez la liste des VM" "GET_LIST_VM" \

                  "Démarrez une VM" "START_VM" \
                  "Arrêtez une VM" "STOP_VM" \
                  "Mettez en pause une VM" "PAUSE_VM" \
                  "Relancez une VM" "RESTART_VM" \

                  "Faites un snapshot sur une VM" "BACKUP_VM" \
                  "Revenez à un état précédent sur une VM" "RESET_VM" \
                  "Mettre à jour des VM" "SETTING_VM" \
                  )
  # show menu command
  command_action=$(zenity --width=500  --height=400 --list --text "Sélectez une commande" --hide-column="2" --print-column="2" --column "Action" --column "Command" "${vm_action_list[@]}");

  # launch a command
  lance_command_action $command_action
}
###
##======================= Dialog Functions =============================##
###

###
##======================= VirtualBox Functions =============================##
###
# Delete all host
function delete_all_host()
{
  remote_host_list=()
}

# Delete all VMs
function delete_all_vm()
{
  # get remote vm by host
  if [ "0" ==  ${#remote_host_list[0]} ];
   then
     show_warning_dialog "Veuillez ajoutez le serveur pour continuer"
     add_host_list_dialog
     delete_all_vm
   else
     for host in "${remote_host_list[@]}"
     do
      get_host_info "$host"
      temp_vms_info=$(excute_remote_command "$username@$ip -p $port" "VBoxManage list vms &")

      string_convert_array "$temp_vms_info" "2"

      if [ "${#return_array[@]}" > "1" ];
      then
        for vm in "${return_array[@]}"
        do
          vm_id=$(echo $vm | cut -d " " -f2)
          #temp_vms_info=$(excute_remote_command "$username@$ip -p $port" "VBoxManage unregister $vm_id --delete &")
          #vm_name=$(echo "$temp_vms_info" | awk '{match($0, /name="(.[^"]+?)/, matchs);print matchs[1]}')

          show_notification "La machine virtuelle $vm_name dans $ip a été supprimée."
        done
      fi
    done
  fi
}

###
##======================= VirtualBox Functions =============================##
###

###
##======================= Main Functions =============================##
###

# Launch a command of argument
function lance_command_action()
{

  case "$1" in
    "ADD_HOST")
      add_host_list_dialog
      show_command_menu_dialog
    ;;

    "GET_ALL_HOST")
      delete_all_vm_dialog
      show_command_menu_dialog
    ;;

    "GET_LIST_VM")
     get_all_vm_dialog
     show_command_menu_dialog
    ;;

    "DEPLOYE_VM")

    ;;

    "START_VM")
     manipulate_one_vm_dialog "start"
     show_command_menu_dialog
    ;;

    "PAUSE_VM")
     manipulate_one_vm_dialog "pause"
     show_command_menu_dialog
    ;;

    "STOP_VM")
     manipulate_one_vm_dialog "stop"
     show_command_menu_dialog
    ;;

    "RESTART_VM")
     manipulate_one_vm_dialog "restart"
     show_command_menu_dialog
    ;;

    "BACKUP_VM")

    ;;

    "RESET_VM")

    ;;

    "SETTING_VM")

    ;;
  esac
}

# Launch main programe
function run()
{
   # show primary menu
   show_command_menu_dialog
}
###
##======================= Main Functions =============================##
###


###
##======================= Lance programe =============================##
###

run

###
##======================= Lance programe =============================##
###
