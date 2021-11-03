#!/bin/bash

# ------------------------------------------------------------
# Simple remote culster shh command executor
# Noë FLATREAUD 03/11/2021
# * known issues : using variables in the INI file might break the script ! Beware !
# * TODO : being able to use variables in the INI file
# -----------------------------------------------------------

# -----------------------------------------------------------------------
# PARSE PSEUDO-LIBRaRY
# -----------------------------------------------------------------------

# parse config file into associative array
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

# -----------------------------------------------------------------------
# CONSTANT DECLARATIONS
# -----------------------------------------------------------------------

# region Color definitions

NC='\033[0m'

YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
CYAN='\033[0;36m'

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'

# region Script constants

VERBOSE=""
ERROR=0

FILE=$1; shift

# -----------------------------------------------------------------------
# FUNCTION DECLARATIONS
# -----------------------------------------------------------------------

# Execute script behaviour
run()
{
	local file="$1" # defining file locally as 1st argument of run()

	# Check if file exists, else Error!
	if [[ ! -f "$file" ]]; then
		echo -e "[${RED}Error${NC}] \"$file\" doesn't exist!"
		return 1
	fi

	# Parse configuration
	cfg_parser $file	# Parse file
	cfg_section default 	# Get defaults
	cfg_section_keys task	# Get Task keys

	i=1 # Task index
	# Iterate trough task keys
	for task in "${keys[@]}"; do
		cfg_section task $task # Task scope
		echo -e "\n[${YELLOW}$((i++))/${#keys[@]}${NC}] $title..." #cg. [1/3] Here is myNewTaskTitle...
		cfg_section_keys host # Get host keys
		# Iterate trough host keys
		for host in "${keys[@]}"; do
			cfg_section host $host # host scope
			# Build commandfrom string
			# TODO : better command building to allow variable calls in INI file
			# TODO : Improve Security
			CMD="sshpass -p '$password' ssh -o \"UserKnownHostsFile=/dev/null\" -o \"StrictHostKeyChecking=no\" $username@$inet '$command'"
			eval $CMD # Evaluate built command
			# check command return value
			if [[ $? -eq 0 ]]; then
				# command ended successfully
				echo -e "[${GREEN}OK${NC}] ($name) : Command Returned successfully ($?)"
			else
				# there was an error during command execution
				ERROR=$((ERROR+$?))
				echo -e "[${RED}Error${NC}] ($name) : Oops ! Something went wrong ($ERROR)"
			fi

			# check for VERBOSE argument
			if [[ ! -z "$VERBOSE" ]]; then
				# debug command string when VERBOSE is defined
				echo -e "${CYAN}$CMD${NC}"
			fi
			done
	done

	# Check for errors
	if [[ $ERROR -gt 0 ]]; then
		echo -e "\n[${RED}Error${NC}] RSSH Command stopped with errors ($ERROR) !\n"
		return 1;
	else
		echo -e "\n[${GREEN}OK${NC}] RSSH Command ended successfully !\n"
		return 0;
	fi
}

# usage command message, called for help or when command is misused
usage()
{
	echo
	echo "usage:   $0 FILE_PATH [-v|--verbose] [-h|--help]"
	echo
	echo "  FILE_PATH 		Path to the INI file used as remoteconfig"
	echo "  -v | --verbose	Be verbose about what you do"
	echo "  -h | --help		Display help message (this message)"
	echo
}

# Checking for short & long flags
while [ ! $# -eq 0 ]; do
	case "$1" in
		-v|--verbose) echo -e "${CYAN}Enabled Verbose${NC}"; VERBOSE="-v" ;;
		-h|--help) usage; exit ;;
		*) usage; exit ;;
	esac
	shift
done

#run default.ini
run $FILE # running script behaviour

# If command ended with errors, prints out usage message
if [[ $? -gt 0 ]]; then
	usage
	exit 1
fi
