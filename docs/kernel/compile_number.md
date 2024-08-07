### Kernel Functions
# compile_number
<dl>
	<dt>Arguments</dt>
	<dd>AH&nbsp;&nbsp;Offset</dd>
	<dd>AL&nbsp;&nbsp;Parameters</dd>
	<dd>BH&nbsp;&nbsp;4-byte prefix</dd>
	<dd>BL&nbsp;&nbsp;3-byte prefix</dd>
	<dd>CH&nbsp;&nbsp;2-byte prefix</dd>
	<dd>CL&nbsp;&nbsp;1-byte prefix</dd>
	<dd>J:I&nbsp;Value</dd>
	<dd>L:K&nbsp;Destination pointer</dd>
	<dt>Returns</dt>
	<dd>C&nbsp;&nbsp;&nbsp;Size of number, or 0 if value too large</dd>
	<dd>L:K&nbsp;Destination + Offset + Size</dd>
	<dt>Clobbers</dt>
	<dd>None</dd>
</dl>

 Places a prefix and a value at the destination pointer.
 
 If the value is to be computed, the placed value is 
 ```
 (destination + offset + size) - raw value
 ```

 Prefix is placed at \[destination\]

 Value is placed at \[destination + offset\]

 | Parameter Bit | Description |
 | ------------- | ----------- |
 | 0 | If set, 1-byte value allowed |
 | 1 | If set, 2-byte value allowed |
 | 2 | If set, 3-byte value allowed |
 | 3 | If set, 4-byte value allowed |
 | 4 | If set, signed. If clear, unsigned |
 | 5 | If set, compute signed value. If clear, use raw value |