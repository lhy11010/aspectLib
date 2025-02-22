#!/bin/bash
# example usage:
#  slurm.sh -N 1 -n 4 -l /home/lochy/ASPECT_PROJECT/aspectLib/.output/job.log -lt ./output/machine_time --hold

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${dir}/utilities.sh"

# default value
filename="test.prm"
nnode=1
total_tasks=1
time_by_hour=24
partition="high2"
name="task"
mem_per_cpu=2000  # 2000M
project="TwoDSubduction"
hold=0  # hold jobs

test_dir="${dir}/.test"  # do test in this directory
if ! [[ -d ${test_dir} ]]; then
    mkdir "${test_dir}"
fi
test_fixtures_dir="${dir}/tests/integration/fixtures"

usage()
{
    printf "\
Submit a job to cluster with a slurm system

Usage:
  %s [options] [server_name] [file_name]

Options:
"
}

parse_command(){
    unset _command
    # parse command with the fist input
    if [[ "$1" =~ -.* || "$1" = "submit" ]]; then
	    _command="submit"
    elif [[ "$1" = "remote" ]]; then
	    _command="remote"
    elif [[ "$1" = "test" ]]; then
	    _command="test"
    elif [[ "$1" = "remote_test" || "$1" = "rt" ]]; then
	    _command="remote_test"
    elif [[ "$1" = "write_log" ]]; then
	    _command="write_log"
    else
	    return 1
    fi
    return 0
}

parse_options(){
    # parse parameters from command line
    # future pass in name of case
    while [ -n "$1" ]; do
      param="$1"
      case $param in
        -h|--help)
          echo ""  # help information
          exit 0
        ;;
        #####################################
        # filename
        #####################################
        [^-]*)
          filename=$(fix_route "$param")
        ;;
        #####################################
        # number of total tasks
        #####################################
        -n)
          shift
          total_tasks="${1}"
        ;;
        -n=*|--total_tasks=*)
          total_tasks="${param#*=}"
        ;;
        #####################################
        # number of nodes
        #####################################
        -N)
          shift
          nnode="${1}"
        ;;
        -N=*|--nnode=*)
          nnode="${param#*=}"
        ;;
        #####################################
        # time in hour
        #####################################
        -t)
          shift
          time_by_hour="${1}"
        ;;
        -t=*|--time=*)
          time_by_hour="${param#*=}"
        ;;
        #####################################
        # partition
        #####################################
        -p)
          shift
          partition="${1}"
        ;;
        -p=*|--partition=*)
          partition="${param#*=}"
        ;;
        #####################################
        # memory per cpu
        #####################################
        -m)
          shift
          mem_per_cpu="${1}"
        ;;
        -m=*|--mem-per-cup=*)
          mem_per_cpu="${param#*=}"
        ;;
        #####################################
        # log file
        #####################################
        -l)
          shift
          local temp="${1}"
	  log_file=$(fix_route "${temp}")
        ;;
        -l=*|--log_file=*)
          local temp="${param#*=}"
	  log_file=$(fix_route "${temp}")
        ;;
        #####################################
        # log file for time
        #####################################
        -lt)
          shift
          local temp="${1}"
	  log_file_time=$(fix_route "${temp}")
        ;;
        -lt=*|--log_file_time=*)
          local temp="${param#*=}"
	  log_file_time=$(fix_route "${temp}")
        ;;
        #####################################
        # project
        #####################################
        -P)
          shift
          project="${1}"
        ;;
        -P=*|--project=*)
          project="${param#*=}"
        ;;
        #####################################
        # bool value
        #####################################
        -b)
          shift
          bool="${1}"
        ;;
        -b=*|--bool=*)
          bool="${param#*=}"
        ;;
        #####################################
        # float value
        #####################################
        -f)
          shift
          float="${1}"
        ;;
        -f=*|--float=*)
          float="${param#*=}"
        ;;
        #####################################
        # bind to
        #####################################
        -bd)
          shift
          bind_to="${1}"
        ;;
        -bd=*|--bind_to=*)
          bind_to="${param#*=}"
	;;
        #####################################
        # hold job
        #####################################
        --hold)
          hold=1
        ;;
        #####################################
        # use file
        #####################################
        --file=*)
          job_file="${param#*=}"
        ;;
      esac
      shift
    done
    
    # check values
    [[ -z ${bool} || ${bool} = "true" || ${bool} = "false" ]] || { cecho ${BAD} "${FUNCNAME[0]}: bool value must be true or false"; exit 1; }
    [[ -z ${float} || ${float} =~ ^[0-9\.]+$ ]] || { cecho ${BAD} "${FUNCNAME[0]}: entry for \${float} must be a float value"; exit 1; }
}


########################################
submit(){
    # The useful part of your job goes below

    export OMP_NUM_THREADS=$SLURM_NTASKS

    # Aspect executable
    # add project_dir after aspect_dir, like 'build_master'

    Aspect_project_DIR="${Aspect_DIR}_${project}"
    Aspect_executable="${Aspect_project_DIR}/aspect"

    # Aspect_executable="${Aspect_DIR}/aspect"

    # compose the sbatch file
    # future: add comment to sbatch file

    # check for filename

    [[ -e "${filename}" ]] || { cecho ${BAD} "${filename} doesn't exit"; exit 1; }

    # first cd to the folder
    local previous_dir=$(pwd)
    local case_dir=$(dirname "$filename")
    cd "$case_dir"

    if [ -f 'job.sh' ]; then
    	eval "rm job.sh"
    fi

    # create slurm script
    eval "touch job.sh"

    # write slurm messages
    echo "#!/bin/bash -l" >> job.sh
    echo "#SBATCH -J $name" >> job.sh
    echo "#SBATCH -N $nnode" >> job.sh
    echo "#SBATCH -n $total_tasks" >> job.sh
    # tasks per node
    ((tasks_per_nodes=total_tasks/nnode))
    echo "#SBATCH --tasks-per-node=${tasks_per_nodes}" >> job.sh
    echo "#SBATCH -o $name-%j.stdout" >> job.sh
    echo "#SBATCH -e $name-%j.stderr" >> job.sh
    echo "#SBATCH -t $time_by_hour:00:00" >> job.sh
    echo "#SBATCH --partition=$partition" >> job.sh
    echo "#SBATCH --mem-per-cpu=$mem_per_cpu" >> job.sh
    echo "" >> job.sh

    # unload module openmpi and load Max Rudolph's version
    if [[ $(hostname) = "peloton.cse.ucdavis.edu" ]]; then
      echo "module unload openmpi" >> job.sh
      echo "export PATH=/home/rudolph/sw/openmpi-4.0.5/bin:\$PATH" >> job.sh
      echo "" >> job.sh
    fi

    addition=""
    [[ -n ${bind_to} ]] && addition="$addition --cpu-bind=${bind_to}"
    echo "srun ${addition} ${Aspect_executable} ${filename}" >> job.sh

    # submit the job, hold if the hold option is 1

    (( hold == 0 )) && eval "sbatch -p $partition job.sh"

    # go back to previous dir
    cd "${previous_dir}"
}

################################################################################
# submit_with_file()
################################################################################





################################################################################
# test functions
################################################################################
test_parse_command(){
    unset _command
    # case 1
    parse_command 'submit' '-n' '32'
    if [[ ${_command} != "submit" ]]; then
	cecho ${BAD} "test_parse_command fail for \"submit -n 32\""
        exit 1
    fi
    unset _command
    # case 2
    parse_command '-n' '32'
    if [[ ${_command} != "submit" ]]; then
	cecho ${BAD} "test_parse_command fail for \"-n 32\""
	exit 1
    fi
    unset _command
    # case 3
    parse_command 'remote' '-n' '32'
    if [[ ${_command} != "remote" ]]; then
	cecho ${BAD} "test_parse_command fail for \"remote -n 32\""
	exit 1
    fi
    unset _command
    # case 4
    parse_command 'foo'
    if [[ "$?" != 1 ]]; then
	cecho ${BAD} "test_parse_command fail for \"foo\""
	exit 1
    fi
    cecho ${GOOD} "test_parse_command passed"
}

test_submit(){
    # test submit to local slurm system
    # copy file to test_dir
    cp "${dir}/tests/integration/fixtures/submit_test.prm" "${test_dir}/"
    local job_id
    # test 1: mission with 1 core
    local _test="slurm.sh -n 1 -p med2 ${test_dir}/submit_test.prm"
    job_id=$(eval "${_test}" | sed 's/Submitted\ batch\ job\ //')
    if ! [[ ${job_id} =~ ^[0-9]*$ ]]; then
        cecho ${BAD} "test_submit fail for \"${_test}\", job id is not returned"
	exit 1
    fi
    # get info from the squeue command
    get_job_info ${job_id} 'ST'
    quit_if_fail "get_job_info: no such stat 'ST'"
    if ! [[ ${return_value} = 'R' || ${return_value} = 'PD' ]]; then
        cecho ${BAD} "test_submit fail for \"${_test}\", job failed"
	exit 1
    fi
    eval "scancel ${job_id}"  # terminate this job

    # test 2: mission with nproc core
    local _nproc=$(nproc)  # numbers of cores in a node
    _test="slurm.sh -n ${_nproc}  -p med2 ${test_dir}/submit_test.prm"
    job_id=$(eval "${_test}" | sed 's/Submitted\ batch\ job\ //')
    if ! [[ ${job_id} != '' && ${job_id} =~ ^[0-9]*$ ]]; then
	cecho ${BAD} "test_submit fail for \"${_test}\", job id is not returned"
	exit 1
    fi
    # get info from the squeue command
    get_job_info ${job_id} 'ST'
    quit_if_fail "get_job_info: no such stat 'ST'"
    if ! [[ ${return_value} = 'R' || ${return_value} = 'PD' ]]; then
	cecho ${BAD} "test_submit fail for \"${_test}\", job failed"
	exit 1
    fi
    get_job_info ${job_id} 'CPU'
    quit_if_fail "get_job_info: no such stat 'CPU'"
    if ! [[ ${return_value} = ${_nproc} ]]; then
	cecho ${BAD} "test_submit fail for \"${_test}\", nproc doesn't match"
	exit 1
    fi
    eval "scancel ${job_id}"  # terminate this job
    # test 3 submit with a log file assigned, case infomation will be added to this file
    _log_file="${test_dir}/job.log"
    [[ -e "${_log_file}" ]] && eval "rm ${_log_file}"  # remove older file
    _test="slurm.sh -n ${_nproc}  -p med2 ${test_dir}/submit_test.prm -l ${test_dir}/job.log"
    job_id=$(eval "${_test}" | sed 's/Submitted\ batch\ job\ //')
    if ! [[ ${job_id} != '' && ${job_id} =~ ^[0-9]*$ ]]; then
	cecho ${BAD} "test_submit fail for \"${_test}\", job id is not returned"
	exit 1
    fi
    # pull out content in the output file
    _line=$(sed -n '2'p "${_log_file}")
    # compare with standard ouput
    if ! [[ "${_line}" =~ \.test\ [0-9]+\ [A-Z]+ ]]; then
	    cecho ${BAD} "output format in the log file is not correct for \"${_test}\"."
	    exit 1
    fi
    eval "scancel ${job_id}"  # terminate this job
    cecho ${GOOD} "test_submit passed"
}


main(){
    parse_command "$1" # parse the command
    parse_options "$@"  # parse option with '-'
    quit_if_fail "No such command \"$1\""
    if [[ ${_command} = "test" ]]; then
        test_parse_command
	test_submit

  elif [[ ${_command} = "submit" && ${hold} -eq 0 ]]; then
    # parse_options "$@"  # parse option with '-'
	  local _message; local case_dir
  	if [[ -e "${job_file}" ]]; then
  		# for this to work, the job_file need to be put in the case folder
  		_message=$(sbatch ${job_file})
  		# get job_id
      		job_id=$(echo "${_message}" | sed 's/Submitted\ batch\ job\ //')
  		# get case directory, be default it's the same as the prm file
  		case_dir=$(dirname "${job_file}")
  		case_dir=$(fix_route "${case_dir}")  # get a full route
  	else
  		_message=$(submit)  # submit job
  		# get job_id
      		job_id=$(echo "${_message}" | sed 's/Submitted\ batch\ job\ //')
  		# get case directory, be default it's the same as the prm file
  		case_dir=$(dirname "${filename}")
  		case_dir=$(fix_route "${case_dir}")  # get a full route
  	fi
  	# call write_log from utilities.sh
  	if [[ ${job_id} =~ ^[0-9]*$ && "${log_file}" != '' ]]; then
  		[[ -e "${log_file}" ]] || write_log_header "${log_file}"  # write header when create a new file
  		clean_log "${case_dir}" "${log_file}"  # clean older record of same case
  		write_log "${case_dir}" "${job_id}" "${log_file}"
  	fi
  	# output the message to be backwork compatible
  	echo "${_message}"
  	# bind this with aspect_lib.sh to pullout machine time
  	local sleep_duration
  	[[ -n ${float} ]] && sleep_duration="${float}" || sleep_duration=1
  	if [[ -n ${log_file_time} ]]; then
  		local log_file_time_dir=$(dirname "${log_file_time}")
  		[[ -d ${log_file_time_dir} ]] || mkdir "${log_file_time_dir}"
          	eval "nohup ${dir}/aspect_lib.sh foo keep_write_time_log ${case_dir} ${job_id} ${log_file_time} -f ${sleep_duration}>/dev/null 2>&1 &"
  		return 0
  	fi
    
  elif [[ ${_command} = "submit" && ${hold} -eq 1 ]]; then
    # this is different from hold = 0, in that 'hold = 1' first write to a queuing list
    # and then handle the list accordingly
    echo "hold instead of submit"
	  # get job_id
	  local _message=$(submit)  # submit job
	  # get case directory, be default it's the same as the prm file
	  local case_dir=$(dirname "${filename}")
	  case_dir=$(fix_route "${case_dir}")  # get a full route
	  # output the message to be backwork compatible
	  echo "${_message}"

    elif [[ ${_command} = "remote_test" ]]; then
	# test submit to cluster
        local server_info="$2"  # user@server
        shift
        if ! [[ ${server_info} =~ .*\@.* ]]; then
            # check format
            cecho ${BAD} "with 'remote' command, '\$2' needs to be 'user@server'"
        fi
        # submit job
        # future, drag down results and compare
        # future: reset the scheme of output characters on server
        ssh ${server_info} << EOF
    	    eval "slurm.sh test"
EOF
    else
        # command error is already catched
        echo "foo"
    fi
}


if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
	main $@
fi
