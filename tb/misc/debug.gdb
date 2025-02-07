target remote :3333
monitor reset halt

load

d breakpoints
b main
b syscalls.c:116

i b
i r pc

printf "------------------------------------\n"
printf "-------------- X-HEEP --------------\n"
printf "------------------------------------\n"
printf "Write c to continue or stepi to step\n"
