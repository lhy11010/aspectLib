#!/bin/bash
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
test_dir="${dir}/.test"  # do test in this directory
if ! [[ -d ${test_dir} ]]; then
    mkdir "${test_dir}"
fi
test_fixtures_dir="tests/integration/fixtures"

set -a  # to export every variables that will be set

################################################################################
# Unit functions
element_in() {
	# determine if element is in an array
	local e match="$1"
	shift
	for e; do [[ "$e" == "$match" ]] && return 0; done
	return 1
}


take_record() {
    # Taking record of commands
    message=$(eval echo $1)
    record_file=$(eval echo $2)

    # add time stamp to record
    timestamp () {
                echo "$(date +"%Y-%m-%d_%H-%M-%S")"

    }

    echo "$(timestamp): ${message}" >> ${record_file}
}


fix_route() {
    # substitute ~ with ${HOME}
    local dir=$(pwd)
    if [[ "${1}" =~ ^[^\/\.~] ]]; then
        # append a relative route
        local output="${dir}/${1}"
    elif [[ "${1}" =~ ^~ ]]; then
        local output=${1/#~/$HOME}
    elif [[ "${1}" =~ ^\. ]]; then
        local output=${1/#\./$dir}
    else
        local output="$1"
    fi
    echo "${output}"
}

################################################################################
# Colours for progress and error reporting
BAD="\033[1;31m"
GOOD="\033[1;32m"
WARN="\033[1;35m"
INFO="\033[1;34m"
BOLD="\033[1m"


################################################################################
# Define candi helper functions

prettify_dir() {
   # Make a directory name more readable by replacing homedir with "~"
   echo ${1/#$HOME\//~\/}
}

cecho() {
    # Display messages in a specified colour
    COL=$1; shift
    echo -e "${COL}$@\033[0m"
}

cls() {
    # clear screen
    COL=$1; shift
    echo -e "${COL}$@\033c"
}

default () {
    # Export a variable, if it is not already set
    VAR="${1%%=*}"
    VALUE="${1#*=}"
    eval "[[ \$$VAR ]] || export $VAR='$VALUE'"
}

quit_if_fail() {
    # Exit with some useful information if something goes wrong
    STATUS=$?
    if [ ${STATUS} -ne 0 ]; then
        cecho ${BAD} 'Failure with exit status:' ${STATUS}
        cecho ${BAD} 'Exit message:' $1
        exit ${STATUS}
    fi
}


################################################################################
# Define functions to work with slurm system
get_remote_environment(){
    # get the value of a remote environment variable
    # Inputs:
    #   1: server_info
    #   2: variable name
    [[ $# = 2 ]] || return 1
    unset return_value
    local server_info=$1
    local name=$2
	ssh "${server_info}" << EOF > ".log"
        eval "echo \${${name}}"
EOF
	return_value=$(tail -n 1 ".log")
}


get_job_info(){
    # get info from the squeue command
    # inputs:
    #	1: job_id
    #	2: key
    unset return_value
    local _outputs
    local _temp
    if ! [[ "$1" =~ ^[0-9]*$ ]]; then
	    return 1
    fi
    _outputs=$(eval "squeue -j ${1} 2>&1")
    if [[ ${_outputs} =~ "slurm_load_jobs error: Invalid job id specified" ]]; then
        # catch non-exitent job id
        return_value='NA'
	return 0
    fi
    _temp=$(echo "${_outputs}" | sed -n '1'p)
    IFS=' ' read -r -a  _headers<<< "${_temp}"
    _temp=$(echo "${_outputs}" | sed -n '2'p)
    IFS=' ' read -r -a  _infos<<< "${_temp}"
    local i=0
    for element in ${_headers[@]}; do
	    if [[ "$element" = "$2" ]]; then
	        return_value="${_infos[i]}"
	        return 0
	    fi
        ((i++))
    done
    return 2  # if the key is not find, return an error message
}

parse_stdout(){
	# parse from a stdout file
	# Ouputs:
	#	last_time_step(str)
	#	last_time(str): time of last time step
	local _ifile=$1
	unset last_time_step
	unset last_time
	while IFS= read -r line; do
		if [[ ${line} =~ \*\*\* ]]; then
			break
		fi
	done <<< "$(sed '1!G;h;$!d' ${_ifile})"
	last_time_step=${line#*Timestep\ }
	last_time_step=${last_time_step%:*}
	last_time=${line#*t=}
	last_time=${last_time/ /}
}


read_log(){
	# read a log file
	# Inputs:
	#	$1: log file name
	local log_file=$1
	local i=0
	unset return_value0
	unset return_value1
    local line
	local foo
	while IFS= read -r line; do
        IFS=' ' read -r -a foo<<< "${line}"  # construct an array from line
        # i = 0 is the header line, ignore that
		if [[ $i -eq 1 ]]; then
			return_value0="${foo[0]}"
			return_value1="${foo[1]}"
		elif [[ $i -gt 1 ]]; then
			return_value0="${return_value0} ${foo[0]}"
			return_value1="${return_value1} ${foo[1]}"
		fi
        ((i++))
	done < "${log_file}"
	return 0
}


write_log_header(){
	# write a header to a log file
	# Inputs:
	#	$1: log file name
	local log_file=$1
	echo "job_dir job_id ST last_time_step last_time" > "${log_file}"
}


write_log(){
    # write to a log file
    # Inputs:
    #   $1: job id
    #   $2: job directory
    #   $3: log file name
    local job_dir=$1
    local job_id=$2
    local log_file=$3
    local _file
    get_job_info ${job_id} 'ST'
    quit_if_fail "get_job_info: invalid id number ${job_id} or no such stat 'ST'"
    local ST=${return_value}
    # parse stdout file
    for _file in ${job_dir}/*
    do
        # look for stdout file
        if [[ "${_file}" =~ ${job_id}.stdout ]]; then
            break
	fi
    done
    parse_stdout ${_file}  # parse this file
    echo "${job_dir} ${job_id} ${ST} ${last_time_step} ${last_time}" >> "${log_file}"
}
################################################################################
# Test functions
test_element_in(){
	local _test_array=('a' 'b' 'c d')
	if ! element_in 'a' "${_test_array[@]}"; then
		cecho ${BAD} "test_element_in failed, 'a' is not in ${_test_array}[@]"
	fi
	if element_in 'c' "${_test_array[@]}"; then
		cecho ${BAD} "test_element_in failed, 'c' is in ${_test_array}[@]"
	fi
	cecho ${GOOD} "test_element_in passed"

}


test_parse_stdout(){
	# test the parse_stdout function, return values are last timestpe and time
	local _ifile="tests/integration/fixtures/task-2009375.stdout"
	if ! [[ -e ${_ifile} ]]; then
		cecho ${BAD} "test_parse_stdout failed, no input file ${_ifile}"
		exit 1
	fi
	parse_stdout ${_ifile}  # parse this file
	if ! [[ ${last_time_step} = "10" ]]; then
		cecho ${BAD} "test_parse_stdout failed, time_step is wrong"
		exit 1
	fi
	if ! [[ ${last_time} = "101705years" ]]; then
		cecho ${BAD} "test_parse_stdout failed, time is wrong"
		exit 1
	fi
	cecho ${GOOD} "test_parse_stdout passed"
}


test_read_log(){
	local log_file="${test_fixtures_dir}/test.log"
	read_log "${log_file}"
	if ! [[ "${return_value0}" = "tests/integration/fixtures tests/integration/fixtures" && "${return_value1}" = "2009375 2009376" ]]; then
		cecho ${BAD} "test_read_log failed, return values are not correct"
		return 1
	fi
	cecho ${GOOD} "test_read_log passed"
}


test_write_log(){
    local _ofile="${test_dir}/test.log"
    if [[ -e ${_ofile} ]]; then
        # remove older file
        eval "rm ${_ofile}"
    fi
    # test 1, write a non-existent job, it should return a NA status
    write_log_header "${_ofile}"
    write_log "${test_fixtures_dir}" "2009375" "${_ofile}"
    if ! [[ -e "${_ofile}" ]]; then
        cecho ${BAD} "test_write_log fails for test1, \"${_ofile}\"  doesn't exist"
	exit 1
    fi
    _output=$(cat "${_ofile}" | sed -n '2'p)
    if ! [[ ${_output} = "${test_fixtures_dir} 2009375 NA 10 101705years" ]]
    then
        cecho ${BAD} "test_write_log fails for test2, output format is wrong"
	exit 1
    fi
    cecho ${GOOD} "test_write_log passed"

}

test_fix_route() {
    # test1 test for relacing '~'
    fixed_route=$(fix_route "~/foo/ffoooo")
    [[ "${fixed_route}" = "${HOME}/foo/ffoooo" ]] || { cecho ${BAD} "test_fix_route failed for test 1"; exit 1; }
    # test2, test for replacing '.'
    local dir=$(pwd)
    fixed_route=$(fix_route "./foo/ffoooo")
    [[ "${fixed_route}" = "${dir}/foo/ffoooo" ]] || { cecho ${BAD} "test_fix_route failed for test 2"; exit 1; }
    # test3, test for replacing relative route
    fixed_route=$(fix_route "foo/ffoooo")
    [[ "${fixed_route}" = "${dir}/foo/ffoooo" ]] || { cecho ${BAD} "test_fix_route failed for test 3"; exit 1; }
    cecho ${GOOD} "test_fix_route passed"
}


main(){
	if [[ "$1" = "test" ]]; then
		# run tests by ./utilities.sh test
		test_parse_stdout
        test_fix_route
		test_element_in
        # these two must be down with a slurm systems, todo_future: fix it
		test_read_log
		test_write_log
	fi
}


set +a  # return to default setting


if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
	main $@
fi
