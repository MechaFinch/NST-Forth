### Kernel Functions
# do_zero_branch
<dl>
	<dt>Arguments</dt>
	<dd>None</dd>
	<dt>Returns</dt>
	<dd>None</dd>
	<dt>Clobbers</dt>
	<dd>None</dd>
</dl>

 Does the runtime action of ZEROBRANCH. If TOS = 0, branch by offset in the word after the CALL. Otherwise,
 skip offset to return.
