### Kernel Functions
# search_dict
<dl>
	<dt>Arguments</dt>
	<dd>CL&nbsp;&nbsp;String length</dd>
	<dd>J:I&nbsp;String pointer</dd>
	<dt>Returns</dt>
	<dd>J:I&nbspHeader Pointer, or 0</dd>
	<dt>Clobbers</dt>
	<dd>B</dd>
	<dd>CH</dd>
</dl>

 Searches the dictionary for the given word. If found, returns a pointer to its header in J:I. If not found,
 returns 0 in J:I.
