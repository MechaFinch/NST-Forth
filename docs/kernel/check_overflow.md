### Kernel Functions
# check_overflow
<dl>
	<dt>Arguments</dt>
	<dd>None</dd>
	<dt>Returns</dt>
	<dd>None</dd>
	<dt>Clobbers</dt>
	<dd>B:C</dd>
	<dd>J:I</dd>
</dl>

 Checks the parameter, locals, and return stacks, and the dictionary, for overflow and underflow.
 If over/underflow is detected, the corresponding exception code is thrown. 

 The locals stack overflow and underflow codes are -256 and -257 respectively.
