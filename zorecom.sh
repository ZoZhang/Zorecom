#!/bin/bash
#
# a simple remote command execution script
#
# @author Zhao ZHANG <zo.zhang@gmail.com>
# Usage: ./zorecom.sh
#
remote_host_list=("z18013171 Fg.123456 127.0.0.1 22")
select_host_list=()

###
##======================= Helper Functions =============================##
###

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
  pos=4
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
function show_warning_notification()
{
echo
}

# Show a warning dialog
function show_warning_dialog()
{
  zenity --info --title="Sélectez les serveurs" --text="$1"
}

# Show host list dialog for add a service
function show_host_list_dialog()
{
     remote_host=$(zenity --forms --title="Ajoute des serveurs" --text="Saisissez vos serveurs" --separator=" " --add-entry="Utilisateurs"  --add-password="Mot de passe"  --add-entry="IP address" --add-entry="Port")

     if [ $? != "0" ]
     then
        exit 1
     fi

     remote_host_list=("${remote_host_list[@]}" "$remote_host" )
}

# Show select host list
function select_host_list_dialog()
{
   select_host=$(zenity --list --title="Sélectez les serveurs" --separator=" " --multiple --print-column=ALL --hide-column=2 --column="Utilisateur" --column="Password" --column="IP" --column="Port" ${remote_host_list[@]})

   if [ $? != "0" ]
   then
      exit 1
   fi

   #convert full string to array
   string_convert_array "${select_host}"

   #save selected host to list
   for ((i=0;i<${#return_array[@]};i++))
   do
     select_host_list=("${select_host_list[@]}" "${return_array[$i]}")
   done
}

# Delete all vm
function delete_all_vm_dialog()
{
   if zenity --question  --text="Êtes-vous sûr de vouloir tout supprimer?"
   then
     echo 'supir'
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

# View all vm of host selected
function get_all_vm()
{
  select_host_list_dialog

  if [ "0" ==  ${#select_host_list[0]} ];
   then
      show_warning_dialog "Veuillez sélectionner le serveur cible pour exécuter la commande"
      get_all_vm
   else

      for host in "${select_host_list[@]}"
     do
       get_host_info "$host"
       excute_remote_command "$username@$ip -p $port" "VBoxManage list vms"
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
      show_host_list_dialog
      show_command_menu_dialog
    ;;

    "GET_ALL_HOST")
      delete_all_vm
      delete_all_host
      show_command_menu_dialog
    ;;

    "GET_LIST_VM")
     get_all_vm
     show_command_menu_dialog

    ;;

    "DEPLOYE_VM")

    ;;

    "START_VM")

    ;;

    "PAUSE_VM")

    ;;

    "STOP_VM")

    ;;

    "RESTART_VM")

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
