### Kernel Functions
# compile_remove_locals
<dl>
	<dt>Arguments</dt>
	<dd>CL&nbsp;&nbsp;Amount</dd>
	<dt>Returns</dt>
	<dd>J:I&nbsp;HERE</dd>
	<dt>Clobbers</dt>
	<dd>CH</dd>
</dl>

 Compiles code to remove the given number of locals from the locals stack, without removing them form
 the locals dictionary or updating their offsets.