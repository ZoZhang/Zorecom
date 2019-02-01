#!/bin/bash
#
# a simple remote command execution script
#
# @author Zhao ZHANG <zo.zhang@gmail.com>
# Usage: ./zorecom.sh
#
remote_host_list=("z18013171 Fg.123456 10.203.9.106 22 d18025352 test 10.203.9.107 22 b17026741 test 10.203.9.108 22")
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

# excute VirutalBox command
# @param $1:action $2:vm uuid
function get_vm_command()
{
  #Adapt operation command line
  case "$1" in

     "start")
      manipulate_command+="VBoxManage startvm "$2" --type headless;"
     ;;

     "pause")
      manipulate_command+="VBoxManage controlvm "$2" pause;"
     ;;

     "resume")
      manipulate_command+="VBoxManage controlvm "$2" resume;"
     ;;

     "stop")
      manipulate_command+="VBoxManage controlvm "$2" savestate; VBoxManage controlvm "$2" poweroff;"
     ;;

     "restart")
      get_vm_command "stop"  "$2"
      get_vm_command "start"  "$2"
     ;;

     "backup")
       current_date=$(date +"%m-%d-%Y%T")
       new_snapshot="NEW_SNAPSHOT_AUTOMATIQUE_$current_date"
       new_snapshot_description="Snapshot taken on $current_date"
       manipulate_command+="VBoxManage snapshot "$2" take \"$new_snapshot\" --description \"$new_snapshot_description\";"
     ;;

     "restore_snapshot")
      manipulate_command+="VBoxManage snapshot "$2" restore "$restore_napshot_id";"
     ;;

     "snapshot_list")
      manipulate_command+="VBoxManage snapshot "$2" list --machinereadable;"
     ;;

     "screenshot")
      current_date=$(date +"%m-%d-%Y%T")
      new_screenshotpng="/tmp/screenshotpng_$current_date.png"
      manipulate_command+="VBoxManage controlvm "$2" screenshotpng $new_screenshotpng;"
     ;;

     "config")
     manipulate_command+="VBoxManage modifyvm "$2" --name \"$3\" --description \"$7\" --cpus $4 --vram $5 --memory $6;"

     ;;

     "deploye")
      manipulate_command+="VBoxManage createvm --name \"$2\"  --ostype $3  --register;"
     ;;

     "delete")
      get_vm_command "stop"  "$2"
      manipulate_command+="VBoxManage unregister \"$2\" --delete;"
     ;;

  esac

  # launch programe in backend
  #manipulate_command+="&"
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
  #Initial selection host list
  select_host_list=()

  #currenty get vm list by action
  currenty_action=$1

  select_host_list_dialog

  # get remote vm by host
  if [ "0" ==  ${#select_host_list[0]} ];
   then
      show_warning_dialog "Veuillez sélectionner le serveur cible pour exécuter la commande"
      get_all_vm_dialog $1
   else
      host_vm_list=()

      for host in "${select_host_list[@]}"
      do
       get_host_info "$host"
       temp_vms_info=$(excute_remote_command "$username@$ip -p $port" "VBoxManage list vms &")

       string_convert_array "$temp_vms_info" "2"

       if [ "${#return_array[@]}" -gt 0 ];
       then
         for vm in "${return_array[@]}"
         do
           vm_id=$(echo $vm | cut -d " " -f2)
           temp_vms_info=$(excute_remote_command "$username@$ip -p $port" "VBoxManage showvminfo $vm_id --machinereadable &")

           # setter parametre variable
           vm_name=$(echo "$temp_vms_info" | awk '{match($0, /name="(.[^"]+?)/, matchs);print matchs[1]}')
           cpus=$(echo "$temp_vms_info" | awk '{match($0, /cpus=(.[^ ]+?)/, matchs);print matchs[1]}')
           ostype=$(echo "$temp_vms_info" | awk '{match($0, /ostype="(.[^"]+?)/, matchs);print matchs[1]}' | sed 's/\s/_/g')
           VMState=$(echo "$temp_vms_info" | awk '{match($0, /VMState="(.[^"]+?)/, matchs);print matchs[1]}')
           memory=$(echo "$temp_vms_info" | awk '{match($0, /memory=(.[^ ]+?)/, matchs);print matchs[1]}')

           #filter only this state of vm by action
           case "$currenty_action" in
             "start")

              # Filtering has been started vm
              if [ "running" == $VMState ]
              then
                  continue;
              fi

             ;;

             "pause")

               # Filtering has been poweroff or paused vm
               if [ "paused" == $VMState ] || [ "poweroff" == $VMState ]
               then
                   continue;
               fi

             ;;

             "stop")

               # Filtering has been poweroff vm
               if [ "poweroff" == $VMState ]
               then
                   continue;
               fi

             ;;

             "resume")

               # Filtering not has been paused vm
               if [ "paused" != $VMState ]
               then
                   continue;
               fi

             ;;
           esac

           host_vm_list=("${host_vm_list[@]}" "$vm_name $vm_id $VMState $ostype $cpus $memory"MB" $username $ip $port" )
         done
        else
          show_warning_dialog "Il n'y aucune machine trouvé."
        fi
     done

     if [ "${#host_vm_list[@]}" -gt 0 ];
     then

       all_vm_selected_list=$(zenity --width=800 --height=500 --list  --multiple --print-column=ALL --hide-column=2,7,9 --title="List les vms" --separator=" " --column="Nom" --column="UUID" --column="Etat" --column="Systéme" --column="Nombre du cpu" --column="Taille Mémeoire" --column="Utilisateur Hôte" --column="Machine Hôte" --column="Port Hôte" ${host_vm_list[@]})

        if [ $? != "0" ]
        then
           show_command_menu_dialog
           exit 1
        fi

      else
        show_warning_dialog "Il n'y aucune machine trouvé."
      fi
   fi
}

# View all snapshot of vm selected
# @param $1:username@ip:port $2:vm UUID
function show_snapshot_vm_dialog()
{
  #get vm command
  get_vm_command "snapshot_list" "$2"
  temp_vms_info=$(excute_remote_command "$1" "$manipulate_command")

  if [ -z $temp_vms_info ]
  then
    show_warning_dialog "Il n'y aucune snapshot sur cette vm"
  else

    #vm_name=$(echo "$temp_vms_info" | awk '{match($0, /SnapshotName(.[^"]+?)/, matchs);print matchs[1]}')
    show_warning_dialog "Cette fonctionnalité est encore en construction"
  fi
  show_command_menu_dialog
}

#selection a ostype to add a vm
function show_select_ostype_vm_dialog()
{
   temp_vms_os_types=$(VBoxManage list ostypes)

   os_type_id=$(echo "$temp_vms_os_types" | awk '{match($0, /^ID:(.[^\n]+?)/, matchs);print matchs[1]}')

   os_type_selected=$(zenity --width 309 --height 400 --list --radiolist --title="Veuillez sélectionner un système" --column "Votre Choix" --column "Type de système" $os_type_id)

   if [ $? != "0" ]
   then
      show_command_menu_dialog
      exit 1
   fi
}

#Add a vm to selection host
# @param $1:username@ip:port $2:vm UUID
function add_vm_dialog()
{
   select_host_list_dialog

    # get remote vm by host
    if [ "0" ==  ${#select_host_list[0]} ];
     then
        show_warning_dialog "Veuillez sélectionner le serveur cible pour exécuter la commande"
        add_vm_dialog $1
     else

       if [ -z "$add_vm_name" ]
       then
         add_vm_name=$(zenity --forms --title="Ajoute une vm" --text="Saisissez vos configurations" --separator=" " --add-entry="Name")

         if [ $? != "0" ]
         then
            show_command_menu_dialog
            exit 1
         fi
       fi

        # show selection ostype dialog
        show_select_ostype_vm_dialog

        if [ -z "$os_type_selected" ]
        then
          show_warning_dialog "Veuillez sélectionner le type de os pour la vm"
          add_vm_dialog $1
        else

           #get vm command
           get_vm_command "deploye" "$add_vm_name" "$os_type_selected"

           #launch remote command
           if [ -z "$manipulate_command" ]
           then
             show_notification "la creation la machine virtuelle a échoué."
           else
               for host in "${select_host_list[@]}"
               do
                  get_host_info "$host"

                  temp_vms_info=$(excute_remote_command "$username@$ip -p $port" "$manipulate_command")

                  echo $temp_vms_info
                  show_notification "La nouvelle machine virtuelle ($add_vm_name) a été créée avec succès dans le $ip."
               done
           fi
        fi
    fi
}

#Edit configuration information to vm
# @param $1:username@ip:port $2:vm UUID
function show_config_modity_vm_dialog()
{
    config_info=$(zenity --forms --title="Modifie des confitugrations" --text="Saisissez vos configurations" --separator=" " --add-entry="Nouveau Name" --add-entry="Nombre Cpu"  --add-entry="Taille Graphique (MB)" --add-entry="Taille Memeoire (MB)" --add-entry="Nouvelle Description")

    if [ $? != "0" ]
    then
       show_command_menu_dialog
       exit 1
    fi

    newname=$(echo $config_info | cut -d " " -f 1)
    newcpu=$(echo $config_info | cut -d " " -f 2)
    newvram=$(echo $config_info | cut -d " " -f 3)
    newmemory=$(echo $config_info | cut -d " " -f 4)
    newdescription=$(echo $config_info | cut -d " " -f 5)

    #get vm command
    get_vm_command "config" "$2" "$newname" "$newcpu" "$newvram" "$newmemory" "$newdescription"
    temp_vms_info=$(excute_remote_command "$1" "$manipulate_command")
}

# Start, stop, restart, shut down a virtual machine
function manipulate_some_vm_dialog()
{
  get_all_vm_dialog "$1"

  # get remote vm by host
  if [ "0" ==  ${#select_host_list[0]} ];
   then
      show_warning_dialog "Veuillez sélectionner le serveur cible pour exécuter la commande"
      manipulate_some_vm_dialog $1
   else

      if [ "${#all_vm_selected_list[@]}" -gt 0 ];
       then

         select_vm_list=()
         manipulate_command=
         #convert full string to array
         string_convert_array "${all_vm_selected_list}" "9"

         #each selected vm by list
         for ((i=0;i<${#return_array[@]};i++))
         do

            vm_name=$(echo ${return_array[$i]} | cut -d " " -f1)
            vm_id=$(echo ${return_array[$i]} | cut -d " " -f2)

            username=$(echo ${return_array[$i]} | cut -d " " -f7)
            ip=$(echo ${return_array[$i]} | cut -d " " -f8)
            port=$(echo ${return_array[$i]} | cut -d " " -f9)

            if [ "restore" == $1 ]
            then
               #TOdoo restor snaphsot
               show_snapshot_vm_dialog "$username@$ip -p $port" "$vm_id"

            elif [ "config" == $1 ]
            then
                # Edit configuration information
                show_config_modity_vm_dialog "$username@$ip -p $port" "$vm_id"
                show_notification "La machine virtuelle $vm_name a été modifié dans $ip a été."
            else

              #get vm command
              get_vm_command "$1" "$vm_id"

              #launch remote command
              if [ -z "$manipulate_command" ]
              then
                show_notification "$1 la machine virtuelle $vm_name dans $ip a échoué."
              else

                temp_vms_info=$(excute_remote_command "$username@$ip -p $port" "$manipulate_command")

                #Save current state before shutting down vm
                if [ "stop" == $1 ]
                then
                    show_notification "L'état actuel de la machine virtuelle $vm_name dans $ip a été stocké."
                elif [ "backup" == $1 ]
                then
                    show_notification "La capture instantanée ($new_snapshot) a été créée automatiquement avec succès dans $ip."
                elif [ "screenshot" == $1 ]
                then
                  show_notification "La capture d'image a été créée avec succès dans $new_screenshotpng."
                fi

                #Convient à la plupart des notifications automatisées sauf backup
                if [ "backup" != $1 ]
                then
                    show_notification "La machine virtuelle $vm_name dans $ip a été $1."
                fi

              fi
            fi

         done
      fi

   fi
}

# Show VirutalBox Manage command list menu
function show_command_menu_dialog()
{
  # add menu comand
  vm_action_list=("Ajoutez une machine hôte" "ADD_HOST" \
                  "Retirez les machines hôtes et supprimer toutes les VM" "GET_ALL_HOST" \
                  "Déployer une VM sur une ou plusieurs machines hôtes" "DEPLOYE_VM" \
                  "Supprimer une VM sur une ou plusieurs machines hôtes" "DELETE_VM" \
                  "Consultez la liste des VM" "GET_LIST_VM" \

                  "Démarrez une ou plusieurs VM" "START_VM" \
                  "Arrêtez une VM ou plusieurs" "STOP_VM" \
                  "Mettez en pause une ou plusieurs VM" "PAUSE_VM" \
                  "Reprendre une ou plusieurs VM pause en fonction" "RESUME_VM" \
                  "Relancez une VM ou plusieurs" "RESTART_VM" \
                  "Prenez une capture d’image png des vm" "SCREENSHOT_VM" \

                  "Faites un snapshot sur une VM" "BACKUP_VM" \
                  "Revenez à un état précédent sur une VM" "RESTORE_VM" \
                  "Mettre à jour la confituration pour les VM" "CONFIG_VM" \
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
      add_vm_dialog
      show_command_menu_dialog
    ;;

    "DELETE_VM")
      manipulate_some_vm_dialog "delete"
      show_command_menu_dialog
    ;;

    "START_VM")
     manipulate_some_vm_dialog "start"
     show_command_menu_dialog
    ;;

    "PAUSE_VM")
     manipulate_some_vm_dialog "pause"
     show_command_menu_dialog
    ;;

    "STOP_VM")
     manipulate_some_vm_dialog "stop"
     show_command_menu_dialog
    ;;

    "RESTART_VM")
     manipulate_some_vm_dialog "restart"
     show_command_menu_dialog
    ;;

    "RESUME_VM")
     manipulate_some_vm_dialog "resume"
     show_command_menu_dialog
    ;;

    "BACKUP_VM")
      manipulate_some_vm_dialog "backup"
      show_command_menu_dialog
    ;;

    "RESTORE_VM")
      manipulate_some_vm_dialog "restore"
      show_command_menu_dialog
    ;;

    "SCREENSHOT_VM")
      manipulate_some_vm_dialog "screenshot"
      show_command_menu_dialog
    ;;

    "CONFIG_VM")
      manipulate_some_vm_dialog "config"
      show_command_menu_dialog
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

#show_warning_dialog "\n\n\nCet outil ne fonctionne que si openssh est déjà autorisé.\n\nParce qu'il ne utilise pas des tiers outils comme sshpass ou expert."

run

###
##======================= Lance programe =============================##
###
