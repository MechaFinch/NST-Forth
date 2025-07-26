### Kernel Functions
# compile_word
<dl>
	<dt>Arguments</dt>
	<dd>J:I&nbsp;Header pointer</dd>
	<dt>Returns</dt>
	<dd>None</dd>
	<dt>Clobbers</dt>
	<dd>B:C</dd>
</dl>

 Perform the compilation semantics of a word.
 
 If the word is immediate, execute it. Otherwise, inline or compile a CALL to the word according to
 the word's inline status and the current inlining state.
