#!/bin/bash
# case manager
# Usage:
#   ./aspect_lib.sh + command + options
# future: use a file to compile remote address

dir="$( cd "$( dirname "${BASH_SOURCE[0]}"  )" >/dev/null 2>&1 && pwd  )"

source "${dir}/utilities.sh"

################################################################################
# parse parameters from command line
# Inputs:
#   $1: options
#        formate of options should be "-a val1 --b=valb ..."
parse_options(){

    # parse options
    while [ -n "$1" ]; do
      param="$1"
      case $param in
        -h|--help)
          usage  # help information
          exit 0
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
        # float value
        #####################################
        -ex)
          shift
          extention="${1}"
        ;;
        -ex=*|--extension=*)
          extension="${param#*=}"
        ;;
        #####################################
        # list
        #####################################
        -l)
          shift
          vlist=()
          while [[ true ]]; do
            [[ -z "$1" ]] && { cecho ${BAD} "${FUNCNAME[0]}: no value given for list"; exit 1; }
            vlist+=("$1")
            [[ -z "$2" || "$2" = -* ]] && break || shift
          done
        ;;
      esac
      shift
    done

    # check values
    [[ -z ${bool} || ${bool} = "true" || ${bool} = "false" ]] || { cecho ${BAD} "${FUNCNAME[0]}: bool value must be true or false"; exit 1; }
    [[ -z ${float} || ${float} =~ ^[0-9\.]+$ ]] || { cecho ${BAD} "${FUNCNAME[0]}: entry for \${float} must be a float value"; exit 1; }
}

################################################################################
# help message
usage()
{
    printf "\
Submit a job to cluster with a slurm system

Usage:
    ./aspect_lib.sh [project] [command] [server_info] [options]

Commands:
    install     Install on local and server
        example usage:
            aspect_lib.sh TwoDSubduction install lochy@peloton.cse.ucdavis.edu
    
    create      create a case under project
        example usage:
            aspect_lib.sh TwoDSubduction create
        
    create_group    create a group of cases under project
        example usage:
            aspect_lib.sh TwoDSubduction create_group

    submit      submit a case under project to server
        example usage:
            aspect_lib.sh TwoDSubduction submit ./foo lochy@peloton.cse.ucdavis.edu
        
    submit_group submit cases within a group under project to server
        example usage:
            aspect_lib.sh TwoDSubduction submit_group ./foo_group lochy@peloton.cse.ucdavis.edu
    
    create_submit   create and then submit a case under project to server
        if a \$4 is given as log file, this will append slurm information to this log file on server side
        example usage:
           aspect_lib.sh TwoDSubduction create_submit lochy@peloton.cse.ucdavis.edu .output/job.log
    
    create_submit_group create and then submit a group under project to server
        if a \$4 is given as log file, this will append slurm information to this log file on server side
        example usage:
           aspect_lib.sh TwoDSubduction create_submit_group lochy@peloton.cse.ucdavis.edu .output/job.log

    translate_visit     translate visit scripts
        
    plot_visit_case     use visit to plot for a case, with saved scripts
        what this commend does is that it first take the saved scripts under 'visit_scrits',
        then it translate those scripts with parameters defined in visit_keys_values, and keep the result in 'visit_scripts_temp'
        At last, it runs visity to plot those translated scripts
        example command line:
            ./aspect_lib.sh TwoDSubduction plot_visit_case \$TwoDSubduction_DIR/isosurf_global2/isosurfULV3.000e+01testS12
        with plot(i.e. translate only) so that we could run in gui later:
            ./aspect_lib.sh TwoDSubduction plot_visit_case \$TwoDSubduction_DIR/isosurf_global2/isosurfULV3.000e+01testS12 -b false
        
    parse_solver_output     parse solver information from stdout file
        This commends extract newton solver output from a stdout output from aspect(e.g. 'task.stdout') and save results in 'solver_output' file
        This file could then be used to plot.
        example command line:
            ./aspect_lib.sh TwoDSubduction parse_solver_output \$TwoDSubduction_DIR/isosurf_global2/isosurfULV3.000e+01testS12/task.stdout ./solver_output
        only output first 20 steps:
            ./aspect_lib.sh TwoDSubduction parse_solver_output \$TwoDSubduction_DIR/isosurf_global2/isosurfULV3.000e+01testS12/task.stdout ./solver_output -l 0 1 20
        
    parse_case_solver_output    parse solver information from stdout file by giving a case directory
        Like the previous one. Only this one looks up file for you in a case
        the .stdout file must be placed under case directory,
        and the output file 'solver_output' goes into the 'output' directory
        example command line:
            ./aspect_lib.sh TwoDSubduction parse_case_solver_output \$TwoDSubduction_DIR/isosurf_global2/isosurfULV3.000e+01testS12
        only output first 20 steps:
            ./aspect_lib.sh TwoDSubduction parse_case_solver_output \$TwoDSubduction_DIR/isosurf_global2/isosurfULV3.000e+01testS12 -l 0 1 20
        
    write_time_log      write time and machine time output to a file
        Note that for this command, \$1 (i.e. name of project) is not needed
        example command line:
            ./aspect_lib.sh foo write_time_log /home/lochy/ASPECT_PROJECT/TwoDSubduction/isosurf_global2/isosurfULV3.000e+01testS13\
 2537585 /home/lochy/ASPECT_PROJECT/TwoDSubduction/isosurf_global2/isosurfULV3.000e+01testS13/output/machine_time
        
    keep_write_time_log     write time and machine time output to a file
        example command line:
            nohup ./aspect_lib.sh foo keep_write_time_log /home/lochy/ASPECT_PROJECT/TwoDSubduction/isosurf_global2/isosurfULV3.000e+01testS13\
 2537585 /home/lochy/ASPECT_PROJECT/TwoDSubduction/isosurf_global2/isosurfULV3.000e+01testS13/output/machine_time &
	# next, an example with sleep duration specified to 0.5hr
        # nohup ./aspect_lib.sh foo keep_write_time_log /home/lochy/ASPECT_PROJECT/TwoDSubduction/isosurf_global2/isosurfULV3.000e+01testS13\
        # 2537585 /home/lochy/ASPECT_PROJECT/TwoDSubduction/isosurf_global2/isosurfULV3.000e+01testS13/output/machine_time -f 0.5 &
        
    bash_post_process   do post process project-wise, handling only the bash part
        example command line:
            ./aspect_lib.sh TwoDSubduction bash_post_process
        
    post_process    do post process project-wise, handling both the bash and the python part
        example command line:
            ./aspect_lib.sh TwoDSubduction post_process
    
    build       build a project in aspect
        usage of this is to bind up source code and plugins
        example command line:
           local build:
               ./aspect_lib.sh TwoDSubduction build
               ./aspect_lib.sh TwoDSubduction build debug
               ./aspect_lib.sh TwoDSubduction build release
        server build(add a server_info):
            example command lines:
               ./aspect_lib.sh TwoDSubduction build lochy@peloton.cse.ucdavis.edu
               ./aspect_lib.sh TwoDSubduction build lochy@peloton.cse.ucdavis.edu debug
               ./aspect_lib.sh TwoDSubduction build lochy@peloton.cse.ucdavis.edu release
        
    test    run tests
            example command line:
                local test:
                    ./aspect_lib.sh TwoDSubduction test
            server test:
                    ./aspect_lib.sh TwoDSubduction test lochy@peloton.cse.ucdavis.edu

Options:
    -h --help       Help message
    --bool -b       A bool value that is either 'true' or 'false'
    
    -l              a lisl of value
                    for example:
                        -l 1.0 2.0 3.0
"
}



create_case(){
    # create a case locally
    local py_script="$1"
    local local_root="$2"
    eval "python -m ${py_script} create -j config_case.json >.temp 2>&1"  # debug
    [[ $? -eq 1 ]] && { cecho ${BAD} "${py_script} failed"; exit 1; }
    # get case name
    _info=$(cat ".temp")
    case_name=$(echo "${_info}" | sed -n '2'p)
    # assertion
    local case_dir="${local_root}/${case_name}"
    local case_prm="${case_dir}/case.prm"
    [[ -d ${case_dir} && -e ${case_prm} ]] || { cecho ${BAD} "Case generation failed"; exit 1; }
    cecho ${GOOD} "${_info}"
}


create_group(){
    # create a group of case locally
    local py_script="$1"
    local local_root="$2"
    eval "python -m ${py_script} create_group -j config_group.json 2>&1 > .temp"
    [[ $? -eq 1 ]] && { cecho ${BAD} "${py_script} failed"; exit 1; }
    # get case names
    _info=$(cat ".temp")
    local group_name=$(echo "${_info}" | sed -n '2'p)
    case_names=()
    while read -r line ; do
        case_names+=("${line}")
    done <<<  "$(cat ".temp" | sed -n '1,2!'p)"
    group_dir="${local_root}/${group_name}"
    create_group_case_dirs=()
    for case_name in "${case_names[@]}"; do
        local case_dir="${group_dir}/${case_name}"
        local case_prm="${case_dir}/case.prm"
        [[ -d ${case_dir} && -e ${case_prm} ]] || { cecho ${BAD} "Creating Group: Case generation failed"; exit 1; }
        create_group_case_dirs+=("${case_dir}")
    done
    cecho ${GOOD} "${_info}"
}


submit(){
    # future parse from json file
    local case_dir="$1"
    local case_name=$(basename "${case_dir}")
    local romote_case_dir="$2"
    local server_info="$3"
    local flag=''  # a vacant flag for adding optional parameters
    local case_prm="${case_dir}/case.prm"
    local remote_case_prm="${remote_case_dir}/case.prm"
    # output machine time output
    local remote_time_file="${remote_case_dir}/output/machine_time"
    flag="${flag} -lt ${remote_time_file}"

    # get configuration from a file
    local node=1  # backward compatible
    total_tasks=$(sed -n '1'p "slurm_config")
    time_by_hour=$(sed -n '2'p "slurm_config")
    partition=$(sed -n '3'p "slurm_config")
    nodes=$(sed -n '4'p "slurm_config")

    # scp to remote
    local remote_target=$(dirname "${remote_case_dir}")
    eval "${RSYNC} -r ${case_dir} ${server_info}:${remote_target}/"

    # check file arrival
    local status_
    while [[ true ]]; do
        ssh ${server_info} << EOF > '.temp'
            eval "[[ -e ${remote_case_prm} ]] && echo \"0\" || echo \"1\""
EOF
        status_=$(cat '.temp'| sed -n '$'p)
        ((status_==0)) && break || { cecho ${WARN} "Files haven't arrived yet, sleep for 2s"; sleep 2s; }
    done

    # add an optional log file
    [[ "$4" != '' ]] && flag="${flag} -l $4"  # add -l log_file to flag, if $4 given
    # submit using slurm.sh,
    # determine if there is a valid job id, future
    # also add -P option for project name
    ssh ${server_info} << EOF > '.temp'
        eval "slurm.sh -N ${nodes} -n ${total_tasks} -t ${time_by_hour} -p ${partition} -P ${project} ${remote_case_prm} ${flag}"
EOF
    # get job_id
    local _info=$(cat '.temp'| sed -n '$'p)
    local job_id=$(echo "${_info}" | sed 's/Submitted\ batch\ job\ //')
    if ! [[ ${job_id} != '' && ${job_id} =~ ^[0-9]*$  ]]; then
        cecho ${BAD} "submit case: ${case_name} failed"
        return 1
    else
        cecho ${GOOD} "submit case: ${case_name} succeeded, job id: ${job_id}"
        echo "${job_id}" > ".temp"  # use .temp to transfer information
        return 0
    fi
}


################################################################################
# install
install(){
    local project="$1"
    local server_info="$2"

    # new folder
    local project_dir="${ASPECT_PROJECT_DIR}/${project}"
    [[ -d "${project_dir}" ]]  || mkdir "${project_dir}"

    # on server side
    get_remote_environment "${server_info}" "ASPECT_PROJECT_DIR"
    local remote_project_dir="${return_value}/${project}"
    ssh ${server_info} << EOF
        eval "[[ -d \"${remote_project_dir}\" ]]  || mkdir \"${remote_project_dir}\" "
EOF

    # set alias, add a line every time it executes, future: fix this bug
    echo "export ${project}_DIR=\"${project_dir}\"" >> "${dir}/env/enable.sh"
    echo "export ${project}_DIR=\"${remote_project_dir}\"" >> "${dir}/env/enable_peloton.sh";

    # new mkdocs project
    previous=$(pwd)
    cd "${project_dir}"
    if ! [[ -d "mkdocs_project" ]]; then
        eval "mkdocs new mkdocs_project"
        yml_file="${project_dir}/mkdocs_project/mkdocs.yml"  # make a .yml file
        echo "site_name: ${project}" > "${yml_file}"
        echo "nav:" >> "${yml_file}"
        echo "    - Home: index.md" >> "${yml_file}"
        echo "theme: readthedocs" >> "${yml_file}"
    fi
    cd "${previous}"
}

################################################################################
# copy visit color table from ScientificColourMaps6
# Inputs:
#   $1: ScientificColourMap directory
copy_visit_color_table(){
    local visit_conf_dir="${HOME}/.visit"
    [[ -d ${visit_conf_dir} ]] || cecho ${BAD} "${FUNCNAME[0]}: ${visit_conf_dir} doesn't exist"

    # copy file
    for _dir in "$1"/*; do
        if [[ -d ${_dir} ]]; then
            for _file in "${_dir}"/*; do
                if [[ ${_file} =~ ".ct" ]]; then 
                    echo "copy file: ${_file}"
                    # get base name of file
                    _base=$(basename "${_file}")
                    # copy file with prefix 'SCM'
                    eval "cp ${_file} ${visit_conf_dir}/SCM_${_base}"
                fi
            done
        fi
    done
}

################################################################################
# Translate a visit script
# Inputs:
#    filein: name of the script
#    keys: keys to translate
#    values: values to translate
tranlate_visit_script(){
    # check variable
    # check_variable 'keys'
    # check_variable 'values'
    # check_variable 'filein'
    # check_variable 'fileout'

    # read file
    contents=$(cat ${filein})
    
    # do substutions
    local i=0
    for key in ${keys[@]}; do
        value="${values[i]}"
        contents=${contents//"$key"/"${value}"}  # substitute key with value
        ((i++))
    done

    # output
    echo "${contents}" > "${fileout}"
}


################################################################################
# Translate a visit script, run it and generate plots
# Inputs:
#    fileins: list name of the script
#    file_keys_values: file that holds keys and values to substitute
plot_visit_scripts(){
    # future
    echo '0'
}
        

################################################################################
# Run tests
# Inputs:
run_tests(){
    current_dir=$(pwd)

    # run python tests
    cd ${ASPECT_LAB_DIR}
    # eval "python -m pytest tests -v --cov"

    cd ${current_dir}

    # run bash tests
    bash_tests_dir="${ASPECT_LAB_DIR}/bash_tests"
    for file in ${bash_tests_dir}/* ; do
        [[ ${file} =~ /test.*\.sh$ && -x ${file} ]] && eval "${file} ${project} ${server_info}"
    done
}


################################################################################
# Generate visit plots for a single case
# Inputs
#    case_dir: case directory
#    bool: whether to plot
#       if this option is 'false', this function will just translate the scripts without plotting
plot_visit_case(){
    # check folders
    [ -d "${case_dir}" ] || { cecho ${BAD} "plot_visit_case: Case folder - ${case_dir} doesn't exist"; exit 1; }
    data_sub_dir="${case_dir}/output"
    [ -d "${data_sub_dir}" ] || { cecho ${BAD} "plot_visit_case: Data folder - ${data_sub_dir} doesn't exist"; exit 1; }
    # dir for transfered visit scripts
    local visit_temp_dir="${dir}/visit_scripts_temp"
    [ -d "${visit_temp_dir}" ] || mkdir "${visit_temp_dir}" ]
    # dir for image output
    local img_dir="${case_dir}/img"
    [ -d "${img_dir}" ] || mkdir "${img_dir}" ]

    # get a list of scripts to plot
    visit_script_bases=("slab.py")
    visit_script_dir="${dir}/visit_scripts/${project}"
        
    # call python module to generate visit_keys_values file
    eval "python -m shilofue.${project} visit_options -i ${case_dir} -j post_process.json"
    
    # get keys and values
    keys_values_file="${dir}/visit_keys_values"
    [ -r "${keys_values_file}" ] || { cecho ${BAD} "plot_visit_case: Files containing keys and values - ${keys_values_file} cannot be read"; exit 1; }
    read_keys_values "visit_keys_values"
    
    # do substitution and run
    for visit_script_base in ${visit_script_bases[@]}; do
        filein="${visit_script_dir}/${visit_script_base}"
        fileout="${visit_temp_dir}/${visit_script_base}"

        # translate script
        tranlate_visit_script

        # run
        [[ -z ${bool} || ${bool} = "true" ]] && echo "exit()" | eval "visit -nowin -cli -s ${fileout}"
    done
}


################################################################################
# outputs from solver
# Inputs:
#   filein: file to read from
#   fileout: file to output to
#   vlist: [start step, interval, end step].
#       If this is none, take all steps   
parse_solver_output(){
    # parse in options
    # assert the list of value
    local start; local interval; local end;
    if [[ -n ${vlist} ]]; then
        if [[ ${#vlist[@]} -eq 3 ]]; then
            start=${vlist[0]}
            interval=${vlist[1]}
            end=${vlist[2]}
        else
            cecho ${BAD} "${FUNCNAME[0]}: If vlist exists, it must be a list of length of 3"; exit 1;
        fi
    else
        start=0
        interval=1
        # set a max number to avoid dead loop
        end=1000000
    fi

    # loop for timesteps
    timestep=${start}
    while ((timestep<end)); do
        parse_solver_output_timestep
        
        # check if this is successful
        # we take for granted that any non-zero state
        # indicates that we reach the EOF
        [[ $? -eq 0 ]] || break

        ((timestep+=interval))
    done
    return 0
}


################################################################################
# outputs from solver by giving a case directory
# Before converting result, we check if there is already results presented and we
# check the relative time of that file to the new output file.
# Inputs:
#   case_dir: directory to parse from
#   vlist: [start step, interval, end step].
#       If this is none, take all steps   
#   update: if we update a pre-existing file
#   $1: output file name, default is 'solver_output'
# Returns:
#   0: normal
#   -1: no operation needed
parse_case_solver_output()
{
    # unset
    unset filein
    
    # find newest .stdout file
    local temp; local id; local filename
    local idin=0
    for file_ in "${case_dir}"/*"stdout"; do
        # fix bug
        [[ -e "${file_}" ]] || continue
        # get id
        filename=$(basename "${file_}")
        temp=${filename#*"-"}
        id=${temp%%".stdout"}
        ((id>idin)) && { filein="${file_}"; ((idin=id)); }
    done
    [[ -z "${filein}" ]] && { cecho ${WARN} "${FUNCNAME[0]}: fail to get file in dir ${case_dir}"; return 1; }

    # check output dir 
    local output_dir="${case_dir}/output"
    [[ -d ${output_dir} ]] || mkdir "${output_dir}"

    # check results existence and compare time
    local fileout_base
    [[ -n $1 ]] && fileout_base="$1" || fileout_base="solver_output"
    fileout="${output_dir}/${fileout_base}"
    if [[ -z ${update} || ${update} = "False" ]]; then
        [[ -e "${fileout}" && "${fileout}" -nt ${filein} ]] && return -1
    fi

    # call parse_solver_output function
    parse_solver_output
    return 0
}


################################################################################
# outputs from solver for a timestep
# Inputs:
#   filein: file to read from
#   fileout: file to output to
#   timestep(int): time step
# Returns:
#   0
#   1: reach end of the file
#   2: no such outputs presented
parse_solver_output_timestep(){
    # read input 
    [[ -z ${filein} ]] && { cecho ${BAD} "${FUNCNAME[0]}: filein must be given"; exit 1; }
    [[ -z ${fileout} ]] && { cecho ${BAD} "${FUNCNAME[0]}: fileout must be given"; exit 1; }
    [[ -z ${timestep} ]] && { cecho ${BAD} "${FUNCNAME[0]}: timestep must be given"; exit 1; }
    
    # parse content from stdout file 
    parse_stdout1 "${filein}" "${timestep}"
    [[ $? -eq 0 ]] || { echo "${FUNCNAME[0]}: timestep ${timestep} seems to hit end of the file ${filein}"; return 1; }

    # parse one time step
    local solver_outputs=()
    local output=''
    local start=0
    parse_block_outputs "${content}" "Rebuilding Stokes"

    # get useful information
    # number of nonlinear solver
    local nnl="${#block_outputs[@]}"
    # Relative nonlinear residual (total Newton system)
    local rnrs=()
    # norm of the rhs
    local nors=()
    # newton_derivative_scaling_factor
    local ndsfs=()
    local temp; local temp1
    for block_output in "${block_outputs[@]}"; do
        # get rnr
        parse_output_value "${block_output}" "Relative nonlinear" "residual"
        local line_="${value}"

        parse_output_value "${line_}" "nonlinear iteration" ":" ","
        [[ -z ${value} ]] && { cecho ${WARN} "${FUNCNAME[0]}: ${filein} doens't have solver outputs"; return 2; } 
        rnrs+=("${value}")
        # get nors
        parse_output_value "${line_}" "norm of the rhs" ":" ","
        nors+=("${value}")
        # get ndrsf
        parse_output_value "${line_}" "newton_derivative_scaling_factor" ":" ","
        # if value is not present, append by 0
        [[ -n ${value} ]] && ndsfs+=("${value}") || ndsfs+=("0")
    done

    # output header if file doesn't exist
    if ! [[ -e ${fileout} ]]; then 
        printf "# 1: Time step number\n" >> "${fileout}"
        printf "# 2: Index of nonlinear iteration\n" >> "${fileout}"
        printf "# 3: Relative nonlinear residual\n" >> "${fileout}"
        printf "# 4: Norms of the rhs\n" >> "${fileout}"
        printf "# 5: Newton Derivative Scaling Factor\n" >> "${fileout}"
    fi

    # get length of array
    local length=${#rnrs[@]}
 
    # output
    local i=0
    while ((i<length)); do
        # output to file 
        printf "%-15s %-15s %-15s %-15s %s\n" "${timestep}" "${i}" "${rnrs[$i]}" "${nors[$i]}" "${ndsfs[$i]}" >> "${fileout}"
        ((i++))
    done
    
    return 0
}


################################################################################
# future
# build a project in aspect
# usage of this is to bind up source code and plugins
# Inputs:
#   project: name of the project
#   $1: release or debug, default is debug following aspect's routine
build_aspect_project(){
    build_dir="${ASPECT_SOURCE_DIR}/build_${project}"
    [[ -d ${build_dir} ]] || mkdir ${build_dir}
    local mode
    if [[ -n $1 ]]; then
        [[ $1="debug" || $1="release" ]] || { cecho ${BAD} "${FUNCNAME[0]}: mode is either \'debug\' or \'release\'"; exit 1; }
        mode=$1
    else
        mode="debug"
    fi

    # get the project json file
    json="${ASPECT_LAB_DIR}/files/${project}/project.json"
    [[ -e ${json} ]] || cecho ${WARN} "${FUNCNAME[0]}: json file of project(i.e. ${json}) doesn't exist"

    # get the list of plugins
    plugins=("prescribe_field" "subduction_temperature2d" "slab2d_statistics")

    # build
    local current_dir=$(pwd)
    # Here we pick nproc - 1, this make sure that we don't use up all resources. 
    # But this will cause problem when nproc = 1
    local nproc=$(($(nproc)-1))
    cd ${build_dir}
    # build source code
    eval "cmake .."
    quit_if_fail "${FUNCNAME[0]}: cmake inside ${build_dir} failed"
    eval "make ${mode}"
    quit_if_fail "${FUNCNAME[0]}: \"make ${mode}\" inside ${build_dir} failed"
    eval "make -j ${nproc}"
    quit_if_fail "${FUNCNAME[0]}: make inside ${build_dir} failed"

    # build plugins
    plugins_dir="${ASPECT_SOURCE_DIR}/plugins"
    for plugin in ${plugins[@]}; do
        build_aspect_plugin "${plugin}"
    done
}

################################################################################
# build a plugin with source code in aspect
# usage of this is to bind up source code and plugins
# Inputs:
#   project: name of the project
#   $1: name of plugin
build_aspect_plugin(){
    local plugin="$1"
    build_dir="${ASPECT_SOURCE_DIR}/build_${project}"
    [[ -d ${build_dir} ]] || mkdir ${build_dir}
    
    # copy plugins
    plugins_dir="${ASPECT_SOURCE_DIR}/plugins"
    # check plugin existence
    plugin_dir="${plugins_dir}/${plugin}"
    [[ -d ${plugin_dir} ]] || { cecho ${BAD} "${FUNCNAME[0]}: plugin(i.e. ${plugin_dir}) doesn't exist"; exit 1; }
    # remove old ones
    plugin_to_dir="${build_dir}/${plugin}"
    [[ -d ${plugin_to_dir} ]] && rm -r ${plugin_to_dir}
    # copy new ones
    eval "cp -r ${plugin_dir} ${build_dir}/"
    cecho ${GOOD} "${FUNCNAME[0]}: copyied plugin(i.e. ${plugin})"

    # build 
    cd ${plugin_to_dir}
    # remove cache before compling
    [[ -e "${plugin_to_dir}/CMakeCache.txt" ]] && eval "rm ${plugin_to_dir}/CMakeCache.txt"
    eval "cmake -DAspect_DIR=${build_dir}"
    quit_if_fail "${FUNCNAME[0]}: cmake inside ${plugin_to_dir} failed"
    eval "make"
    quit_if_fail "${FUNCNAME[0]}: make inside ${plugin_to_dir} failed"
}


################################################################################
# post-process of a case via bash
#   Inputs:
#   case_dir: directory of case
bash_post_process_case(){
    # handle newton solver output
    # future: add option
    vlist=(0 1 20)
    parse_case_solver_output
    return 0
}


################################################################################
# post-process of a project via bash
# Inputs:
#   local_root: directory of project
# Global variables:
#   case_dir(dir): this is changed here
bash_post_process_project(){
    # search for groups and cases
    # return values are group_dirs and case_dirs
    search_for_groups_cases "${local_root}"

    local group_dir

    # deal solver output
    for case_dir in "${case_dirs[@]}"; do
        bash_post_process_case
    done

    # read for directories to plot with visit
    # it is possible to write this part into a function
    local filein="${dir}/post_process.json"

    local keys=("visit")
    # check for visit options
    read_json_file
    if [[ -n "${value}" ]]; then
        keys=("dirs")
        local is_array='true'
        read_json_file
    
        # get the dir to plot visit
        local visit_dirs=()
        if [[ $value =~ "active" ]]; then
            # future
            echo 0
        else
            IFS=" "; dirs=(${value})
            local source_dir; local dir_
            for dir_ in "${dirs[@]}"; do
                source_dir="${local_root}/${dir_}"
                search_for_groups_cases "${source_dir}"
                visit_dirs+=("${case_dirs[@]}")
            done
        fi

        # plot visit cases
        for case_dir in "${visit_dirs[@]}"; do
            plot_visit_case
        done
    fi
    
    return 0
}

################################################################################
# Update the mkdocs and public on github
# Inputs:
#   local_root: directory of project
process_docs(){
    # update mkdocs
    echo "python -m shilofue.${project} update_docs -o ${local_root} -j post_process.json"
    eval "python -m shilofue.${project} update_docs -o ${local_root} -j post_process.json"

    # submit to github
    mkdocs_dir="${local_root}/mkdocs_project"
    local previous_=$(pwd)
    cd "${mkdocs_dir}"; eval "mkdocs gh-deploy"; cd "${previous_}"
}


################################################################################
# post-projecss of a project via bash and python
# Inputs:
#   py_script: python script for this project
#   local_root: directory of project
post_process_project(){
    # call bash scripts to do post process
    bash_post_process_project

    # call python post process
    eval "python -m ${py_script} update -j ${dir}/post_process.json -o ${local_root} -j post_process.json"

    # update mkdocs
    process_docs
}

################################################################################
#   affinty test on server
#   name of tests are P*B#, * could be 16, 32, 64, 128
#   # could be 1 or 2, this is wheter the binded option is used.
do_affinity_test(){
    source_dir="${ASPECT_LAB_DIR}/files/${project}/affinity_test"
    [[ -d ${source_dir} ]] || cecho $BAD "source_dir doesn't exist"
    # todo
    local project_dir="${ASPECT_PROJECT_DIR}/${project}"
    # get remote variables
    get_remote_environment "${server_info}" "${project}_DIR"
    local remote_root=${return_value}
    get_remote_environment "${server_info}" "ASPECT_LAB_DIR"
    local remote_lib_dir=${return_value}
    
    if [[ "${server_info}" =~ "peloton" ]]; then
        target_dir="${project_dir}/peloton_affinity_test"
    else
        target_dir="${project_dir}/affinity_test"
    fi
    
    [[ -d ${target_dir} ]] && rm -r "${target_dir}"
    mkdir "${target_dir}"
    remote_target_dir=${target_dir/"${local_root}"/"${remote_root}"} # substitution
    ssh ${server_info} << EOF > '.temp'
        eval "[[ -d ${remote_target_dir} ]] && rm -r ${remote_target_dir}"
        eval "mkdir ${remote_target_dir}"
EOF
    
    # make case P16
    local remote_case_dir
    local case_dir
    local number_of_nodes=(1 1 1 1 1 1 1 2 1)
    local number_of_cores=(2 4 4 8 16 32 64 64 64)
    local bind_to_cores=(0 0 1 0 0 0 0 0 0)
    local bind_to_threads=(0 0 0 0 0 0 0 0 1)
    # todo
    local _i=0
    while ((_i<${#number_of_nodes[@]})); do
        _n=${number_of_cores[_i]}
        _N=${number_of_nodes[_i]}
        _bc=${bind_to_cores[_i]}
        _bt=${bind_to_threads[_i]}

        # deal with local files 
        case_dir="${target_dir}/N${_N}n${_n}"
        ((${_bc}==1)) && case_dir="${case_dir}bc"
        ((${_bt}==1)) && case_dir="${case_dir}bt"
        [[ -d ${case_dir} ]] && rm -r "${case_dir}"  # remove previous results
        mkdir "${case_dir}"
        eval "cp ${source_dir}/* ${case_dir}"

        # scp to remote
        remote_case_dir=${case_dir/"${local_root}"/"${remote_root}"} # substitution
        remote_case_prm="${remote_case_dir}/case.prm"
        remote_out_dir="${remote_case_dir}/output"
        local remote_target=$(dirname "${remote_case_dir}")
        eval "${RSYNC} -r ${case_dir} ${server_info}:${remote_target}/"
    
        local status_
        while [[ true ]]; do
            ssh ${server_info} << EOF > '.temp'
                eval "[[ -e ${remote_case_prm} ]] && echo \"0\" || echo \"1\""
EOF
            status_=$(cat '.temp'| sed -n '$'p)
            ((status_==0)) && break || { cecho ${WARN} "Files haven't arrived yet, sleep for 2s"; sleep 2s; }
        done
    
        # generate job.sh file
        local addition=""
        local flag="--hold"
        ((${_bc}==1)) && flag="${flag} --bind_to=\"cores\""
        ((${_bt}==1)) && flag="${flag} --bind_to=\"threads\""
        ssh ${server_info} << EOF > ".temp"
            eval "[[ -d ${remote_out_dir} ]] || mkdir ${remote_out_dir} "
            eval "slurm.sh -N ${_N} -n ${_n} -t 24 ${addition} -P ${project} ${flag} ${remote_case_prm}"
EOF
        ((_i++))
    done
}

main(){
    # parameter list, future
    local project="$1"
    local local_root=$(eval "echo \${${project}_DIR}")
    local py_script="shilofue.${project}"

    # parse commend
    _command="$2"

    # parse options
    parse_options $@

    # check project
    [[ -d ${local_root} || ${_command} = 'install' || ${_command} = 'write_time_log' || ${_command} = 'keep_write_time_log' ]] || { cecho ${BAD} "Project ${project} is not included"; exit 1; }

    # execute
    if [[ ${_command} = 'install' ]]; then
        # Install on local and server
        # example usage:
        #   aspect_lib.sh TwoDSubduction install lochy@peloton.cse.ucdavis.edu
        [[ "$#" -eq 3 ]] || { cecho ${BAD} "for install, server_info must be given"; exit 1; }
        set_server_info "$3"
        install "${project}" ${server_info}

    elif [[ ${_command} = "copy_visit_color_table" ]]; then
        # copy visit color file
        # example usage:
        #   ./aspect_lib.sh TwoDSubduction copy_visit_color_table /home/lochy/Desktop/ScientificColourMaps6/ScientificColourMaps6
        ScientificColourMap_dir="$3"
        copy_visit_color_table "${ScientificColourMap_dir}"

    elif [[ ${_command} = 'create' ]]; then
        # create a case under project
        # example usage:
        #   aspect_lib.sh TwoDSubduction create
        create_case "${py_script}" "${local_root}"

    elif [[ ${_command} = 'create_group' ]]; then
        # creat a group of cases under project
        # example usage:
        #   aspect_lib.sh TwoDSubduction create_group
        create_group "${py_script}" "${local_root}"

    elif [[ ${_command} = 'submit' ]]; then
        # submit a case under project to server
        # example usage:
        #   aspect_lib.sh TwoDSubduction submit ./foo lochy@peloton.cse.ucdavis.edu
        local case_name="$3"
        set_server_info "$4"
        local case_dir="${local_root}/${case_name}"
        # get remote case directory
        get_remote_environment "${server_info}" "${project}_DIR"
        local remote_root=${return_value}
        local remote_case_dir=${case_dir/"${local_root}"/"${remote_root}"} # substitution
        local log_file="$5"  # add an optional log_file
        if [[ "${log_file}" != '' ]]; then
            # if there is no $5 given, log file is ''
            log_file=$(fix_route "${log_file}")
            log_file=${log_file/"${local_root}"/"${remote_root}"} # substitution
        fi
        submit "${case_dir}" "${remote_case_dir}" "${server_info}" "${log_file}"
        quit_if_fail "aspect_lib.sh submit failed for case ${case_name}"

    elif [[ ${_command} = 'submit_group' ]]; then
        # submit cases within a group under project to server
        # example usage:
        #   aspect_lib.sh TwoDSubduction submit_group ./foo_group lochy@peloton.cse.ucdavis.edu
        local group_name="$3"
        set_server_info "$4"
        local group_dir="${local_root}/${group_name}"
        # get remote case directory
        get_remote_environment "${server_info}" "${project}_DIR"
        local remote_root=${return_value}
        local remote_group_dir=${group_dir/"${local_root}"/"${remote_root}"}
        ssh "${server_info}" eval "[[ -d ${remote_group_dir} ]] || mkdir ${remote_group_dir}"
        local log_file="$5"  # add an optional log_file, future, move this to global settings
        if [[ "${log_file}" != '' ]]; then
            # if there is no $5 given, log file is ''
            log_file=$(fix_route "${log_file}")
            log_file=${log_file/"${local_root}"/"${remote_root}"} # substitution
        fi
        # get a list of cases and submit
        local job_ids=""
        for case_dir in "${group_dir}/"*; do
            if [[ -d "${case_dir}" ]]; then
                # select directories
                local _files=$(ls "${case_dir}")
                if [[ "${_files[@]}" =~ 'stdout' ]]; then
                    continue
                fi
                if [[ "${_files[@]}" =~ 'case.prm' ]]; then
                    local remote_case_dir=${case_dir/"${local_root}"/"${remote_root}"}
                    # call submit functions
                    submit "${case_dir}" "${remote_case_dir}" "${server_info}" "${log_file}"
                    quit_if_fail "aspect_lib.sh submit group failed for case ${case_dir}"
                    local job_id=$(cat ".temp")  # get job id
                    job_ids="${job_ids} ${job_id}"
                fi
            fi
        done
        echo "${job_ids[@]}" > ".temp"
        return 0

    elif [[ ${_command} = 'create_submit' ]]; then
        # create and then submit a case under project to server
        # if a $4 is given as log file, this will append slurm information to this log file on server side
        # example usage:
        #   aspect_lib.sh TwoDSubduction create_submit lochy@peloton.cse.ucdavis.edu .output/job.log
        set_server_info "$3"
        local log_file="$4"  # optional log file
        ./aspect_lib.sh "${project}" 'create'
        [[ $? -eq 0 ]] || {  cecho ${BAD} "aspect_lib.sh create failed"; exit 1; }
        # get case name
        local _info=$(cat ".temp")
        local case_name=$(echo "${_info}" | sed -n '2'p)
        # submit to server
        ./aspect_lib.sh "${project}" 'submit' "${case_name}" "${server_info}" "${log_file}"
        [[ $? -eq 0 ]] || {  cecho ${BAD} "aspect_lib.sh submit failed"; exit 1; }

    elif [[ ${_command} = 'create_submit_group' ]]; then
        # create and then submit a group under project to server
        # if a $4 is given as log file, this will append slurm information to this log file on server side
        # example usage:
        #   aspect_lib.sh TwoDSubduction create_submit_group lochy@peloton.cse.ucdavis.edu .output/job.log
        set_server_info "$3"
        local log_file="$4"  # optional log file
        # ./aspect_lib.sh "${project}" 'create_group'
        create_group "${py_script}" "${local_root}"
        [[ $? -eq 0 ]] || {  cecho ${BAD} "aspect_lib.sh create failed"; exit 1; }
        # get group name
        # local _info=$(cat ".temp")
        # local group_name=$(echo "${_info}" | sed -n '2'p)
        # call self
        # ./aspect_lib.sh "${project}" 'submit_group' "${group_name}" "${server_info}" "${log_file}"
        # get remote case directory
        get_remote_environment "${server_info}" "${project}_DIR"
        local remote_root=${return_value}
        local remote_case_dir
        # fix log_file 
        if [[ "${log_file}" != '' ]]; then
            # if there is no $4 given, log file is ''
            log_file=$(fix_route "${log_file}")
            log_file=${log_file/"${local_root}"/"${remote_root}"} # substitution
        fi
        for case_dir in ${create_group_case_dirs[@]}; do
            remote_case_dir=${case_dir/"${local_root}"/"${remote_root}"} # substitution
            submit "${case_dir}" "${remote_case_dir}" "${server_info}" "${log_file}"
        done
        quit_if_fail "aspect_lib.sh submit_group failed"

    elif [[ ${_command} = 'terminate' ]]; then
        # future
        echo '0'

    elif [[ ${_command} = 'remove' ]]; then
        # future
        echo '0'

    elif [[ ${_command} = 'translate_visit' ]]; then
        # translate visit scripts
        filein="$3"
        filein_base=$(basename ${filein})
        fileout="${ASPECT_LAB_DIR}/visit_scripts_temp/${filein_base}"

        # get keys
        read_keys_values "${ASPECT_LAB_DIR}/visit_keys_values"

        # call function
        keys = ${keys[@]} 
        tranlate_visit_script
    
    elif [[ ${_command} = 'plot_visit_case' ]]; then
        # plot visit for a case
        # example command line:
        # ./aspect_lib.sh TwoDSubduction plot_visit_case $TwoDSubduction_DIR/isosurf_global2/isosurfULV3.000e+01testS12
        # no plot so that we could run in gui later:
        #   ./aspect_lib.sh TwoDSubduction plot_visit_case $TwoDSubduction_DIR/isosurf_global2/isosurfULV3.000e+01testS12 -b false
        case_dir="$3"
        [[ -d ${case_dir} ]] || { cecho ${BAD} "${FUNCNAME[0]}: case directory(i.e. ${case_dir}) doesn't exist"; exit 1; }

        # call function
        plot_visit_case

    elif [[ ${_command} = 'parse_solver_output' ]]; then
        # parse solver information from stdout file
        # This commends extract newton solver output from a stdout output from aspect(e.g. 'task.stdout') and save results in 'solver_output' file
        # This file could then be used to plot.
        # example command line:
        # ./aspect_lib.sh TwoDSubduction parse_solver_output $TwoDSubduction_DIR/isosurf_global2/isosurfULV3.000e+01testS12/task.stdout ./solver_output
        # only output first 20 steps:
        # ./aspect_lib.sh TwoDSubduction parse_solver_output $TwoDSubduction_DIR/isosurf_global2/isosurfULV3.000e+01testS12/task.stdout ./solver_output -l 0 1 20
        filein="$3"
        fileout="$4"
        
        # call function
        parse_solver_output
    
    elif [[ ${_command} = 'parse_case_solver_output' ]]; then
        # parse solver information from stdout file by giving a case directory
        # the .stdout file must be placed under this directory
        # and the output file 'solver_output' goes into the 'output' directory
        # example command line:
        # ./aspect_lib.sh TwoDSubduction parse_case_solver_output $TwoDSubduction_DIR/isosurf_global2/isosurfULV3.000e+01testS12
        # only output first 20 steps:
        # ./aspect_lib.sh TwoDSubduction parse_case_solver_output $TwoDSubduction_DIR/isosurf_global2/isosurfULV3.000e+01testS12 -l 0 1 20
        case_dir="$3"
        
        # call function
        # future: make this quieter
        parse_case_solver_output
    
    elif [[ ${_command} = 'plot_solver_step' ]]; then
        # plot solver output for specific step
        # example usage:
        #   ./aspect_lib.sh TwoDSubduction plot_solver_step /home/lochy/ASPECT_PROJECT/TwoDSubduction/non_linear19/non_linear_1e18_1MaULV3.000e+01testNST5.000e-05SBR5 -f 55
        # --extension=pdf
        case_dir="$3"

        # construct vlist based on step 
        vlist=("${float}" 1 "$((${float}+1))")
        echo "${vlist[@]}"  # debug

        # remove previous data file
        local odatafile="${case_dir}/output/solver_output_step"
        [[ -e ${odatafile} ]] && rm ${odatafile}
        
        # call function to parse output
        local update="False"
        parse_case_solver_output "solver_output_step"

        # add appendix
        local appendix=""
        [[ -n ${extension} ]] && appendix="${appendix} --ex ${extension}"

        # call python scripts to plot
        eval "python -m shilofue.TwoDSubduction plot_newton_solver_step -i ${case_dir}/output/solver_output_step -o ${case_dir}/img -s ${float} ${appendix}"

    elif [[ ${_command} = 'write_time_log' ]]; then
        # Note that for this command, \$1 (i.e. name of project) is not needed
        # write time and machine time output to a file
        # example command line:
        # ./aspect_lib.sh foo write_time_log /home/lochy/ASPECT_PROJECT/TwoDSubduction/isosurf_global2/isosurfULV3.000e+01testS13\
        # 2537585 /home/lochy/ASPECT_PROJECT/TwoDSubduction/isosurf_global2/isosurfULV3.000e+01testS13/output/machine_time
        [[ -n $3 && -d $3 ]] || { cecho ${BAD} "${FUNCNAME[0]}: write_time_log, \$3 must be a valid directory"; exit 1; }
        [[ -n $4 && $4=~^[0-9]+$ ]] || { cecho ${BAD} "${FUNCNAME[0]}: write_time_log, \$4 must be a valid job id"; exit 1; }
        [[ -n $5 ]] || { cecho ${BAD} "${FUNCNAME[0]}: write_time_log, \$5 must be a valid path of a file"; exit 1; }
        write_time_log $3 $4 $5
    
    
    elif [[ ${_command} = 'keep_write_time_log' ]]; then
        # write time and machine time output to a file
        # example command line:
        # nohup ./aspect_lib.sh foo keep_write_time_log /home/lochy/ASPECT_PROJECT/TwoDSubduction/isosurf_global2/isosurfULV3.000e+01testS13\
        # 2537585 /home/lochy/ASPECT_PROJECT/TwoDSubduction/isosurf_global2/isosurfULV3.000e+01testS13/output/machine_time &
	# next, an example with sleep duration specified to 0.5hr
        # nohup ./aspect_lib.sh foo keep_write_time_log /home/lochy/ASPECT_PROJECT/TwoDSubduction/isosurf_global2/isosurfULV3.000e+01testS13\
        # 2537585 /home/lochy/ASPECT_PROJECT/TwoDSubduction/isosurf_global2/isosurfULV3.000e+01testS13/output/machine_time -f 0.5 &
        [[ -n $3 && -d $3 ]] || { cecho ${BAD} "${FUNCNAME[0]}: write_time_log, \$3 must be a valid directory"; exit 1; }
        [[ -n $4 && $4=~^[0-9]+$ ]] || { cecho ${BAD} "${FUNCNAME[0]}: write_time_log, \$4 must be a valid job id"; exit 1; }
        [[ -n $5 ]] || { cecho ${BAD} "${FUNCNAME[0]}: write_time_log, \$5 must be a valid path of a file"; exit 1; }

	# get value of time interval(sleep duration)
	local sleep_duration
	[[ -n ${float} ]] && sleep_duration="${float}" || sleep_duration=1

        while true
        do
            write_time_log $3 $4 $5
            [[ $? -eq 0 ]] || { printf "${FUNCNAME[0]}: stop writing time log\n"; exit 0; }
            eval "sleep ${sleep_duration}h"
        done

    elif [[ ${_command} = 'bash_post_process' ]]; then
        # do post process project-wise, handling only the bash part
        # example command line:
        # ./aspect_lib.sh TwoDSubduction bash_post_process
        bash_post_process_project

    elif [[ ${_command} = 'process_docs' ]]; then
        # update the mkdocs and publish on github
        # example command line:
        #   ./aspect_lib.sh TwoDSubduction process_docs
        process_docs

    elif [[ ${_command} = 'post_process' ]]; then
        # do post process project-wise, handling both the bash and the python part
        # example command line:
        # ./aspect_lib.sh TwoDSubduction post_process
        post_process_project

    
    elif [[ ${_command} = 'build' ]]; then
        # build a project in aspect
        # usage of this is to bind up source code and plugins
        # example command line:
        #   local build:
        #       ./aspect_lib.sh TwoDSubduction build
        #       ./aspect_lib.sh TwoDSubduction build debug
        #       ./aspect_lib.sh TwoDSubduction build release
        build_aspect_project $3

    
    elif [[ ${_command} = 'build_plugin' ]]; then
        # build a the plugin with the main source in aspect
        # usage of this is to bind up source code and plugins
        # example command line:
        #   ./aspect_lib.sh TwoDSubduction build_plugin subduction_temperature2d
        build_aspect_plugin "$3"

    
    elif [[ ${_command} = 'build_remote' ]]; then
        #   server build(add a server_info):
        #   example command lines:
        #       ./aspect_lib.sh TwoDSubduction build_remote lochy@peloton.cse.ucdavis.edu
        #       ./aspect_lib.sh TwoDSubduction build_remote lochy@peloton.cse.ucdavis.edu debug
        #       ./aspect_lib.sh TwoDSubduction build_remote lochy@peloton.cse.ucdavis.edu release
        set_server_info "$3"
        ssh ${server_info} << EOF
            eval "\${ASPECT_LAB_DIR}/aspect_lib.sh ${project} build $4"
EOF

    elif [[ ${_command} = "affinity_test" ]]; then
        #  affinity test on server
        #  example command line 
        #       ./aspect_lib.sh TwoDSubduction affinity_test lochy@peloton.cse.ucdavis.edu
        # todo
        set_server_info "$3"

        do_affinity_test "${project}"

    elif [[ ${_command} = 'test' ]]; then
        # run tests
        # example command line:
        #   local test:
        #       ./aspect_lib.sh TwoDSubduction test
        #   server test:
        #       ./aspect_lib.sh TwoDSubduction test lochy@peloton.cse.ucdavis.edu
        # get server info
        set_server_info "$3"

        # call scripts in bash_tests folder
        run_tests
    
    else
        cecho ${BAD} "Bad commend: ${_command}"
    fi
    return 0
}

main $@
