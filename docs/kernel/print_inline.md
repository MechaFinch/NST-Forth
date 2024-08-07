### Kernel Functions
# print_inline
<dl>
	<dt>Arguments</dt>
	<dd>None</dd>
	<dt>Clobbers</dt>
	<dd>B:C</dd>
</dl>

 Prints the counted string found inline after the CALL to this function
 
```nasm
loop:
	CALL kernel_print_inline
	db 14, "Hello, World!", 0x0A
	JMP loop
```
 
 Execution resumes after the string.
