/*******************************************************************************
* Filename    : edf.c
* Author      : Cormac Taylor
* Date        : March 3, 2024
* Description : Earliest Deadline First Scheduling Algorithm
* Pledge      : I pledge my honor that I have abided by the Stevens Honor System.
******************************************************************************/

#include <stdio.h>
#include <stdlib.h>

#define True 1
#define False 0

//nodes for linked list
typedef struct node {
    
    int process_type;
    int pid;
    int start_time;
    int end_of_period;  
    int cpu_left;
    struct node* next_node;
    struct node* next_print;
    struct node* next_id;
} Node;  

//initalizes instance of Node
Node* create_node(int type, int pid, int strt, int eop, int cpu){

    Node* new_node = (Node*) malloc(sizeof(Node));
    new_node -> process_type = type;
    new_node -> pid = pid;
    new_node -> start_time = strt;
    new_node -> end_of_period = eop;
    new_node -> cpu_left = cpu;
    new_node -> next_node = NULL;
    new_node -> next_print = NULL;
    new_node -> next_id = NULL;
    return new_node;
}

//adds the new_node to the linked list at head_id
void push_id(Node** head_id, Node** new_node){

    if(*head_id == NULL){
        *head_id = *new_node;
    } else if((*head_id) -> process_type > (*new_node) -> process_type ||
                ((*head_id) -> process_type == (*new_node) -> process_type && (*head_id) -> cpu_left > (*new_node) -> cpu_left) || 
                ((*head_id) -> process_type == (*new_node) -> process_type && (*head_id) -> cpu_left == (*new_node) -> cpu_left && (*head_id) -> start_time > (*new_node) -> start_time)){
        
        (*new_node) -> next_id = *head_id;
        *head_id = *new_node;
    } else {

        Node* cur = *head_id;
        Node* next = cur -> next_id;
        while(next != NULL && ((next) -> process_type < (*new_node) -> process_type ||
                ((next) -> process_type == (*new_node) -> process_type && (next) -> cpu_left < (*new_node) -> cpu_left) || 
                ((next) -> process_type == (*new_node) -> process_type && (next) -> cpu_left == (*new_node) -> cpu_left && (next) -> start_time < (*new_node) -> start_time))){
            cur = next;
            next = next -> next_id;
        }
        (*new_node) -> next_id = next;
        cur -> next_id = *new_node;
    }
}

//adds the new_node to the linked list at head_print
void push_print(Node** head_print, Node** new_node){
    
    if(*head_print == NULL){
        *head_print = *new_node;
    } else if((*head_print) -> start_time > (*new_node) -> start_time ||
                ((*head_print) -> start_time == (*new_node) -> start_time && (*head_print) -> process_type > (*new_node) -> process_type)){
        
        (*new_node) -> next_print = *head_print;
        *head_print = *new_node;
    } else {
        Node* cur = *head_print;
        Node* next = cur -> next_print;
        while(next != NULL && ((next) -> start_time < (*new_node) -> start_time ||
                ((next) -> start_time == (*new_node) -> start_time && (next) -> process_type < (*new_node) -> process_type))){
            cur = next;
            next = next -> next_print;
        }
        (*new_node) -> next_print = next;
        cur -> next_print = *new_node;
    }
}

//creates a new node and adds the new_node to the linked list at head
Node* push(Node** head, int type, int pid, int strt, int eop, int cpu){

    Node* new_node = create_node(type, pid, strt, eop, cpu);
    if(*head == NULL){
        *head = new_node;
    } else if(((*head) -> end_of_period > eop) || ((*head) -> end_of_period == eop && (*head) -> start_time > strt) ||
                                            ((*head) -> end_of_period == eop && (*head) -> start_time == strt && (*head) -> process_type > type)){

        new_node -> next_node = *head;
        *head = new_node;
    } else {

        Node* cur = *head;
        Node* next = cur -> next_node;

        while(next != NULL && ((next -> end_of_period < eop) || (next -> end_of_period == eop && next -> start_time < strt) ||
                                            (next -> end_of_period == eop && next -> start_time == strt && next -> process_type < type))){
            cur = next;
            next = next -> next_node;
        }
        new_node -> next_node = next;
        cur -> next_node = new_node;
    }
    return new_node;
}

//gets the cpu time left for a process
int peek(Node** head){  
    return (*head)->cpu_left;
}

//prints all the items in the print queue
void print_queue(Node** head){

    Node* cur = *head;
    while (cur != NULL){

        printf(" %d (%d ms)", cur -> process_type, peek(&cur));
        //printf(" || id:%d st:%d en:%d (%d ms)", cur -> process_type, cur -> start_time, cur -> end_of_period, peek(&cur));
        cur = cur -> next_print;
    }
    printf("\n");
}

//removes the node from the linked list at head_id
void remove_id(Node** head_id, Node** node){

    if(*head_id != NULL){

        if(*head_id == *node){
            *head_id = (*head_id) -> next_id;
            (*node) -> next_id = NULL;
        } else {

            Node* cur = *head_id;
            Node* next = cur -> next_id;
            while(next != NULL && next != *node){
                cur = next;
                next = next -> next_id;
            }
            if(next != NULL){
                cur -> next_id = next -> next_id;
                next -> next_id = NULL;
            }
        }
    }
}

//removes the node from the linked list at head_print
void remove_print(Node** head_print, Node** node){

    if(*head_print != NULL){

        if(*head_print == *node){
            *head_print = (*head_print) -> next_print;
            (*node) -> next_print = NULL;
        } else {

            Node* cur = *head_print;
            Node* next = cur -> next_print;
            while(next != NULL && next != *node){
                cur = next;
                next = next -> next_print;
            }
            if(next != NULL){
                cur -> next_print = next -> next_print;
                next -> next_print = NULL;
            }
        }
    }
}

//removes the node from the head of the linked list
void pop(Node** head){  

    Node* old_node = *head;
    *head = old_node -> next_node;
    old_node -> next_node = NULL;
    free(old_node);
}

//removes the node from the linked list
void remove_node(Node** head, Node** node){

    Node* n = *node;
    if(*head != NULL){

        if(*head == *node){

            Node* old_node = *head;
            *head = old_node -> next_node;
            old_node -> next_node = NULL;
        } else {

            Node* cur = *head;
            Node* next = cur -> next_node;
            while(next != NULL && next != n){
                cur = next;
                next = next -> next_node;
            }
            if(next != NULL){
                cur -> next_node = next -> next_node;
                next -> next_node = NULL;
            }
        }
    }
    free(n);
}

//eudclidian algorithm for greatest common divisor
int gcd(int a, int b){

    if(a == 0){
        return b;
    }
    return gcd(b % a, a);
}

//least commmon multiple for a list of positive values for max time
int lcm_list(int* lst, int len){

    int result = lst[0];
    for(int i = 1; i < len; i++){
        result = (result * lst[i]) / gcd(result, lst[i]);
    }
    return result;
}

//greatest common divisor of all periods and cpu times for time delta
int get_time_delta(int* l1, int* l2, int len){

    int result = l1[0];
    for(int i = 1; i < len; i++){
        result = gcd(result, l1[i]);
    }
    for(int i = 0; i < len; i++){
        result = gcd(result, l2[i]);
    }
    return result;
}

void edf(int* cpu_times, int* period_times, int num_processes){

    //time vars
    int max_time = lcm_list(period_times, num_processes);
    int time_delta = get_time_delta(period_times, cpu_times, num_processes);
    int time = 0;

    //stats  vars
    int total_waiting_time = 0;
    int num_processes_created = 0;

    //queue vars
    int queue_len = 0;
    int pid_counter = 0;
    int popped;
    int pushed;
    int type_on_cpu = -1;
    int pid_on_cpu = -1;

    //queues
    Node* queue = NULL;
    Node* print_q = NULL;
    Node* id_q = NULL;

    while(time < max_time){

        //removal
        popped = False; 
        if(queue != NULL && peek(&queue) == 0){

            printf("%d: process %d ends\n", time, type_on_cpu);
            remove_id(&id_q, &queue);
            remove_print(&print_q, &queue);
            pop(&queue);
            queue_len--;
            popped = True; 
        }

        //updating and printing missed deadlines
        int type, st, eop, cpu, miss;
        Node* next = id_q;
        while(next != NULL){

            if(pid_on_cpu == next -> pid){
                
                type = next -> process_type; st = next -> start_time; eop = next -> end_of_period; cpu = next -> cpu_left;
                remove_id(&id_q, &next);
                remove_print(&print_q, &next);
                remove_node(&queue, &next);
                Node* new_node= push(&queue, type, pid_counter, st, eop, cpu);
                pid_counter++;
                push_print(&print_q, &new_node);
                push_id(&id_q, &new_node);
                pid_on_cpu = new_node -> pid;
                next = new_node;
            }

            miss = False;
            if(next -> end_of_period == time){

                next -> end_of_period += period_times[((next -> process_type) - 1)];
                printf("%d: process %d missed deadline (%d ms left), new deadline is %d\n", time, next -> process_type, next -> cpu_left, next -> end_of_period);
                type = next -> process_type; st = next -> start_time; eop = next -> end_of_period; cpu = next -> cpu_left;
                remove_id(&id_q, &next);
                remove_print(&print_q, &next);
                remove_node(&queue, &next);
                Node* new_node= push(&queue, type, pid_counter, st, eop, cpu);
                pid_counter++;
                push_print(&print_q, &new_node);
                push_id(&id_q, &new_node);
                miss = True;
            }
            if(miss){
                next = id_q;
            } else {
                next = next -> next_id;
            }
        }

        //adding new nodes to the lists based on period
        pushed = False; 
        for(int i = 0; i < num_processes; i++){

            if(time % period_times[i] == 0){
                
                Node* new_node = push(&queue, i + 1, pid_counter, time, period_times[i] + time, cpu_times[i]);
                push_print(&print_q, &new_node);
                push_id(&id_q, &new_node);
                num_processes_created++;
                queue_len++;
                pid_counter++;
                pushed = True;
            }
        }
        
        //checks the additions and removals for printing to user
        if(pushed){

            printf("%d: processes (oldest first):", time);
            print_queue(&print_q);
            if(pid_on_cpu != queue -> pid){

                if(!popped && type_on_cpu != -1){
                    printf("%d: process %d preempted!\n", time, type_on_cpu);
                }
                type_on_cpu = queue -> process_type;
                pid_on_cpu = queue -> pid;
                printf("%d: process %d starts\n", time, type_on_cpu);
            }
        } else if(queue != NULL && popped){
            type_on_cpu = queue -> process_type;
            pid_on_cpu = queue -> pid;
            printf("%d: process %d starts\n", time, type_on_cpu);
        } else if(queue == NULL && popped){
            type_on_cpu = -1;
            pid_on_cpu = -1;
        } 

        //updates node on cpu, stats, and time
        if(queue != NULL){

            queue -> cpu_left -= time_delta;
            total_waiting_time += (queue_len - 1) * time_delta;
        }
        time += time_delta;
    }

    //removes all the nodes still in the queues at max_time
    while(queue != NULL){

        if(peek(&queue) == 0){
            printf("%d: process %d ends\n", time, queue -> process_type);
        }
        remove_id(&id_q, &queue);
        remove_print(&print_q, &queue);
        remove_node(&queue, &queue);
    }

    printf("%d: Max Time reached\n", time);

    //stats
    printf("Sum of all waiting times: %d\n", total_waiting_time);
    printf("Number of processes created: %d\n", num_processes_created);
    printf("Average Waiting Time: %.2lf\n", ((double)total_waiting_time / num_processes_created));
}

int main(int argc, char* argv[]){

    //propt to get the number of processes
    int num_processes;
    printf("Enter the number of processes to schedule: ");
    scanf("%d", &num_processes);

    //dynamically creates two int arrays to hold cpu times and period times for each process
    int* cpu_times = (int*) malloc(num_processes * 4);
    int* period_times = (int*) malloc(num_processes * 4);


    //prompts and takes in cpu times and period times for each process
    for(int i = 0; i < num_processes; i++){
        printf("Enter the CPU time of process %d: ", i + 1);
        scanf("%d", cpu_times + i);

        printf("Enter the period of process %d: ", i + 1);
        scanf("%d", period_times + i);
    }

    //the earliest deadline first alg(if you can consider that monstrosity a alg)
    edf(cpu_times, period_times, num_processes);

    //always delete your mallocs
    free(cpu_times);
    free(period_times);
    return 0;
}
