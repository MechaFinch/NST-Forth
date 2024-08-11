### Kernel Functions
# do_init_locals
<dl>
	<dt>Arguments</dt>
	<dd>None</dd>
	<dt>Returns</dt>
	<dd>None</dd>
	<dt>Clobbers</dt>
	<dd>None</dd>
</dl>

 Initializes the number of locals specified by the byte after the CALL to this function. Locals may
 compile calls to this function depending on inlining mode and number of locals.
 
 Variants:
 * do_init_locals
 * do_init_locals_1
 * do_init_locals_2
 * do_init_locals_3
 * do_init_locals_4
