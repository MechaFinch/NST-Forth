### Interoperability
# interop_init

 `none interop_init(u32 param_stack_size, u32 locals_stack_size, u32 user_dict_size, i16 user_dict_padding, i16 stack_padding)`

 Initializes the forth environment. 
 
 | Argument | Description |
 | --- | --- |
 | param_stack_size | Size of the parameter stack, bytes |
 | locals_stack_size | Size of the locals stack, bytes |
 | user_dict_size | Size of the user dictionary, bytes |
 | user_dict_padding | If `HERE` reaches `user_dict_origin + user_dict_size - user_dict_padding`, overflow is detected |
 | stack_padding | If a stack pointer reaches `origin - size + padding`, overflow is detected. <br> If a stack pointer reaches `origin - padding`, underflow is detected |
