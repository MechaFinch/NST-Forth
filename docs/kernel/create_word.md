### Kernel Functions
# create_word
<dl>
	<dt>Arguments</dt>
	<dd>CL&nbsp;&nbsp;Length/Flags</dd>
	<dd>J:I&nbsp;Name Pointer</dd>
	<dt>Returns</dt>
	<dd>B:C&nbsp;Contents Pointer (HERE)</dd>
	<dd>J:I&nbsp;Header Pointer (LATEST)</dd>
	<dt>Clobbers</dt>
	<dd>None</dd>
</dl>

 Creates an empty definition with the given name and flags. An empty name is allowed. Returns pointers to the
 header and body of the word.
