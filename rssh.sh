#!/bin/bash

; ----------------------------------------------------------------
;
; Name: 		rssh.sh
; Author: 		Flatreaud Noë (@jellyfish101)
; Usage:
;
;	usage: rssh.sh PATH [-v|--verbose] [-h|--help]
;
;	This script executes multiple tasks on multiple hosts at the same time.
;	Feels like Ansible, smells like Ansible but not that much of Ansible !
;
;	OPTIONS:
;	   PATH         Path of the INI file used as remote configuration 
;	   -h|--help    Show help (this message)
;	   -v|--verbose Be verbose about what you're doing
;
; Dependencies: 
; 
; 	RSSH uses sshpass to execute commands, please verifiy that
; 	you have this installed on your system.
;
; ----------------------------------------------------------------

# -----------------------------------------------------------------
# CONFIG Parser
# -----------------------------------------------------------------

cfg_parser ()
{
    ini="$(<$1)"                # read the file
    oldifs=$IFS
    IFS=$'\n' && ini=( ${ini} ) # convert to line-array
    ini=( ${ini[*]//;*/} )      # remove comments with ;
    ini=( ${ini[*]/\    =/=} )  # remove tabs before =
    ini=( ${ini[*]/=\   /=} )   # remove tabs be =
    ini=( ${ini[*]/\ =\ /=} )   # remove anything with a space around =
    ini+=("[CFG_END]") # dummy section to terminate
    sections=()
    section=CFG_NULL
    vals=""
    for line in "${ini[@]}"; do
      #echo $line
      if [ "${line:0:1}" == "[" ] ; then
        #echo "section mark"
        # close previous section
        eval "cfg_${section}+=(\"$vals\")"
        #eval echo "cfg_$section[@]"
        if [ "$line" == "[CFG_END]" ]; then
          break
        fi
        # new section
        section=${line#[}
        section=${section%]}
        #echo "section: $section"
        secs="${sections[*]}"
        if [ "$secs" == "${secs/$section//}" ] ; then
          sections+=($section)
          eval "cfg_${section}=()"
        fi
        vals=""
        continue
      fi
      key=${line%%=*}
      value=${line#*=}
      value=${value//\"/\\\"}
      if [ "$vals" != "" ] ; then
        vals+=" "
      fi
      vals+="$key='$value'"
    done
    IFS=$oldifs
}

cfg_section_keys ()
# read number of keys (subsections) in a given section
{
  eval "keys=(\${!cfg_$1[@]})"
}

cfg_section ()
# read in settings for a specific key in a given section
{
  section=$1
  key=$2
  if [ "$key" == "" ] ; then
    key=0
  fi
  eval "vals=\${cfg_$section[$key]}"
  eval $vals
}

cfg_section_merge ()
# read and merge all settings for all keys of a given section
{
  cfg_section_keys $1
  for key in "${keys[@]}"; do
    cfg_section $section $key
  done
}

# -----------------------------------------------------------------
# RUN
# -----------------------------------------------------------------

# Run the application with first parameter as INI Config file
run() 
{
	# Parse INI File in parameter
	cfg_parser $1
	# Parse variables from [default] section and apply values if they exist
	cfg_section default
	# Get All keys from [task] sections 
	cfg_section_keys task

	i=1 # Task Index
	for task in "${keys[@]}"; do # Iterate through all [task] sections

		# Scope trough specific [task]
		cfg_section task $task

		echo "[$((i++))/${#keys[@]}] $desc..." # ex. [1/3] Apply echo task on hosts...

		# Get All keys from [host] sections
		cfg_section_keys host
		for host in "${keys[@]}"; do # Iterate trough all [host sections]
		
			# Scope trough specific [host]
			cfg_section host $host

			cmd="sshpass -p $password ssh -l -l $username $inet '$command' $VERBOSE" # build sshpass command using config variables
			
			# If verbose is defined, print the command
			if [[ ! -z VERBOSE ]]; then
				echo "* Executing task on host $name.."
				echo cmd
			fi
		
		done
	done
}

# Prints out Help message for this application
usage()
{
	cat << EOF

	usage: $0 PATH [-v|--verbose] [-h|--help]

	This script executes multiple tasks on multiple hosts at the same time.
	Feels like Ansible, smells like Ansible but not that much of Ansible !

	OPTIONS:
	   PATH         Path of the INI file used as remote configuration 
	   -h|--help    Show help (this message)
	   -v|--verbose Be verbose about what you're doing

  EOF
}

# -----------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------

# Get PATH and initialize VERBOSE to nothing
PATH=$1; shift
VERBOSE=""

# Check for flags (see usage)
while [ ! $# -eq 0 ]; do
    case "$1" in
        -v | --verbose)
            VERBOSE="-v"
            ;;
        -h | --help)
            usage
            exit
            ;;
        *)
            usage
            exit
            ;;
    esac
    shift
done

run PATH # call run()