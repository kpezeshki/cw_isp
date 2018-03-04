USING GDB basics

Compile dcraw with -g flag:
>> gcc -g -o dcraw -O4 dcraw2_dp.c dcraw2_v.c -lm -DNODEPS

Run gdb on dcraw
>> gdb <executable>

Set arguments
>> set args -r 1 1 1 1 -q 0 <image_filename>

Set breakpoints
>> break <function_name>

View breakpoints
>> info break

Run program until breakpoint
>> run

Print variables
>> print <variable_name> 




