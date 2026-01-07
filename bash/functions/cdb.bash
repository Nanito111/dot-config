cdb() {
    go_back_times=$1

    # check if is number
    printf "%d\n" $go_back_times &> /dev/null
    result_status="$?"

    # return if not number
    if [[ $result_status != "0" ]]; then
        echo "Invalid parameter. Not an integer."
        return $result_status
    fi

    # check number is gt 0
    if ((go_back_times < 1)) then
        echo "Number should be greater than 0."
        return 1
    fi

    go_back_string="../"
    for ((i = 1; i < $go_back_times; i++)); do
        go_back_string="${go_back_string}../"
    done

    cd $go_back_string
    echo "Went back $go_back_times directories"
    echo $is_number_status
}
