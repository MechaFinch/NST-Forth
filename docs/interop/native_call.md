### Interoperability
# NATIVE-CALL

 ( i\*x u1\*x u1\*u u1 func-ptr -- j\*x return-val )

 Calls native function func-ptr with arguments described by u1 u1*u.
 D:A is returned. If the return type of func-ptr is smaller than u32, the upper bytes of return-val will be invalid.
 
 u1 is the number of arguments. u1\*u is u argument sizes which may be 1, 2, or 4 bytes. For each argument in u1*x
 the lower u bytes are pushed onto the return stack before func-ptr is called.
 
 Argument values should be pushed onto the parameter stack in the order they appear in the native function header.
