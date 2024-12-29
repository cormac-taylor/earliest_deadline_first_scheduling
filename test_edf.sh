#!/bin/bash

targetfile=edf.c
cfile=edf.c
maxtime=2

if [ ! -f "$targetfile" ]; then
    echo "Error: file $targetfile not found"
    echo "Final score: score - penalties = 0 - 0 = 0"
    exit 1
fi

# Required by the Honor System
missing_name=0
head -n 20 "$targetfile" | egrep -i "author.*[a-zA-Z]+"
if [ $? -ne 0 ]; then
    echo "Student name missing"
    missing_name=1
fi

# Required by the Honor System
missing_pledge=0
head -n 20 "$targetfile" | egrep -i "I.*pledge.*my.*honor.*that.*I.*have.*abided.*by.*the.*Stevens.*Honor.*System"
if [ $? -ne 0 ]; then
    echo -e "Pledge missing"
    missing_pledge=1
fi

# Compiling
echo
results=$(make 2>&1)
if [ $? -ne 0 ]; then
    echo "$results"
    echo "Final score: score - penalties = 0 - 0 = 0"
    exit 1
fi

num_tests=0
num_right=0
memory_problems=0
command="./${cfile%.*}"

run_test_with_args_and_input() {
    ((num_tests++))
    echo -n "Test $num_tests..."

    args="$1"
    input="$2"
    expected_output="$3"

    outputfile=$(mktemp)
    inputfile=$(mktemp)
    statusfile=$(mktemp)

    echo -e "$input" > "$inputfile"

    start=$(date +%s.%N)
    # Run run run, little program!
    (timeout --preserve-status "$maxtime" "$command" $args < "$inputfile" &> "$outputfile"; echo $? > "$statusfile") &> /dev/null
    end=$(date +%s.%N)
    status=$(cat "$statusfile")

    case $status in
        # $command: 128 + SIGBUS = 128 + 7 = 135 (rare on x86)
        135)
            echo "failed (bus error)"
            ;;
        # $command: 128 + SIGSEGV = 128 + 11 = 139
        139)
            echo "failed (segmentation fault)"
            ;;
        # $command: 128 + SIGTERM (sent by timeout(1)) = 128 + 15 = 143
        143)
            echo "failed (time out)"
            ;;
        *)
            # bash doesn't like null bytes so we substitute by hand.
            computed_output=$(sed -e 's/\x0/(NULL BYTE)/g' "$outputfile")
            if [ "$computed_output" = "$expected_output" ]; then
                ((num_right++))
                echo $start $end | awk '{printf "ok (%.3fs)\tvalgrind...", $2 - $1}'
                # Why 93?  Why not 93!
                (valgrind --leak-check=full --error-exitcode=93 $command $args < "$inputfile" &> /dev/null; echo $? > "$statusfile") &> /dev/null
                vgstatus=$(cat "$statusfile")
                case $vgstatus in
                    # valgrind detected an error when running $command
                    93)
                        ((memory_problems++))
                        echo "failed"
                        ;;
                    # valgrind not installed or not in $PATH
                    127)
                        echo "not found"
                        ;;
                    # valgrind: 128 + SIGBUS = 128 + 7 = 135 (rare on x86)
                    135)
                        ((memory_problems++))
                        echo "failed (bus error)"
                        ;;
                    # valgrind: 128 + SIGSEGV = 128 + 11 = 139
                    139)
                        ((memory_problems++))
                        echo "failed (segmentation fault)"
                        ;;
                    # compare with expected status from running $command without valgrind
                    $status)
                        echo "ok"
                        ;;
                    *)
                        ((memory_problems++))
                        echo "unknown status $vgstatus"
                        ;;
                esac
            else
                echo "failed"
                echo "==================== Expected ===================="
                echo "$expected_output"
                echo "==================== Received ===================="
                echo "$computed_output"
                echo "=================================================="
            fi
            ;;
    esac
    rm -f "$inputfile" "$outputfile" "$statusfile"
}

run_test_with_args() {
    run_test_with_args_and_input "$1" "" "$2"
}
run_test_with_input() {
    run_test_with_args_and_input "" "$1" "$2"
}

############################################################
run_test_with_input "1 2 2" "Enter the number of processes to schedule: Enter the CPU time of process 1: Enter the period of process 1: 0: processes (oldest first): 1 (2 ms)
0: process 1 starts
2: process 1 ends
2: Max Time reached
Sum of all waiting times: 0
Number of processes created: 1
Average Waiting Time: 0.00"

run_test_with_input "1 2 4" "Enter the number of processes to schedule: Enter the CPU time of process 1: Enter the period of process 1: 0: processes (oldest first): 1 (2 ms)
0: process 1 starts
2: process 1 ends
4: Max Time reached
Sum of all waiting times: 0
Number of processes created: 1
Average Waiting Time: 0.00"

run_test_with_input "2 1 4 3 5" "Enter the number of processes to schedule: Enter the CPU time of process 1: Enter the period of process 1: Enter the CPU time of process 2: Enter the period of process 2: 0: processes (oldest first): 1 (1 ms) 2 (3 ms)
0: process 1 starts
1: process 1 ends
1: process 2 starts
4: process 2 ends
4: processes (oldest first): 1 (1 ms)
4: process 1 starts
5: process 1 ends
5: processes (oldest first): 2 (3 ms)
5: process 2 starts
8: process 2 ends
8: processes (oldest first): 1 (1 ms)
8: process 1 starts
9: process 1 ends
10: processes (oldest first): 2 (3 ms)
10: process 2 starts
12: processes (oldest first): 2 (1 ms) 1 (1 ms)
13: process 2 ends
13: process 1 starts
14: process 1 ends
15: processes (oldest first): 2 (3 ms)
15: process 2 starts
16: processes (oldest first): 2 (2 ms) 1 (1 ms)
18: process 2 ends
18: process 1 starts
19: process 1 ends
20: Max Time reached
Sum of all waiting times: 4
Number of processes created: 9
Average Waiting Time: 0.44"

run_test_with_input "2 25 50 35 80" "Enter the number of processes to schedule: Enter the CPU time of process 1: Enter the period of process 1: Enter the CPU time of process 2: Enter the period of process 2: 0: processes (oldest first): 1 (25 ms) 2 (35 ms)
0: process 1 starts
25: process 1 ends
25: process 2 starts
50: processes (oldest first): 2 (10 ms) 1 (25 ms)
60: process 2 ends
60: process 1 starts
80: processes (oldest first): 1 (5 ms) 2 (35 ms)
85: process 1 ends
85: process 2 starts
100: processes (oldest first): 2 (20 ms) 1 (25 ms)
100: process 2 preempted!
100: process 1 starts
125: process 1 ends
125: process 2 starts
145: process 2 ends
150: processes (oldest first): 1 (25 ms)
150: process 1 starts
160: processes (oldest first): 1 (15 ms) 2 (35 ms)
175: process 1 ends
175: process 2 starts
200: processes (oldest first): 2 (10 ms) 1 (25 ms)
210: process 2 ends
210: process 1 starts
235: process 1 ends
240: processes (oldest first): 2 (35 ms)
240: process 2 starts
250: processes (oldest first): 2 (25 ms) 1 (25 ms)
250: process 2 preempted!
250: process 1 starts
275: process 1 ends
275: process 2 starts
300: process 2 ends
300: processes (oldest first): 1 (25 ms)
300: process 1 starts
320: processes (oldest first): 1 (5 ms) 2 (35 ms)
325: process 1 ends
325: process 2 starts
350: processes (oldest first): 2 (10 ms) 1 (25 ms)
360: process 2 ends
360: process 1 starts
385: process 1 ends
400: Max Time reached
Sum of all waiting times: 130
Number of processes created: 13
Average Waiting Time: 10.00"

run_test_with_input "3 2 4 4 8 3 6" "Enter the number of processes to schedule: Enter the CPU time of process 1: Enter the period of process 1: Enter the CPU time of process 2: Enter the period of process 2: Enter the CPU time of process 3: Enter the period of process 3: 0: processes (oldest first): 1 (2 ms) 2 (4 ms) 3 (3 ms)
0: process 1 starts
2: process 1 ends
2: process 3 starts
4: processes (oldest first): 2 (4 ms) 3 (1 ms) 1 (2 ms)
5: process 3 ends
5: process 2 starts
6: processes (oldest first): 2 (3 ms) 1 (2 ms) 3 (3 ms)
8: process 1 missed deadline (2 ms left), new deadline is 12
8: process 2 missed deadline (1 ms left), new deadline is 16
8: processes (oldest first): 2 (1 ms) 1 (2 ms) 3 (3 ms) 1 (2 ms) 2 (4 ms)
8: process 2 preempted!
8: process 1 starts
10: process 1 ends
10: process 3 starts
12: process 1 missed deadline (2 ms left), new deadline is 16
12: process 3 missed deadline (1 ms left), new deadline is 18
12: processes (oldest first): 2 (1 ms) 3 (1 ms) 1 (2 ms) 2 (4 ms) 1 (2 ms) 3 (3 ms)
12: process 3 preempted!
12: process 2 starts
13: process 2 ends
13: process 1 starts
15: process 1 ends
15: process 2 starts
16: process 1 missed deadline (2 ms left), new deadline is 20
16: process 2 missed deadline (3 ms left), new deadline is 24
16: processes (oldest first): 3 (1 ms) 2 (3 ms) 1 (2 ms) 3 (3 ms) 1 (2 ms) 2 (4 ms)
16: process 2 preempted!
16: process 3 starts
17: process 3 ends
17: process 3 starts
18: process 3 missed deadline (2 ms left), new deadline is 24
18: processes (oldest first): 2 (3 ms) 1 (2 ms) 3 (2 ms) 1 (2 ms) 2 (4 ms) 3 (3 ms)
18: process 3 preempted!
18: process 1 starts
20: process 1 ends
20: process 1 missed deadline (2 ms left), new deadline is 24
20: processes (oldest first): 2 (3 ms) 3 (2 ms) 1 (2 ms) 2 (4 ms) 3 (3 ms) 1 (2 ms)
20: process 2 starts
23: process 2 ends
23: process 3 starts
24: Max Time reached
Sum of all waiting times: 81
Number of processes created: 13
Average Waiting Time: 6.23"

run_test_with_input "4 1 2 2 4 3 6 5 10" "Enter the number of processes to schedule: Enter the CPU time of process 1: Enter the period of process 1: Enter the CPU time of process 2: Enter the period of process 2: Enter the CPU time of process 3: Enter the period of process 3: Enter the CPU time of process 4: Enter the period of process 4: 0: processes (oldest first): 1 (1 ms) 2 (2 ms) 3 (3 ms) 4 (5 ms)
0: process 1 starts
1: process 1 ends
1: process 2 starts
2: processes (oldest first): 2 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms)
3: process 2 ends
3: process 1 starts
4: process 1 ends
4: processes (oldest first): 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms)
4: process 3 starts
6: process 1 missed deadline (1 ms left), new deadline is 8
6: process 3 missed deadline (1 ms left), new deadline is 12
6: processes (oldest first): 3 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms)
6: process 3 preempted!
6: process 1 starts
7: process 1 ends
7: process 2 starts
8: process 1 missed deadline (1 ms left), new deadline is 10
8: process 2 missed deadline (1 ms left), new deadline is 12
8: processes (oldest first): 3 (1 ms) 4 (5 ms) 2 (1 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms)
8: process 2 preempted!
8: process 4 starts
10: process 1 missed deadline (1 ms left), new deadline is 12
10: process 1 missed deadline (1 ms left), new deadline is 12
10: process 4 missed deadline (3 ms left), new deadline is 20
10: processes (oldest first): 3 (1 ms) 4 (3 ms) 2 (1 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 4 (5 ms)
10: process 4 preempted!
10: process 3 starts
11: process 3 ends
11: process 2 starts
12: process 2 ends
12: process 1 missed deadline (1 ms left), new deadline is 14
12: process 1 missed deadline (1 ms left), new deadline is 14
12: process 1 missed deadline (1 ms left), new deadline is 14
12: process 2 missed deadline (2 ms left), new deadline is 16
12: process 3 missed deadline (3 ms left), new deadline is 18
12: processes (oldest first): 4 (3 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms)
12: process 1 starts
13: process 1 ends
13: process 1 starts
14: process 1 ends
14: process 1 missed deadline (1 ms left), new deadline is 16
14: process 1 missed deadline (1 ms left), new deadline is 16
14: processes (oldest first): 4 (3 ms) 3 (3 ms) 2 (2 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms)
14: process 2 starts
16: process 2 ends
16: process 1 missed deadline (1 ms left), new deadline is 18
16: process 1 missed deadline (1 ms left), new deadline is 18
16: process 1 missed deadline (1 ms left), new deadline is 18
16: process 2 missed deadline (2 ms left), new deadline is 20
16: processes (oldest first): 4 (3 ms) 3 (3 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms)
16: process 3 starts
18: process 1 missed deadline (1 ms left), new deadline is 20
18: process 1 missed deadline (1 ms left), new deadline is 20
18: process 1 missed deadline (1 ms left), new deadline is 20
18: process 1 missed deadline (1 ms left), new deadline is 20
18: process 3 missed deadline (1 ms left), new deadline is 24
18: process 3 missed deadline (3 ms left), new deadline is 24
18: processes (oldest first): 4 (3 ms) 3 (1 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms)
18: process 3 preempted!
18: process 4 starts
20: process 1 missed deadline (1 ms left), new deadline is 22
20: process 1 missed deadline (1 ms left), new deadline is 22
20: process 1 missed deadline (1 ms left), new deadline is 22
20: process 1 missed deadline (1 ms left), new deadline is 22
20: process 1 missed deadline (1 ms left), new deadline is 22
20: process 2 missed deadline (2 ms left), new deadline is 24
20: process 2 missed deadline (2 ms left), new deadline is 24
20: process 4 missed deadline (1 ms left), new deadline is 30
20: process 4 missed deadline (5 ms left), new deadline is 30
20: processes (oldest first): 4 (1 ms) 3 (1 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms)
20: process 4 preempted!
20: process 1 starts
21: process 1 ends
21: process 1 starts
22: process 1 ends
22: process 1 missed deadline (1 ms left), new deadline is 24
22: process 1 missed deadline (1 ms left), new deadline is 24
22: process 1 missed deadline (1 ms left), new deadline is 24
22: process 1 missed deadline (1 ms left), new deadline is 24
22: processes (oldest first): 4 (1 ms) 3 (1 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms)
22: process 3 starts
23: process 3 ends
23: process 2 starts
24: process 1 missed deadline (1 ms left), new deadline is 26
24: process 1 missed deadline (1 ms left), new deadline is 26
24: process 1 missed deadline (1 ms left), new deadline is 26
24: process 1 missed deadline (1 ms left), new deadline is 26
24: process 1 missed deadline (1 ms left), new deadline is 26
24: process 2 missed deadline (1 ms left), new deadline is 28
24: process 2 missed deadline (2 ms left), new deadline is 28
24: process 2 missed deadline (2 ms left), new deadline is 28
24: process 3 missed deadline (3 ms left), new deadline is 30
24: process 3 missed deadline (3 ms left), new deadline is 30
24: processes (oldest first): 4 (1 ms) 4 (5 ms) 2 (1 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms)
24: process 2 preempted!
24: process 1 starts
25: process 1 ends
25: process 1 starts
26: process 1 ends
26: process 1 missed deadline (1 ms left), new deadline is 28
26: process 1 missed deadline (1 ms left), new deadline is 28
26: process 1 missed deadline (1 ms left), new deadline is 28
26: process 1 missed deadline (1 ms left), new deadline is 28
26: processes (oldest first): 4 (1 ms) 4 (5 ms) 2 (1 ms) 3 (3 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms)
26: process 2 starts
27: process 2 ends
27: process 2 starts
28: process 1 missed deadline (1 ms left), new deadline is 30
28: process 1 missed deadline (1 ms left), new deadline is 30
28: process 1 missed deadline (1 ms left), new deadline is 30
28: process 1 missed deadline (1 ms left), new deadline is 30
28: process 1 missed deadline (1 ms left), new deadline is 30
28: process 2 missed deadline (1 ms left), new deadline is 32
28: process 2 missed deadline (2 ms left), new deadline is 32
28: process 2 missed deadline (2 ms left), new deadline is 32
28: processes (oldest first): 4 (1 ms) 4 (5 ms) 3 (3 ms) 2 (1 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms)
28: process 2 preempted!
28: process 4 starts
29: process 4 ends
29: process 4 starts
30: process 1 missed deadline (1 ms left), new deadline is 32
30: process 1 missed deadline (1 ms left), new deadline is 32
30: process 1 missed deadline (1 ms left), new deadline is 32
30: process 1 missed deadline (1 ms left), new deadline is 32
30: process 1 missed deadline (1 ms left), new deadline is 32
30: process 1 missed deadline (1 ms left), new deadline is 32
30: process 3 missed deadline (3 ms left), new deadline is 36
30: process 3 missed deadline (3 ms left), new deadline is 36
30: process 3 missed deadline (3 ms left), new deadline is 36
30: process 4 missed deadline (4 ms left), new deadline is 40
30: process 4 missed deadline (5 ms left), new deadline is 40
30: processes (oldest first): 4 (4 ms) 3 (3 ms) 2 (1 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms)
30: process 4 preempted!
30: process 2 starts
31: process 2 ends
31: process 1 starts
32: process 1 ends
32: process 1 missed deadline (1 ms left), new deadline is 34
32: process 1 missed deadline (1 ms left), new deadline is 34
32: process 1 missed deadline (1 ms left), new deadline is 34
32: process 1 missed deadline (1 ms left), new deadline is 34
32: process 1 missed deadline (1 ms left), new deadline is 34
32: process 1 missed deadline (1 ms left), new deadline is 34
32: process 2 missed deadline (2 ms left), new deadline is 36
32: process 2 missed deadline (2 ms left), new deadline is 36
32: process 2 missed deadline (2 ms left), new deadline is 36
32: processes (oldest first): 4 (4 ms) 3 (3 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms)
32: process 1 starts
33: process 1 ends
33: process 1 starts
34: process 1 ends
34: process 1 missed deadline (1 ms left), new deadline is 36
34: process 1 missed deadline (1 ms left), new deadline is 36
34: process 1 missed deadline (1 ms left), new deadline is 36
34: process 1 missed deadline (1 ms left), new deadline is 36
34: process 1 missed deadline (1 ms left), new deadline is 36
34: processes (oldest first): 4 (4 ms) 3 (3 ms) 3 (3 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms)
34: process 3 starts
36: process 1 missed deadline (1 ms left), new deadline is 38
36: process 1 missed deadline (1 ms left), new deadline is 38
36: process 1 missed deadline (1 ms left), new deadline is 38
36: process 1 missed deadline (1 ms left), new deadline is 38
36: process 1 missed deadline (1 ms left), new deadline is 38
36: process 1 missed deadline (1 ms left), new deadline is 38
36: process 2 missed deadline (2 ms left), new deadline is 40
36: process 2 missed deadline (2 ms left), new deadline is 40
36: process 2 missed deadline (2 ms left), new deadline is 40
36: process 2 missed deadline (2 ms left), new deadline is 40
36: process 3 missed deadline (1 ms left), new deadline is 42
36: process 3 missed deadline (3 ms left), new deadline is 42
36: process 3 missed deadline (3 ms left), new deadline is 42
36: process 3 missed deadline (3 ms left), new deadline is 42
36: processes (oldest first): 4 (4 ms) 3 (1 ms) 3 (3 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms)
36: process 3 preempted!
36: process 1 starts
37: process 1 ends
37: process 1 starts
38: process 1 ends
38: process 1 missed deadline (1 ms left), new deadline is 40
38: process 1 missed deadline (1 ms left), new deadline is 40
38: process 1 missed deadline (1 ms left), new deadline is 40
38: process 1 missed deadline (1 ms left), new deadline is 40
38: process 1 missed deadline (1 ms left), new deadline is 40
38: processes (oldest first): 4 (4 ms) 3 (1 ms) 3 (3 ms) 2 (2 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms)
38: process 4 starts
40: process 1 missed deadline (1 ms left), new deadline is 42
40: process 1 missed deadline (1 ms left), new deadline is 42
40: process 1 missed deadline (1 ms left), new deadline is 42
40: process 1 missed deadline (1 ms left), new deadline is 42
40: process 1 missed deadline (1 ms left), new deadline is 42
40: process 1 missed deadline (1 ms left), new deadline is 42
40: process 2 missed deadline (2 ms left), new deadline is 44
40: process 2 missed deadline (2 ms left), new deadline is 44
40: process 2 missed deadline (2 ms left), new deadline is 44
40: process 2 missed deadline (2 ms left), new deadline is 44
40: process 2 missed deadline (2 ms left), new deadline is 44
40: process 4 missed deadline (2 ms left), new deadline is 50
40: process 4 missed deadline (5 ms left), new deadline is 50
40: process 4 missed deadline (5 ms left), new deadline is 50
40: processes (oldest first): 4 (2 ms) 3 (1 ms) 3 (3 ms) 2 (2 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms)
40: process 4 preempted!
40: process 3 starts
41: process 3 ends
41: process 3 starts
42: process 1 missed deadline (1 ms left), new deadline is 44
42: process 1 missed deadline (1 ms left), new deadline is 44
42: process 1 missed deadline (1 ms left), new deadline is 44
42: process 1 missed deadline (1 ms left), new deadline is 44
42: process 1 missed deadline (1 ms left), new deadline is 44
42: process 1 missed deadline (1 ms left), new deadline is 44
42: process 1 missed deadline (1 ms left), new deadline is 44
42: process 3 missed deadline (2 ms left), new deadline is 48
42: process 3 missed deadline (3 ms left), new deadline is 48
42: process 3 missed deadline (3 ms left), new deadline is 48
42: process 3 missed deadline (3 ms left), new deadline is 48
42: processes (oldest first): 4 (2 ms) 3 (2 ms) 2 (2 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms)
42: process 3 preempted!
42: process 2 starts
44: process 2 ends
44: process 1 missed deadline (1 ms left), new deadline is 46
44: process 1 missed deadline (1 ms left), new deadline is 46
44: process 1 missed deadline (1 ms left), new deadline is 46
44: process 1 missed deadline (1 ms left), new deadline is 46
44: process 1 missed deadline (1 ms left), new deadline is 46
44: process 1 missed deadline (1 ms left), new deadline is 46
44: process 1 missed deadline (1 ms left), new deadline is 46
44: process 1 missed deadline (1 ms left), new deadline is 46
44: process 2 missed deadline (2 ms left), new deadline is 48
44: process 2 missed deadline (2 ms left), new deadline is 48
44: process 2 missed deadline (2 ms left), new deadline is 48
44: process 2 missed deadline (2 ms left), new deadline is 48
44: process 2 missed deadline (2 ms left), new deadline is 48
44: processes (oldest first): 4 (2 ms) 3 (2 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms)
44: process 1 starts
45: process 1 ends
45: process 1 starts
46: process 1 ends
46: process 1 missed deadline (1 ms left), new deadline is 48
46: process 1 missed deadline (1 ms left), new deadline is 48
46: process 1 missed deadline (1 ms left), new deadline is 48
46: process 1 missed deadline (1 ms left), new deadline is 48
46: process 1 missed deadline (1 ms left), new deadline is 48
46: process 1 missed deadline (1 ms left), new deadline is 48
46: process 1 missed deadline (1 ms left), new deadline is 48
46: processes (oldest first): 4 (2 ms) 3 (2 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 2 (2 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms)
46: process 3 starts
48: process 3 ends
48: process 1 missed deadline (1 ms left), new deadline is 50
48: process 1 missed deadline (1 ms left), new deadline is 50
48: process 1 missed deadline (1 ms left), new deadline is 50
48: process 1 missed deadline (1 ms left), new deadline is 50
48: process 1 missed deadline (1 ms left), new deadline is 50
48: process 1 missed deadline (1 ms left), new deadline is 50
48: process 1 missed deadline (1 ms left), new deadline is 50
48: process 1 missed deadline (1 ms left), new deadline is 50
48: process 2 missed deadline (2 ms left), new deadline is 52
48: process 2 missed deadline (2 ms left), new deadline is 52
48: process 2 missed deadline (2 ms left), new deadline is 52
48: process 2 missed deadline (2 ms left), new deadline is 52
48: process 2 missed deadline (2 ms left), new deadline is 52
48: process 2 missed deadline (2 ms left), new deadline is 52
48: process 3 missed deadline (3 ms left), new deadline is 54
48: process 3 missed deadline (3 ms left), new deadline is 54
48: process 3 missed deadline (3 ms left), new deadline is 54
48: process 3 missed deadline (3 ms left), new deadline is 54
48: processes (oldest first): 4 (2 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 2 (2 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms)
48: process 4 starts
50: process 4 ends
50: process 1 missed deadline (1 ms left), new deadline is 52
50: process 1 missed deadline (1 ms left), new deadline is 52
50: process 1 missed deadline (1 ms left), new deadline is 52
50: process 1 missed deadline (1 ms left), new deadline is 52
50: process 1 missed deadline (1 ms left), new deadline is 52
50: process 1 missed deadline (1 ms left), new deadline is 52
50: process 1 missed deadline (1 ms left), new deadline is 52
50: process 1 missed deadline (1 ms left), new deadline is 52
50: process 1 missed deadline (1 ms left), new deadline is 52
50: process 4 missed deadline (5 ms left), new deadline is 60
50: process 4 missed deadline (5 ms left), new deadline is 60
50: process 4 missed deadline (5 ms left), new deadline is 60
50: processes (oldest first): 4 (5 ms) 2 (2 ms) 3 (3 ms) 2 (2 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 4 (5 ms)
50: process 2 starts
52: process 2 ends
52: process 1 missed deadline (1 ms left), new deadline is 54
52: process 1 missed deadline (1 ms left), new deadline is 54
52: process 1 missed deadline (1 ms left), new deadline is 54
52: process 1 missed deadline (1 ms left), new deadline is 54
52: process 1 missed deadline (1 ms left), new deadline is 54
52: process 1 missed deadline (1 ms left), new deadline is 54
52: process 1 missed deadline (1 ms left), new deadline is 54
52: process 1 missed deadline (1 ms left), new deadline is 54
52: process 1 missed deadline (1 ms left), new deadline is 54
52: process 1 missed deadline (1 ms left), new deadline is 54
52: process 2 missed deadline (2 ms left), new deadline is 56
52: process 2 missed deadline (2 ms left), new deadline is 56
52: process 2 missed deadline (2 ms left), new deadline is 56
52: process 2 missed deadline (2 ms left), new deadline is 56
52: process 2 missed deadline (2 ms left), new deadline is 56
52: process 2 missed deadline (2 ms left), new deadline is 56
52: processes (oldest first): 4 (5 ms) 3 (3 ms) 2 (2 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms)
52: process 3 starts
54: process 1 missed deadline (1 ms left), new deadline is 56
54: process 1 missed deadline (1 ms left), new deadline is 56
54: process 1 missed deadline (1 ms left), new deadline is 56
54: process 1 missed deadline (1 ms left), new deadline is 56
54: process 1 missed deadline (1 ms left), new deadline is 56
54: process 1 missed deadline (1 ms left), new deadline is 56
54: process 1 missed deadline (1 ms left), new deadline is 56
54: process 1 missed deadline (1 ms left), new deadline is 56
54: process 1 missed deadline (1 ms left), new deadline is 56
54: process 1 missed deadline (1 ms left), new deadline is 56
54: process 1 missed deadline (1 ms left), new deadline is 56
54: process 3 missed deadline (1 ms left), new deadline is 60
54: process 3 missed deadline (3 ms left), new deadline is 60
54: process 3 missed deadline (3 ms left), new deadline is 60
54: process 3 missed deadline (3 ms left), new deadline is 60
54: process 3 missed deadline (3 ms left), new deadline is 60
54: processes (oldest first): 4 (5 ms) 3 (1 ms) 2 (2 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms)
54: process 3 preempted!
54: process 2 starts
56: process 2 ends
56: process 1 missed deadline (1 ms left), new deadline is 58
56: process 1 missed deadline (1 ms left), new deadline is 58
56: process 1 missed deadline (1 ms left), new deadline is 58
56: process 1 missed deadline (1 ms left), new deadline is 58
56: process 1 missed deadline (1 ms left), new deadline is 58
56: process 1 missed deadline (1 ms left), new deadline is 58
56: process 1 missed deadline (1 ms left), new deadline is 58
56: process 1 missed deadline (1 ms left), new deadline is 58
56: process 1 missed deadline (1 ms left), new deadline is 58
56: process 1 missed deadline (1 ms left), new deadline is 58
56: process 1 missed deadline (1 ms left), new deadline is 58
56: process 1 missed deadline (1 ms left), new deadline is 58
56: process 2 missed deadline (2 ms left), new deadline is 60
56: process 2 missed deadline (2 ms left), new deadline is 60
56: process 2 missed deadline (2 ms left), new deadline is 60
56: process 2 missed deadline (2 ms left), new deadline is 60
56: process 2 missed deadline (2 ms left), new deadline is 60
56: process 2 missed deadline (2 ms left), new deadline is 60
56: processes (oldest first): 4 (5 ms) 3 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms)
56: process 1 starts
57: process 1 ends
57: process 1 starts
58: process 1 ends
58: process 1 missed deadline (1 ms left), new deadline is 60
58: process 1 missed deadline (1 ms left), new deadline is 60
58: process 1 missed deadline (1 ms left), new deadline is 60
58: process 1 missed deadline (1 ms left), new deadline is 60
58: process 1 missed deadline (1 ms left), new deadline is 60
58: process 1 missed deadline (1 ms left), new deadline is 60
58: process 1 missed deadline (1 ms left), new deadline is 60
58: process 1 missed deadline (1 ms left), new deadline is 60
58: process 1 missed deadline (1 ms left), new deadline is 60
58: process 1 missed deadline (1 ms left), new deadline is 60
58: process 1 missed deadline (1 ms left), new deadline is 60
58: processes (oldest first): 4 (5 ms) 3 (1 ms) 3 (3 ms) 4 (5 ms) 2 (2 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms)
58: process 4 starts
60: Max Time reached
Sum of all waiting times: 926
Number of processes created: 61
Average Waiting Time: 15.18"

############################################################
echo
echo "Total tests run: $num_tests"
echo "Number correct : $num_right"
score=$((100 * $num_right / $num_tests))
echo "Percent correct: $score%"
if [ $missing_name == 1 ]; then
    echo "Missing Name: -5"
fi
if [ $missing_pledge == 1 ]; then
    echo "Missing or incorrect pledge: -5"
fi

if [ $memory_problems -gt 1 ]; then
    echo "Memory problems: $memory_problems (-5 each, max of -15)"
    if [ $memory_problems -gt 3 ]; then
        memory_problems=3
    fi
fi

penalties=$((5 * $missing_name + 5 * $missing_pledge + 5 * $memory_problems))
final_score=$(($score - $penalties))
if [ $final_score -lt 0 ]; then
    final_score=0
fi
echo "Final score: score - penalties = $score - $penalties = $final_score"

make clean > /dev/null 2>&1
