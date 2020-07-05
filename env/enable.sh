export ASPECT_LAB_DIR="$HOME/ASPECT_PROJECT/aspectLib"
export TwoDSubduction_DIR="$HOME/ASPECT_PROJECT/TwoDSubduction"
alias project_update="python -m shilofue.TwoDSubduction update -o /home/lochy/ASPECT_PROJECT/TwoDSubduction"
alias plt_connect='ssh -X lochy@peloton.cse.ucdavis.edu'
alias plt_update='process.sh update_from_server .output/job.log lochy@peloton.cse.ucdavis.edu'
alias plt_download='process.sh update_outputs_from_server .output/job.log lochy@peloton.cse.ucdavis.edu'
alias plt_submit='aspect_lib.sh TwoDSubduction create_submit lochy@peloton.cse.ucdavis.edu ./output/job.log'
alias plt_submit_group='aspect_lib.sh TwoDSubduction create_submit_group lochy@peloton.cse.ucdavis.edu .output/job.log'
