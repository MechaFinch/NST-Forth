### Kernel Functions
# print_number
<dl>
	<dt>Arguments</dt>
	<dd>BH&nbsp;&nbsp;Signed?</dd>
	<dd>BL&nbsp;&nbsp;Base</dd>
	<dd>J:I&nbsp;Number</dd>
	<dt>Returns</dt>
	<dd>C = 1 if success, 0 if failure</dd>
	<dt>Clobbers</dt>
	<dd>None</dd>
</dl>

 Prints a number with the given base. Returns C = 0 if base is invalid. If BH = 0, unsigned.
