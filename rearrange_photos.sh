path="/Volumes/192.168.0.1/iphone photos"
revert_path="/Volumes/192.168.0.1/iphone photos"

current_file_name=$0

remove_last_letter()
{
    local inp=$1
    local character=$2
        # Check if the last character is a slash
    if [[ "${inp: -1}" == $character ]]; then
        # Remove the last character
        inp="${inp%?}"
    fi
    echo "$inp"
}

get_folder_name()
{
    
    local inp=$(remove_last_letter "$1")
    local op=$(awk -F'/' '{print $NF}' <<< "$inp")
    echo "$op"
}

path_folder_name=$(get_folder_name "$path")
revert_path_folder_name=$(get_folder_name "$revert_path")


validate_path()
{
    # Checking if the path is valid or not
    if [ $1 == "process" ] && [ ! -d "$path" ]; then
        echo "The given path is $path not valid. Kindly give a valid path." >&2
        exit 1
    fi

    # Checking if the path ends with /
    if [ $1 == "process" ] && [[ "${path: -1}" != '/' ]]; then
        echo "Last character of path not ends with '/'."
        echo "Before \ added: $path"
        path="$path""/"
        echo "After \ added: $path"
    fi

    # Checking if the revert is valid or not
    if [ $1 == "revert" ] && [ ! -d "$revert_path" ]; then
        echo "The given revert path is $revert_path not valid. Kindly give a valid path." >&2
        exit 1
    fi
}

init_log_files()
{
    #Initiating log files in this function

    local current_datetime=$(date +"%Y-%m-%d %H:%M:%S")

    log_file="./log.txt"
    dir_log_file="./dir_log.txt"

    #Creating log files if not exists
    if [ ! -f "$log_file" ]; then
        touch $log_file
    fi

    if [ ! -f "$dir_log_file" ]; then
        touch $dir_log_file
    fi

    echo "Logging at $current_datetime \n\n" >> $log_file
    echo "Logging at $current_datetime \n\n" >> $dir_log_file
}

exit_log_file()
{
    #Exiting log files in this function

    local current_datetime=$(date +"%Y-%m-%d %H:%M:%S")

    echo "\n\n" >> $log_file
    echo "Logging finished at $current_datetime \n\n" >> $log_file

    echo "\n\n" >> $dir_log_file
    echo "Logging finished at $current_datetime \n\n" >> $dir_log_file
}

# ------------- Processing Functions ------------- #

get_year_of_a_file()
{
    #Get the created year of a file
    local year=$(stat -f %SB "$1" | awk '{print $4}')
    echo "$year"
}

get_month_of_a_file()
{
    #Get the created month of a file
    local year=$(stat -f %SB "$1" | awk '{print $1}')
    echo "$year"
}

move_file()
{
    #In this function, we move a file based on the created date.
    #The folder format is "Year" > "Month Year"

    local source_file="$1"
    local month="$2"
    local year="$3"
    local year_dir="$path""$year"
    local destination_dir="$month $year"
    local dir_path=$year_dir/$destination_dir

    #below commented line is used to check if the values are setted correctly while debugging.
    # echo "source_file $source_file month $month year $year year_dir $year_dir destination_dir $destination_dir dir_path $dir_path"

    # Create year directory if not exists
    if [ ! -d "$year_dir" ]; then
        mkdir "$year_dir"
        echo "Directory $year_dir created." >> $log_file
        echo "Directory $year_dir created." >> $dir_log_file
    fi

    # Check if the destination directory exists
    if [ -d "$dir_path" ]; then
        # If the directory exists, move the file into it
        mv "$source_file" "$dir_path/"
        echo "File $source_file moved to existing directory $destination_dir."  >> $log_file
    else
        # If the directory doesn't exist, create it and then move the file into it
        mkdir "$dir_path"
        mv "$source_file" "$dir_path/"
        echo "Directory $destination_dir created and file $source_file moved to $dir_path ."  >> $log_file
        echo "Directory $destination_dir created and file $source_file moved to $dir_path ."  >> $dir_log_file
    fi
}


process()
{
    validate_path "process"
    init_log_files

    echo "---------------- Processing starts ----------------"

    list_files_without_dir_sh_files=$(eval "ls -p '$path' | grep -v / | grep -v '\.sh$'")

    for filename in $list_files_without_dir_sh_files; do
        echo "Processing file $filename" >> $log_file

        filename="$path""$filename"

        current_file_month=$(get_month_of_a_file "$filename")
        current_file_year=$(get_year_of_a_file "$filename")
        echo "$filename year is $current_file_year and month is $current_file_month" >> $log_file
        move_file "$filename" "$current_file_month" "$current_file_year" 
        current_file_year=0

        echo "Processed file $filename" >> $log_file
        echo >> $log_file
    done

    echo "---------------- Processing ends ----------------"

    exit_log_file
}

# -------------x Processing Functions x------------- #




# ------------- Reverting Functions ------------- #

move_files_recursive() 
{
    #In this function, we recursively go through the directory and move the file to the revert path

    local source_dir="$1"
    local destination_dir="$2"

    # Loop through each item in the source directory
    for item in "$source_dir"/*; do
        if [[ "$item" =~ "$current_file_name" ]] || [[ "$item" == "*$path_folder_name" ]] || [[ "$item" == "*$revert_path_folder_name" ]] || [[ "$item" =~ $log_file ]] || [[ "$item" =~ $dir_log_file ]]; then
            echo "Skipping $item" >> $log_file
            continue
        fi

        if [[ -d "$item" ]]; then
            # If item is a directory, recursively move files within it
            move_files_recursive "$item" "$destination_dir"
        elif [[ -f "$item" ]]; then
            # If item is a file, move it to the destination directory
            mv "$item" "$destination_dir"
            echo "Moved file: $item to $destination_dir" >> $log_file
        fi
    done
}

revert_files()
{
    # Loop through directories in the current directory
    for dir in "$path"/*; do
        if [ -d "$dir" ]; then
            echo "Process in Directory: $dir" >> $log_file
            move_files_recursive "$dir" "$revert_path"
        fi
    done
}

revert()
{
    validate_path "revert"
    init_log_files

    echo "----- Reverting starts ----------------"

    revert_files

    echo "----- Reverting ends ----------------"

    exit_log_file

    echo "Please delete the year and month folder created when processing."    
}

# -------------x Reverting Functions x------------- #

if [ -z "$1" ]; then
    process
elif [ "$1" == "revert" ]; then
    revert
else
    echo "Please execute one of the below commands: \n sh $0 - process \n sh $0 revert - revert" >&2
    exit 1
fi