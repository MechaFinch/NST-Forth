
;
; Forth
; OS Edition
;

%include "fakeos/fakeos.asm" as os
%include "math/mathutil.asm" as mutil

; Parameters
; 16k param stack
%define PARAM_PARAM_STACK_SIZE 0x0000_4000
; return stack managed by OS, but keep a size to check
%define PARAM_RETURN_STACK_SIZE 0x0000_4000

; 16k locals stack
%define PARAM_LOCAL_STACK_SIZE 0x0000_4000
; 8k locals dictionary
%define PARAM_LOCAL_DICT_SIZE 0x0000_2000
; 128k user dictionary
%define PARAM_USER_DICT_SIZE 0x0002_0000
; 256 character input buffer
%define PARAM_INPUT_BUFFER_SIZE 128

%define PARAM_USER_DICT_PADDING 1024
%define PARAM_LOCAL_DICT_PADDING 64
%define PARAM_STACK_PADDING 64

; Header flags
%define HFLAG_IMMEDIATE 0x80
%define HFLAG_SMUDGE 0x40
%define HFLAG_INLINE 0x20
%define HMASK_LENGTH 0x1F

%define HFLAG_INLINE_ALWAYS 0x8000
%define HFLAG_INLINE_STRICT 0x4000
%define HMASK_CODE_SIZE 0x3FFF

; Other flags
%define FLAG_TRUE 0xFFFF_FFFF
%define FLAG_FALSE 0x0000_0000

; Local type IDs
%define LTYPE_CHAR_VAL 0
%define LTYPE_CELL_VAL 1
%define LTYPE_DCELL_VAL 2
%define LTYPE_CHAR_VAR 4
%define LTYPE_CELL_VAR 5
%define LTYPE_DCELL_VAR 6

; Characters
%define CHAR_BACKSPACE 0x08
%define CHAR_NEWLINE 0x0A
%define CHAR_ESCAPE 0x1B
%define CHAR_SPACE 0x20
%define CHAR_SINGLE_QUOTE 0x27

; OS defines
%define SYSCALL INT 0x20
%define OS_EXIT 		0x0001
%define OS_DEFER		0x0002
%define OS_MALLOC		0x0010
%define OS_CALLOC		0x0011
%define OS_REALLOC		0x0012
%define OS_RCALLOC		0x0013
%define OS_FREE			0x0014
%define OS_OPEN_FILE	0x0020
%define OS_CLOSE_FILE	0x0021
%define OS_READ_FILE	0x0022
%define OS_WRITE_FILE	0x0023
%define OS_SEEK_FILE	0x0024
%define OS_GET_FILE_POS	0x0025
%define OS_SET_FILE_ATT	0x0026
%define OS_STDIN		0
%define OS_STDOUT		1
%define OS_STDERR		2

; THROW codes
%define TCODE_OK					0
%define TCODE_ABORT					-1
%define TCODE_ABORTS				-2
%define TCODE_PSTACK_OVERFLOW		-3
%define TCODE_PSTACK_UNDERFLOW		-4
%define TCODE_RSTACK_OVERFLOW		-5
%define TCODE_RSTACK_UNDERFLOW		-6
%define TCODE_DICTIONARY_OVERFLOW	-8

%define TCODE_OUT_OF_RANGE			-11

%define TCODE_UNDEFINED_WORD		-13
%define TCODE_COMPILE_ONLY			-14

%define TCODE_ZERO_LENGTH_NAME		-16

%define TCODE_PARSED_OVERFLOW		-18
%define TCODE_NAME_TOO_LONG			-19

%define TCODE_COMPILER_NESTING		-29

%define TCODE_LSTACK_OVERFLOW		-256
%define TCODE_LSTACK_UNDERFLOW		-257
%define TCODE_MALFORMED_LOCALS		-258
%define TCODE_TOO_MANY_LOCALS		-259

; Inlining modes
%define INLINE_MODE_ALWAYS	0
%define INLINE_MODE_STRICT	1
%define INLINE_MODE_NEVER	2



; User Variables
uvar_return_stack_origin:	dp 0
uvar_return_stack_end:		dp 0
uvar_param_stack_origin:	dp 0
uvar_param_stack_end:		dp 0
uvar_term_buffer_start:		dp 0
uvar_term_buffer_size:		dp 0
uvar_input_buffer_start:	dp 0
uvar_input_buffer_size:		dp 0	; maximum size
uvar_input_buffer_contents:	dp 0	; populated size
uvar_input_buffer_index:	dp 0	; >IN
uvar_source_id:				dp 0
uvar_user_dict_origin:		dp 0
uvar_user_dict_end:			dp 0
uvar_inlining_mode:			dp 0	; is inlining enabled
uvar_inlinable:				dp 0	; nonzero if inlinable set
uvar_here:					dp 0
uvar_latest:				dp 0
uvar_state:					dp 0
uvar_base:					dp 0
uvar_exceptions_handler:	dp 0	; points to innermost exception stack frame
uvar_exceptions_string:		dp 0	; points to counted string to display for exception# -2, or custom string for other codes
uvar_exceptions_length:		dp 0	; length of string if not counted
uvar_exceptions_thrower:	dp 0	; points to header of throwing word. Optionally set by the word. 
uvar_locals_stack_origin:	dp 0
uvar_locals_stack_end:		dp 0
uvar_locals_dict_origin:	dp 0
uvar_locals_latest:			dp 0
uvar_locals_here:			dp 0
uvar_locals_count:			dp 0	; current number of locals
uvar_locals_size:			dp 0	; number of bytes of locals



; other
%define DICT_LATEST fhead_else



; TODO
;	words for enabling/disabling/polling inlining
;		
;	inlineable compilation mode INLINABLE:



; Entry
; wahoo
entry:
	; get OS running
	CALL os.init
.start:
	
	; User dictionary, 128k
	MOV A, OS_MALLOC
	MOVW C:D, PARAM_USER_DICT_SIZE
	SYSCALL
	MOVW [uvar_user_dict_origin], D:A
	MOVW [uvar_here], D:A
	LEA D:A, [D:A + (PARAM_USER_DICT_SIZE - PARAM_USER_DICT_PADDING)]
	MOVW [uvar_user_dict_end], D:A
	
	; allocate regions of dynamic memory
	; Locals dictionary, 8k
	MOV A, OS_MALLOC
	MOVW C:D, PARAM_LOCAL_DICT_SIZE
	SYSCALL
	MOVW [uvar_locals_dict_origin], D:A
	MOVW [uvar_locals_here], D:A
	
	; Parameter stack
	MOV A, OS_MALLOC
	MOVW C:D, PARAM_PARAM_STACK_SIZE
	SYSCALL
	LEA D:A, [D:A + PARAM_STACK_PADDING]	; 64 bytes of padding on both ends
	MOVW [uvar_param_stack_end], D:A
	LEA D:A, [D:A + (PARAM_PARAM_STACK_SIZE - (PARAM_STACK_PADDING * 2))]
	MOVW [uvar_param_stack_origin], D:A
	
	; Locals stack
	MOV A, OS_MALLOC
	MOVW C:D, PARAM_LOCAL_STACK_SIZE
	SYSCALL
	LEA D:A, [D:A + PARAM_STACK_PADDING]
	MOVW [uvar_locals_stack_end], D:A
	LEA D:A, [D:A + (PARAM_LOCAL_STACK_SIZE - (PARAM_STACK_PADDING * 2))]
	MOVW [uvar_locals_stack_origin], D:A
	
	; Terminal buffer, 256
	MOV A, OS_MALLOC
	MOVW C:D, PARAM_INPUT_BUFFER_SIZE
	MOVW [uvar_term_buffer_size], C:D
	SYSCALL
	MOVW [uvar_term_buffer_start], D:A
	
	; Reset stufffff
	MOVW D:A, DICT_LATEST
	MOVW [uvar_latest], D:A
	MOVW [uvar_locals_latest], D:A
	
	MOVW D:A, 10
	MOVW [uvar_base], D:A
	
	MOVW D:A, INLINE_MODE_STRICT
	MOVW [uvar_inlining_mode], D:A
	
	MOVW D:A, 0
	MOVW [uvar_inlinable], D:A
	MOVW [uvar_locals_count], D:A
	MOVW [uvar_locals_size], D:A
	MOVW [uvar_exceptions_handler], D:A
	MOVW [uvar_exceptions_string], D:A
	MOVW [uvar_exceptions_thrower], D:A
	
	; start execution
	MOVW D:A, 0
	MOVW L:K, [uvar_locals_stack_origin]
	MOVW BP, [uvar_param_stack_origin]
	
	SUB SP, PARAM_STACK_PADDING
	LEA B:C, [SP - 4]
	MOVW [uvar_return_stack_origin], B:C
	LEA B:C, [SP - (PARAM_RETURN_STACK_SIZE - PARAM_STACK_PADDING)]
	MOVW [uvar_return_stack_end], B:C
	
	CALL fword_quit
	ADD SP, PARAM_STACK_PADDING
	
	JMP entry



;
; KERNEL ROUTINES
;

; print_counted
; Prints the counted string
; Arguments J:I = string ptr
; Returns C = stirng length
; Clobbers B
kernel_print_counted:
	PUSHW D:A
	
	MOVZ C, [J:I]	; get length
	MOV B, 0
	INC I			; point to body
	ICC J
	
	MOV A, OS_WRITE_FILE	; print
	MOV D, OS_STDOUT
	SYSCALL
	
	POPW D:A
	RET



; print_string
; Prints the string
; Arguments J:I = string ptr, B:C = string length
; Returns none
; Clobbers none
kernel_print_string:
	PUSHW D:A
	
	MOV A, OS_WRITE_FILE
	MOV D, OS_STDOUT
	SYSCALL
	
	POPW D:A
	RET



; print_name
; Prints the name of a word
; Argument J:I = header pointer
; Returns B:C
; Clobbers none
kernel_print_name:
	MOVZ C, [J:I + 4]	; length/flags
	AND CL, HMASK_LENGTH
	MOV B, 0
	ADD I, 5
	ICC J
	JMP kernel_print_string
	



; print_inline
; Prints the counted string pointed to by SP, and returns to SP + length + 1
; Clobbers B:C, J:I
kernel_print_inline:
	MOVW J:I, [SP]				; get string
	CALL kernel_print_counted	; print
	
	POPW J:I		; string again
	MOVZ C, [J:I]	; length
	INC C			; add to return
	ADD I, C
	ICC J
	JMPA J:I



; parse_token
; Parses a token from the input buffer
; Argument CL = delimiter
; Returns C = length, J:I = pointer
; Clobbers B
kernel_parse_token:
	PUSHW D:A
	PUSHW L:K
	PUSH CL
	
	; AL = delimiter
	; B = remaining characters
	; C = length
	; J:I = start of string
	; L:K = current place in input buffer
	MOVW J:I, [uvar_input_buffer_start]
	MOVW B:C, [uvar_input_buffer_index]
	ADD I, C	; L:K = J:I = current ptr
	ADC J, B
	MOVW L:K, J:I
	
	MOVW D:A, [uvar_input_buffer_contents]
	SUB A, C	; D:A = remaining chars
	SBB D, B
	MOV B, A	; B = remaining
	MOV C, 0	; C = length
	
	POP AL		; AL = delimiter
	
	; If the delimiter is a space, skip leading whitespace
	CMP AL, CHAR_SPACE
	JNE .find_token_end_loop
	
	; find the start of the token
.skip_leading_loop:
	CALL .sub_fetch_char	; get next char
	JZ .skip_leading_empty
	
	CALL .sub_is_delimiter	; is it a delimiter
	JZ .skip_leading_loop	; if so, keep looking
	
	LEA J:I, [L:K - 1]		; J:I = start of string
	JMP .find_token_end_not_delimiter
	
	; Start of the token found. Find the ending delimiter
.find_token_end_loop:
	CALL .sub_fetch_char	; get next char
	JZ .found_token_end
	
	CALL .sub_is_delimiter	; is it a delimiter
	JZ .found_token_end

	; character wasn't a delimiter
.find_token_end_not_delimiter:
	INC C						; increment length
	JMP .find_token_end_loop	; keep looking
	
.found_token_end:
.skip_leading_empty:
	POPW L:K
	POPW D:A
	RET

; subroutine fetch_char
; B = remaining chars
; L:K = current ptr in input buffer
; Updates B, L:K
; Returns DL = character
; ZF set if no chars available
; Clobbers none
.sub_fetch_char:
	CMP B, 0		; is there anything to fetch
	JZ .sfc_ret
	
	MOV DL, [L:K]	; fetch
	INC K			; increment regs
	ICC L
	DEC B
	
	PUSHW J:I		; increment >IN
	MOVW J:I, [uvar_input_buffer_index]
	INC I
	ICC J
	MOVW [uvar_input_buffer_index], J:I
	POPW J:I
	
	MOV F, 0		; clear ZF
.sfc_ret:
	RET

; subroutine is_delimiter
; AL = delimiter
; DL = character
; ZF set if delimiter
; Clobbers none
.sub_is_delimiter:
	CMP AL, CHAR_SPACE
	JE .space_delimiter
	CMP DL, AL
	RET

.space_delimiter:
	CMP DL, CHAR_SPACE
	CMOVB DL, CHAR_SPACE
	CMP DL, AL
	RET



; search_dict
; Finds a word in the dictionary
; Arguments CL = word length, J:I = word pointer
; Returns J:I = header pointer, or 0
; Clobbers B, CH
kernel_search_dict:
	PUSHW L:K
	; CL = word length
	; J:I = header pointer
	; L:K = word pointer
	MOVW L:K, J:I
	
	CMP byte [uvar_locals_count], 0
	JNZ .use_locals_latest
	
	MOVW J:I, [uvar_latest]
	JMP .loop
	
.use_locals_latest:
	MOVW J:I, [uvar_locals_latest]
	
	; algorithm
	; get length/flags from header
	; check smudge
	; not smudge:
	;	compare name lengths
	;	equal:
	;		compare names
	;		equal:
	;			return
	; smudge or no match:
	;	get link
	;	if zero:
	;		return
	;	otherwise:
	;		loop
.loop:
	MOV BL, [J:I + 4]		; get length/flags
	TST CL, HFLAG_SMUDGE	; is it smudged?
	JNZ .next
	
	AND BL, HMASK_LENGTH	; does it match?
	CMP BL, CL
	JNE .next
	
	; BL = bytes left to compare
	; BH = byte being comapred
	; C = offset
	; J:I = header name
	; L:K = word
	PUSH CL
	MOV C, 0
	ADD I, 5
	ICC J
.compare:
	MOV BH, [L:K + C]	; get char from target
	CMP BH, [J:I + C]	; compare to header name
	JNE .compare_next
	INC C
	DEC BL
	JNZ .compare
	
	; found the word
	POP CL
	SUB I, 5
	DCC J
	JMP .ret

	; word didn't match
.compare_next:
	POP CL
	SUB I, 5
	DCC J

.next:
	MOVW J:I, [J:I]	; get link
	CMP J, 0		; are we done
	JNZ .loop
	CMP I, 0
	JNZ .loop
	
.ret:
	POPW L:K
	RET



; convert_number
; Converts a string to a number
; Arguments C = string length, J:I = string pointer
; Returns C = 1 is successful, 0 if failure, J:I = number
kernel_convert_number:
	PUSHW D:A
	PUSHW L:K
	
	; check string exists
	CMP C, 0
	JZ .fret
	
	; get first char, check for base specifier
	MOVZ D, [J:I]
	CMP DL, '#'
	JE .base_10
	CMP DL, '$'
	JE .base_16
	CMP DL, '%'
	JE .base_2
	CMP DL, CHAR_SINGLE_QUOTE
	JE .character
	
	; no specifier, use BASE
	MOV B, [uvar_base]
	JMP .check_sign

.character:
	; something in the form 'c'
	CMP C, 3
	JNE .fret
	CMP byte [J:I + 2], CHAR_SINGLE_QUOTE
	JNE .fret
	
	MOV C, 1
	MOVZ I, [J:I + 1]
	MOV J, 0
	JMP .ret
	
.base_2:
	MOV B, 2
	JMP .discard_base_char

.base_10:
	MOV B, 10
	JMP .discard_base_char

.base_16:
	MOV B, 16

.discard_base_char:
	INC I
	ICC J
	DEC C
	JZ .fret
	MOV DL, [J:I]
	
	; B = base
	; C = length
	; DL = char
	; J:I = ptr
.check_sign:
	CMP DL, '+'
	JE .positive
	CMP DL, '-'
	JE .negative
	MOV AL, 1
	JMP .start_digits

.negative:
	MOV AL, -1
	JMP .discard_sign_char
	
.positive:
	MOV AL, 1

.discard_sign_char:
	INC I
	ICC J
	DEC C
	JZ .fret
	MOV DL, [J:I]
	
	; finally number crunching
	; AL = sign
	; B = base
	; C = chars left
	; D = char/digit
	; J:I = value
	; L:K = ptr
.start_digits:
	MOVW L:K, J:I
	MOVW J:I, 0

.digit_loop:
	; convert digit 
	CMP DL, '0'	; out of bounds?
	JB .fret
	CMP DL, '9'	; decimal digit?
	JBE .digit_decimal
	
	CMP DL, 'A'	; out of bounds?
	JB .fret
	CMP DL, 'Z'	; capital letter?
	JBE .digit_capital
	
	CMP DL, 'a'	; out of bounds?
	JB .fret
	CMP DL, 'z'	; lowercase?
	JBE .digit_lower
	JMP .fret	; out of bounds

.digit_decimal:
	SUB DL, '0'
	JMP .add

.digit_capital:
	SUB DL, 'A' - 10
	JMP .add

.digit_lower:
	SUB DL, 'a' - 10

.add:
	; check base bounds
	CMP D, B
	JAE .fret
	
	; multiply by base
	MUL J, B		; upper word, save
	PUSH J
	MULH J:I, B		; lower word
	ADD J, [SP]		; full value
	ADD SP, 2
	
	ADD I, D		; add digit
	ICC J
	
	INC K			; inc string
	ICC L
	DEC C
	JZ .done
	MOV DL, [L:K]
	JMP .digit_loop
	
	; yay
.done:
	CMP AL, 0		; negate result if needed
	JGE .was_pos
	
	NOT J
	NEG I
	ICC J
	
.was_pos:
	MOV C, 1
	JMP .ret

.fret:
	MOV C, 0
	
.ret:
	POPW L:K
	POPW D:A
	RET



; compile_number
; Places value at the destination pointer with prefix and variable length
; Arguments
;	AH	Offset
;	AL	Parameters
;	BH	4-byte prefix
;	BL	3-byte prefix
;	CH	2-byte prefix
;	CL	1-byte prefix
;	J:I	Value
;	L:K	Destination pointer
; Returns
;	C	Size of number, or 0 if too large
;	L:K	Destination pointer + offset + size
kernel_compile_number:
	PUSH D
	
	; D:A = value
	; C = parameters
	; J:I = prefixes
	XCHGW B:C, J:I	; J:I = prefixes
	XCHGW B:C, D:A	; D:A = value
	
	; Compute value if needed
	TST CL, 0x20
	JZ .raw_value
	
	; Determine size of offset between destination + offset and value
	PUSHW L:K
	PUSH C
	
	; Compute (coffs + size) = value - (destination + offset)
	MOVS C, CH			; C = offset
	LEA L:K, [L:K + C]	; L:K = destination + offset
	SUB A, K			; D:A = value - (destination + offset)
	SBB D, L
	
	POP C
	POPW L:K
	JS .offset_negative
	
	; difference in [MIN_I8 + 1, MAX_I8 + 1]	= i8  
	; difference in [MIN_I16 + 2, MAX_I16 + 2]	= i16
	; difference in [MIN_I24 + 3, MAX_I24 + 3]	= i24
	; otherwise i32

.offset_positive:
	; difference >= 0 ->
	;	difference <= 0x0000_0080	= i8
	;	difference <= 0x0000_8001	= i16
	;	difference <= 0x0080_0002	= i24
	;	otherwise i32
	CMP D, 0x0000
	JNE .offset_positive_least_i24
	CMP A, 0x8001
	JA .offset_is_i24
	CMP A, 0x0080
	JBE .offset_is_i8
	JMP .offset_is_i16

.offset_positive_least_i24:
	CMP D, 0x0080
	JG .offset_is_i32
	JL .offset_is_i24
	CMP A, 0x0002
	JBE .offset_is_i24
	JMP .offset_is_i32

.offset_negative:
	; difference < 0 ->
	;	difference >= 0xFFFF_FF81	= i8
	;	difference >= 0xFFFF_8002	= i16
	;	difference >= 0xFF80_0003	= i24
	CMP D, 0xFFFF
	JNE .offset_negative_least_i24
	CMP A, 0x8002
	JB .offset_is_i24
	CMP A, 0xFF81
	JAE .offset_is_i8
	JMP .offset_is_i16

.offset_negative_least_i24:
	CMP D, 0xFF80
	JG .offset_is_i24
	JL .offset_is_i32
	CMP A, 0x0003
	JAE .offset_is_i24
	JMP .offset_is_i32

.offset_is_i8:
	TST CL, 0x01
	JZ .offset_is_i16
	
	LEA D:A, [D:A - 1]
	JMP .place_1

.offset_is_i16:
	TST CL, 0x02
	JZ .offset_is_i24
	
	LEA D:A, [D:A - 2]
	JMP .place_2

.offset_is_i24:
	TST CL, 0x04
	JZ .offset_is_i32
	
	LEA D:A, [D:A - 3]
	JMP .place_3

.offset_is_i32:
	TST CL, 0x08
	JZ .no_fit
	
	LEA D:A, [D:A - 4]
	JMP .place_4

	; expected:
	;	CH = input offset
	;	J:I = prefixes
	;	D:A = value
	;	L:K = destination
	
	; Determine the size of Value
.raw_value:
	TST CL, 0x10
	JZ .getsize_unsigned
	TST DH, 0x80
	JNZ .getsize_negative

	; Check for positive numbers
.getsize_positive:
	CMP D, 0x0080
	JGE .is_4
	
	MOV BH, DL
	MOV BL, AH
	CMP B, 0x0080
	JGE .is_3
	
	CMP A, 0x0080
	JGE .is_2
	JMP .is_1

	; Check for negative numbers
.getsize_negative:
	CMP D, 0xFF80
	JL .is_4
	
	MOV BH, DL
	MOV BL, AH
	CMP B, 0xFF80
	JL .is_3
	
	CMP A, 0xFF80
	JL .is_2
	JMP .is_1

; Check for unsigned numbers
.getsize_unsigned:
	CMP DH, 0
	JNZ .is_4
	CMP DL, 0
	JNZ .is_3
	CMP AH, 0
	JNZ .is_2

	; Knowing the minimum size, what's the smallest we can place?
.is_1:
	TST CL, 0x01
	JNZ .place_1

.is_2:
	TST CL, 0x02
	JNZ .place_2

.is_3:
	TST CL, 0x04
	JNZ .place_3

.is_4:
	TST CL, 0x08
	JNZ .place_4

	; doesn't fit
.no_fit:
	MOV C, 0
	JMP .ret
	
.place_4:
	MOVS C, CH			; get offset
	MOV B, J			; get prefix
	MOV [L:K], BH		; place prefix
	LEA L:K, [L:K + C]	; place value
	MOVW [L:K], D:A
	MOV C, 4			; return value
	LEA L:K, [L:K + C]
	JMP .ret

.place_3:
	MOVS C, CH			; get offset
	MOV B, J			; get prefix
	MOV [L:K], BL		; place prefix
	LEA L:K, [L:K + C]	; place value
	MOV [L:K], A
	MOV [L:K + 2], DL
	MOV C, 3			; return value
	LEA L:K, [L:K + C]
	JMP .ret

.place_2:
	MOVS C, CH			; get offset
	MOV B, I			; get prefix
	MOV [L:K], BH		; place prefix
	LEA L:K, [L:K + C]	; place value
	MOV [L:K], A
	MOV C, 2			; return value
	LEA L:K, [L:K + C]
	JMP .ret

.place_1:
	MOVS C, CH			; get offset
	MOV B, I			; get prefix
	MOV [L:K], BL		; place prefix
	LEA L:K, [L:K + C]	; place value
	MOV [L:K], AL
	MOV C, 1			; return value
	INC K
	ICC L

.ret:
	POP D
	RET



; print_char
; Prints a character
; Arguments CL = character
; Returns none
; Clobbers B:C, J:I
kernel_print_char:
	PUSHW D:A
	
	PUSH CL
	MOVW B:C, 1
	MOVW J:I, SP
	MOV A, OS_WRITE_FILE
	MOV D, OS_STDOUT
	SYSCALL
	POP CL

.after:
	POPW D:A
	RET



; print_number
; Prints a number
; Arguments J:I = number, BL = base, BH = signed?
; Returns C = 1 if success, 0 if failure (invalid base)
; Clobbers none
kernel_print_number:
	; validate base
	CMP BL, 1
	JBE .bad_base
	CMP BL, 37
	JGE .bad_base
	
	; print
	CMP I, 0
	JNZ .nonzero
	CMP J, 0
	JNZ .nonzero
	
	; zero
	MOV CL, '0'
	CALL kernel_print_char
	JMP .ret

	; nonzero. check sign if applicable
.nonzero:
	CMP BH, 0
	JZ .unsigned
	
	; signed.
	CMP J, 0
	JNS .unsigned
	
	; negative.
	NOT J		; negate
	NEG I
	ICC J
	
	PUSHW J:I	; leading -
	PUSH BL
	MOV CL, '-'
	CALL kernel_print_char
	POP BL
	POPW J:I

	; Unsigned or positive. 
.unsigned:
	MOV BH, 0		; track number of digits
	MOVW D:A, J:I	; move number for convenience
	
.divloop:
	; divide value by base
	PUSH B
	PUSH ptr 0		; base
	PUSH BL
	PUSHW D:A	; number
	CALL mutil.divmu32	; D:A = quotient, B:C = remainder
	ADD SP, 9
	POP B
	
	; remainder -> digit
	CMP CL, 10
	MOV CH, '0'
	CMOVAE CH, 'A' - 10
	ADD CL, CH
	
	PUSH CL	; push character & increment count
	INC BH
	
	; are we done
	CMP A, 0
	JNZ .divloop
	CMP D, 0
	JNZ .divloop

	; done. print.
.printloop:
	POP CL
	PUSH BH
	CALL kernel_print_char
	POP BH
	
	DEC BH
	JNZ .printloop
	JMP .ret

.bad_base:
	MOV C, 0
	JMP .fret

.ret:
	MOV C, 1
.fret:
	RET



; check_overflow
; Checks the stacks and the dictionary for overflow and underflow, throwing the corresponding exceptions
; Clobbers B:C, J:I
kernel_check_overflow:
	; Check parameter stack
	MOVW B:C, [uvar_param_stack_origin]	; check underflow
	MOVW J:I, BP
	
	CMP J, B
	JG .pstack_underflow
	JL .pstack_no_underflow
	CMP I, C
	JA .pstack_underflow
	
.pstack_no_underflow:
	MOVW B:C, [uvar_param_stack_end]	; check overflow
	CMP J, B
	JG .pstack_ok
	JL .pstack_overflow
	CMP I, C
	JB .pstack_overflow
	
	; Check return stack
.pstack_ok:
	MOVW B:C, [uvar_return_stack_origin]	; check underflow
	MOVW J:I, SP
	
	CMP J, B
	JG .rstack_underflow
	JL .rstack_no_underflow
	CMP I, C
	JA .rstack_underflow
	
.rstack_no_underflow:
	MOVW B:C, [uvar_return_stack_end]		; check overflow
	CMP J, B
	JG .rstack_ok
	JL .rstack_overflow
	CMP I, C
	JB .rstack_overflow
	
	; Check locals stack
.rstack_ok:
	MOVW B:C, [uvar_locals_stack_origin]	; check underflow
	MOVW J:I, L:K
	
	CMP J, B
	JG .lstack_underflow
	JL .lstack_no_underflow
	CMP I, C
	JA .lstack_underflow
	
.lstack_no_underflow:
	MOVW B:C, [uvar_locals_stack_end]		; check overflow
	CMP J, B
	JG .lstack_ok
	JL .lstack_overflow
	CMP I, C
	JB .lstack_overflow
	
	; Check dictionary
.lstack_ok:
	MOVW B:C, [uvar_user_dict_end]			; check overflow
	MOVW J:I, [uvar_here]
	
	CMP J, B
	JG .dictionary_overflow
	JL .dictionary_ok
	CMP I, C
	JA .dictionary_overflow

.dictionary_ok:
	RET

.pstack_overflow:
	BPUSHW D:A
	MOVW D:A, TCODE_PSTACK_OVERFLOW
	JMP fword_throw

.pstack_underflow:
	BPUSHW D:A
	MOVW D:A, TCODE_PSTACK_UNDERFLOW
	JMP fword_throw

.rstack_overflow:
	BPUSHW D:A
	MOVW D:A, TCODE_RSTACK_OVERFLOW
	JMP fword_throw

.rstack_underflow:
	BPUSHW D:A
	MOVW D:A, TCODE_RSTACK_UNDERFLOW
	JMP fword_throw

.lstack_overflow:
	BPUSHW D:A
	MOVW D:A, TCODE_LSTACK_OVERFLOW
	JMP fword_throw

.lstack_underflow:
	BPUSHW D:A
	MOVW D:A, TCODE_LSTACK_UNDERFLOW
	JMP fword_throw

.dictionary_overflow:
	BPUSHW D:A
	MOVW D:A, TCODE_DICTIONARY_OVERFLOW
	JMP fword_throw



; memcopy
; Copy data from one location to another
; Arguments D:A = length, B:C = source, J:I = destination
; Returns none
; Clobbers none
kernel_memcopy:
	PUSHW L:K
	MOVW L:K, D:A
	
	JMP .check_remaining
.loop:
	MOVW D:A, [B:C]	; copy
	MOVW [J:I], D:A
	
	ADD C, 4		; increment pointers
	ICC B
	ADD I, 4
	ICC J
	
	SUB K, 4		; decrement remaining
	DCC L
	
.check_remaining:
	CMP L, 0
	JNZ .loop
	CMP K, 4
	JAE .loop
	
	JMP byte [IP + K]
	db @.last_0
	db @.last_1
	db @.last_2
	db @.last_3

.last_3:
	MOV A, [B:C]
	MOV DL, [B:C + 2]
	MOV [J:I], A
	MOV [J:I + 2], DL
	JMP .ret

.last_2:
	MOV A, [B:C]
	MOV [J:I], A
	JMP .ret

.last_1:
	MOV AL, [B:C]
	MOV [J:I], AL
	JMP .ret

.last_0:	
.ret:
	POPW L:K
	RET



; create_word
; Creates an empty definition with the given name
; Arguments CL = length/flags, J:I = name pointer
; Returns B:C = contents pointer, J:I = header pointer
; Clobbers none
kernel_create_word:
	PUSHW D:A
	PUSHW L:K
	
	; setup regs for memcopy
	; D:A = length
	; B:C = source
	; J:I = dest
	MOVZ A, CL
	MOV D, 0
	MOVW B:C, J:I
	MOVW J:I, [uvar_here]
	PUSHW J:I	; need for return
	
	; place link & header
	MOVW L:K, [uvar_latest]
	MOVW [J:I], L:K
	MOV [J:I + 4], AL
	
	; memcopy name
	AND AL, HMASK_LENGTH	; remove flags
	ADD I, 5				; point to name
	ICC J
	PUSH A					; need for return
	PUSHW J:I
	CALL kernel_memcopy
	
	POPW B:C	; contents pointer
	POP A
	ADD C, A
	ICC B
	POPW J:I	; header pointer
	
	MOVW [uvar_here], B:C	; update HERE
	MOVW [uvar_latest], J:I	; update LATEST
	
	POPW L:K
	POPW D:A
	RET



; create_local
; Creates a local with the given name and type
; Arguments CH = type, CL = name length, J:I = name pointer
; Clobbers B
kernel_create_local:
	PUSHW D:A
	PUSHW L:K
	
	; Create dictionary header, setup for name memcopy
	; D:A = length
	; B:C = source
	; J:I = dest
	PUSH CH
	MOVZ A, CL
	MOV D, 0
	MOVW B:C, J:I
	MOVW J:I, [uvar_locals_here]
	PUSHW J:I	; for updating LOCALS_LATEST
	
	; place link
	CMP byte [uvar_locals_count], 0
	JNZ .link_locals_latest

.link_normal_latest:	; link to main dictionary if no other locals
	MOVW L:K, [uvar_latest]
	MOVW [J:I], L:K
	JMP .place_length

.link_locals_latest:
	MOVW L:K, [uvar_locals_latest]
	MOVW [J:I], L:K

.place_length:
	OR AL, HFLAG_IMMEDIATE
	MOV [J:I + 4], AL
	AND AL, HMASK_LENGTH
	
	; memcopy name
	ADD I, 5	; point to name
	ICC J
	PUSH A		; save to recover contents pointer
	PUSHW J:I
	CALL kernel_memcopy
	
	POPW B:C	; contents pointer
	POP A
	ADD C, A
	ICC B
	
	POPW J:I	; update LOCALS_LATEST
	MOVW [uvar_locals_latest], J:I
	
	; place body
	MOV AL, 0x0A	; MOV C, i16
	POP DH
	MOV DL, 0		; offset
	MOV [B:C], AL
	MOV [B:C + 1], D
	
	LEA L:K, [B:C + 3]		; location of JMP
	MOV A, 0x01_3B			; offset 1; compute; signed; 4, 2, 1 allowed
	MOVW B:C, 0xDC_00_DB_DA	; JMP <i32, i16, i8>
	MOVW J:I, kernel_compile_local
	CALL kernel_compile_number
	; L:K = LOCALS_HERE
	MOVW [uvar_locals_here], L:K
	
	; update local offsets
	MOV DL, 4
	MOVW L:K, [uvar_locals_latest]
	MOVZ I, [uvar_locals_count]
	INC I
	JMP .update_loop_check

.update_loop:
	; get to body
	LEA B:C, [L:K + 6]	; length/flags
	MOVZ A, [B:C - 2]
	AND AL, HMASK_LENGTH
	LEA B:C, [B:C + A]	; points to offset
	
	ADD [B:C], DL

	; are we done
.update_loop_check:
	MOVW L:K, [L:K]	; next header
	DEC I
	JNZ .update_loop
	
	INC byte [uvar_locals_count]
	ADD [uvar_locals_size], DL
	
	CMP byte [uvar_locals_size], byte 0x80
	JA .too_many_locals
	
	POPW L:K
	POPW D:A
	RET

.too_many_locals:
	BPUSHW D:A
	MOVW D:A, TCODE_TOO_MANY_LOCALS
	JMP fword_throw


; init_locals
; Compiles code to initialize the most recent n locals
; Arguments CL = n
; Clobbers B, CH, J:I
kernel_init_locals:
	CMP CL, 0	; are we actually doing anything
	JZ .fret
	
	PUSHW D:A
	PUSHW L:K
	
	CMP CL, 4
	JA .compile_memcopy
	
	; if in no inlining mode, use function calls
	CMP byte [uvar_inlining_mode], INLINE_MODE_NEVER
	JE .compile_short_function
	
	; if in strict inlining mode, use function calls for 2-4
	CMP byte [uvar_inlining_mode], INLINE_MODE_STRICT
	JNE .compile_inline
	
	CMP CL, 1
	JE .compile_inline

.compile_short_function:
	; compile:
	; CALL kernel_do_init_locals_n
	MOVZ C, CL
	MOVW J:I, [.function_table + C*4]
	
	MOV A, 0x01_3B					; offset 1; compute difference; signed; 4, 2, 1 bytes allowed
	MOVW B:C, 0xD6_00_D5_D4			; CALL i32, n/a, CALL i16, CALL i8
	MOVW L:K, [uvar_here]			; destination
	CALL kernel_compile_number		; L:K = HERE
	
	MOVW [uvar_here], L:K
	JMP .ret

.function_table:
	dp 0
	dp kernel_do_init_locals_1
	dp kernel_do_init_locals_2
	dp kernel_do_init_locals_3
	dp kernel_do_init_locals_4
	
.compile_inline:
	; <= 4 locals
	; 4 + 4n bytes
	; SUB K, bytes			2
	; DCC L					1
	; MOVW [L:K], D:A		3
	; BPOPW [L:K + offset]	4, for each local except last
	; BPOPW D:A				2
	PUSH CL
	MOV CH, CL		; CH = bytes
	SHL CH, 2
	MOV CL, 0x86	; C = SUB K, bytes
	MOV B, 0x2B_8F	; B = DCC L; MOVW
	
	MOVW J:I, [uvar_here]
	MOVW [J:I], B:C
	
	MOV C, 0x28_46	; [L:K], D:A
	MOV [J:I + 4], C
	
	ADD I, 6
	ICC J
	MOVW B:C, 0x04_28_47_57	; BPOPW [L:K + offset], BH = offset
	JMP .popw_loop_dec
	
.popw_loop:
	MOVW [J:I], B:C
	ADD I, 4
	ICC J
	ADD BH, 4

.popw_loop_dec:
	DEC byte [SP]
	JNZ .popw_loop
	ADD SP, 1
	
	MOV C, 0x00_57	; BPOPW D:A
	MOV [J:I], C
	ADD I, 2
	ICC J
	MOVW [uvar_here], J:I
	JMP .ret
	
	; > 4 locals, compile a memcopy call
	; CALL kernel_do_init_locals
	; db bytes
.compile_memcopy:
	MOV CH, CL		; CH = bytes
	SHL CH, 2
	PUSH CH
	
	MOV A, 0x01_3B					; offset 1; compute difference; signed; 4, 2, 1 bytes allowed
	MOVW B:C, 0xD6_00_D5_D4			; CALL i32, n/a, CALL i16, CALL i8
	MOVW L:K, [uvar_here]			; destination
	MOVW J:I, kernel_do_init_locals	; value
	CALL kernel_compile_number		; L:K = HERE
	
	POP CH			; place argument
	MOV [L:K], CH
	
	INC K			; update HERE
	ICC L
	MOVW [uvar_here], L:K
	
.ret:
	POPW L:K
	POPW D:A
.fret:
	RET



; do_init_locals:
; Init n bytes of locals, n is an inline byte
kernel_do_init_locals:
	MOVW J:I, [SP]	; get argument & return address
	
	MOVZ C, [J:I]
	SUB K, C	; make space on locals stack
	DCC L
	
	PUSH C
	BPUSHW D:A		; memcopy from param to local
	MOVZ D:A, C		; length
	MOVW B:C, BP	; source
	MOVW J:I, L:K	; destomatopm
	CALL kernel_memcopy
	
	POP C			; pop from param stack
	LEA BP, [BP + C]
	BPOPW D:A

	POPW J:I	; return & skip argument
	INC I
	ICC J
	JMPA J:I



; do_init_locals_1:
; Init 1 local (4 bytes)
kernel_do_init_locals_1:
	SUB K, 4
	DCC L
	MOVW [L:K], D:A
	BPOPW D:A
	RET



; do_init_locals_2:
; Init 2 locals (8 bytes)
kernel_do_init_locals_2:
	SUB K, 8
	DCC L
	MOVW [L:K], D:A
	BPOPW ptr [L:K + 4]
	BPOPW D:A
	RET



; do_init_locals_3:
; Init 3 locals (12 bytes)
kernel_do_init_locals_3:
	SUB K, 12
	DCC L
	MOVW [L:K], D:A
	BPOPW ptr [L:K + 4]
	BPOPW ptr [L:K + 8]
	BPOPW D:A
	RET



; do_init_locals_4:
; Init 4 locals (16 bytes)
kernel_do_init_locals_4:
	SUB K, 16
	DCC L
	MOVW [L:K], D:A
	BPOPW ptr [L:K + 4]
	BPOPW ptr [L:K + 8]
	BPOPW ptr [L:K + 12]
	BPOPW D:A
	RET



; compile_remove_locals
; Compiles code to remove the given number of locals from the locals stack. Does not affect definitions.
; Arguments CL = n
; Returns J:I = HERE
; Clobbers C
kernel_compile_remove_locals:
	MOVW J:I, [uvar_here]
	CMP CL, 0
	JE .fret
	
	; compile:
	; ADD K, bytes
	; ICC L
	MOV CH, CL
	MOV CL, 0x76
	MOV [J:I], C
	
	MOV CL, 0x7F
	MOV [J:I + 2], CL
	
	ADD I, 3
	ICC J
	MOVW [uvar_here], J:I
	
.fret:
	RET



; remove_locals
; Removes the given number of locals, and compiles code to remove them from the locals stack
; Arguments CL = n
; Clobbers B, CH, J:I
kernel_remove_locals:
	CMP CL, 0
	JE .fret
	
	; compile removal
	PUSH CL
	CALL kernel_compile_remove_locals
	
	; remove locals
	MOV CL, [SP]
	MOV CH, CL
	SHL CH, 2
	SUB [uvar_locals_size], CH
	SUB [uvar_locals_count], CL
	MOVW J:I, [uvar_locals_latest]
.get_latest_loop:
	MOVW J:I, [J:I]
	DEC CL
	JNZ .get_latest_loop
	
	MOVW [uvar_locals_latest], J:I

	; decrement remaining offsets
	POP CL		; CL = decrement amount, CH = counter
	SHL CL, 2
	MOV CH, [uvar_locals_count]
	INC CH
	JMP .dec_offset_loop_check
	
.dec_offs_loop:
	MOVZ B, [J:I + 4]	; get offset from header ptr to offset field
	AND BL, HMASK_LENGTH
	ADD B, 6
	
	SUB [J:I + B], CL	; decrement
	
	MOVW J:I, [J:I]		; next

.dec_offset_loop_check:
	DEC CH
	JNZ .dec_offs_loop
	

.fret:
	RET



; reset_locals
; Resets the locals dictionary
; Clobbers B:C
kernel_reset_locals:
	MOVW B:C, 0
	MOVW [uvar_locals_count], B:C
	MOVW [uvar_locals_size], B:C
	
	MOVW B:C, [uvar_latest]
	MOVW [uvar_locals_latest], B:C
	
	MOVW B:C, [uvar_locals_dict_origin]
	MOVW [uvar_locals_here], B:C
	RET



; compile_local
; Compiles the action of a local
; Arguments CH = type, CL = offset
; Clobbers B, J:I
kernel_compile_local:
	CMP byte [uvar_inlining_mode], INLINE_MODE_NEVER
	JNE .inline
	
	PUSHW D:A
	PUSHW L:K
	
	; compile:
	; CALL kernel_do_get_local_(val/addr)
	TST CH, 0x04	; value or variable?
	JZ .func_val

.func_var:
	MOVW J:I, kernel_do_get_local_addr
	JMP .compile_function

.func_val:
	MOVW J:I, kernel_do_get_local_val
	
.compile_function:
	PUSH CL
	
	MOV A, 0x01_3B					; offset 1; compute difference; signed; 4, 2, 1 bytes allowed
	MOVW B:C, 0xD6_00_D5_D4			; CALL i32, n/a, CALL i16, CALL i8
	MOVW L:K, [uvar_here]			; destination
	CALL kernel_compile_number		; L:K = HERE
	
	POP CL	; place argument
	MOV [L:K], CL
	
	INC K	; update HERE
	ICC L
	MOVW [uvar_here], L:K
	
	POPW L:K
	POPW D:A
	JMP .ret

.inline:
	; compile:
	; BPUSHW D:A
	MOVW J:I, [uvar_here]
	MOV B, 0x00_53	; BPUSHW D:A
	MOV [J:I], B
	
	MOV BH, CL		; offset
	MOV BL, 0x28	; L:K + i8
	
	TST CH, 0x04	; value or variable?
	JZ .val

	; variable locals
	; compile:
	; LEA D:A, [L:K + offset]
	MOV C, 0x43_6B	; LEA D:A, [bio]
	MOVW [J:I + 2], B:C
	JMP .end

	; value locals
.val:
	; compile:
	; MOVW D:A, [L:K + offset]
	MOV C, 0x43_2B	; MOVW D:A, [bio]
	MOVW [J:I + 2], B:C
	
.end:
	ADD I, 6
	ICC J
	MOVW [uvar_here], J:I

.ret:
	RET



; do_get_local_val
; Gets the value of the local specified by the byte after the CALL
kernel_do_get_local_val:
	MOVW J:I, [SP]	; return address - 1
	MOVZ C, [J:I]	; argument
	
	BPUSHW D:A		; push & get value
	MOVW D:A, [L:K + C]
	
	INC I			; return
	ICC J
	JMPA J:I



; do_get_local_addr
; Gets the address of the local specified by the byte after the CALL
kernel_do_get_local_addr:
	MOVW J:I, [SP]	; return address - 1
	MOVZ C, [J:I]	; argument
	
	BPUSHW D:A		; push & get value
	LEA D:A, [L:K + C]
	
	INC I			; return
	ICC J
	JMPA J:I



; get_body
; Gets the body address of the given header
; Arguments J:I = header pointer
; Returns J:I = body pointer
; Clobbers B
kernel_get_body:
	MOVZ B, [J:I + 4]		; length/flags
	AND BL, HMASK_LENGTH
	LEA J:I, [J:I + B + 5]	; header -> body
	RET



;
; DICTIONARY START
;

; REFILL ( -- flag )
; Attempt to fill the input buffer from the input source
; Returns a true flag if successful, false otherwise
fhead_refill:
	dp 0	; end of dict
	db 6
	db "REFILL"
fword_refill:
	; check SOURCE-ID
	; -1: string, do nothing and return false
	;  0: terminal, syscall for input
	MOVW B:C, [uvar_source_id]
	OR B, C
	JNZ .string
	
	; terminal. syscall for input
	BPUSHW D:A
	
	MOV A, OS_READ_FILE
	MOV D, OS_STDIN
	MOVW B:C, [uvar_input_buffer_size]
	MOVW J:I, [uvar_input_buffer_start]
	SYSCALL
	
	MOVW [uvar_input_buffer_contents], D:A
	MOVZ A, 0
	MOVZ [uvar_input_buffer_index], A
	MOVW D:A, FLAG_TRUE
	RET

.string:
	; string. do nothing and return false
	BPUSHW D:A
	MOVW D:A, FLAG_FALSE
	RET



; BYE ( -- )
; Exits to OS
fhead_bye:
	dp fhead_refill
	db 3
	db "BYE"
fword_bye:
	MOV A, OS_EXIT
	SYSCALL



; INTERPRET
; Interprets as described in section 3.4 of the ANS standard standard, with fancier compilation
; Until parse arae empty:
;	Parse a token
;	FIND the token
;	If found:
;		If interpreting:
;			Execute the word
;		If compiling:
;			If word is immediate:
;				Execute the word
;			If word is inline and INLINING is true and (word is strict or INLINE_STRICT is false):
;				Inline the word
;			Otherwise:
;				Compile the word
;	Otherwise:
;		Attempt to convert to a number
;		If successful:
;			If interpreting:
;				Push the number
;			If compiling:
;				Compile a literal of the number
;		Otherwise:
;			Display an error and ABORT
fhead_interpret:
	dp fhead_bye
	db 9
	db "INTERPRET"
fword_interpret:
	; Parse a token
	; C = token length
	; J:I = token pointer
	MOV CL, CHAR_SPACE
	CALL kernel_parse_token
	
	CMP C, 0	; parse area empty?
	JZ .ret
	
	; save token
	PUSH C
	PUSHW J:I
	
	; not empty. try to FIND the word
	CALL kernel_search_dict
	
	; debug: display if we found it
	CMP J, 0
	JNZ .found
	CMP I, 0
	JNZ .found

.not_found:
	MOVW J:I, [SP]				; get token
	MOV C, [SP + 4]
	
	CALL kernel_convert_number	; attempt number conversion
	
	CMP C, 0
	JZ .error
	
	ADD SP, 6					; discard token if successful
	
	CMP byte [uvar_state], 0	; check STATE
	JZ .interpret_literal

.compile_literal:
	; place number HERE
	PUSH A
	PUSHW L:K
	
	MOVW L:K, [uvar_here]	; place BPUSHW D:A
	MOV A, 0x00_53
	MOV [L:K], A
	ADD K, 2
	ICC L
	
	MOV A, 0x021A		; offset 2, signed, 2/4 allowed
	MOV B, 0x2B40		; prefix 4 = MOVW, also RIM
	MOV CH, 0x02		; prefix 2 = MOVS
	MOV [L:K + 1], BL	; place RIM
	CALL kernel_compile_number
	
	; update HERE
	MOVW [uvar_here], L:K
	
	POPW L:K
	POP A
	JMP .repeat

.interpret_literal:
	; place on stack & done
	BPUSHW D:A
	MOVW D:A, J:I
	JMP .repeat

	; token is neither number nor word
.error:
	POPW J:I	; get token
	POP C
	MOV B, 0
	
	MOVW [uvar_exceptions_string], J:I	; save token for exception
	MOVW [uvar_exceptions_length], B:C
	
	BPUSHW D:A
	MOVW D:A, TCODE_UNDEFINED_WORD
	JMP fword_throw

	; token is a word. 
.found:
	ADD SP, 6					; discard token
	CMP byte [uvar_state], 0	; are we interpreting
	JZ .interpret_word

.compile_word:
	MOV CL, [J:I + 4]		; length/flags
	TST CL, HFLAG_IMMEDIATE	; immediate?
	JNZ .interpret_word
	
	PUSH CL
	TST CL, HFLAG_INLINE	; get body pointer
	MOV CH, 5
	CMOVNZ CH, 7
	
	AND CL, HMASK_LENGTH
	ADD CL, CH
	MOV CH, 0
	
	ADD I, C
	ICC J
	
	POP CL
	TST CL, HFLAG_INLINE	; inline or compile?
	JZ .compile_word_not_inline
	
	MOV B, [J:I - 2]				; get inline size
	TST B, HFLAG_INLINE_ALWAYS		; INLINE_ALWAYS overrides mode
	JNZ .compile_word_inline
	
	MOV CL, [uvar_inlining_mode]	; check mode
	CMP CL, INLINE_MODE_NEVER
	JE .compile_word_not_inline
	
	TST B, HFLAG_INLINE_STRICT		; if not NEVER, INLINE_STRICT does inlining
	JNZ .compile_word_inline
	
	CMP CL, INLINE_MODE_ALWAYS		; word isn't strict or always, inline as specified
	JNE .compile_word_not_inline

.compile_word_inline:
	PUSHW D:A
	
	AND B, HMASK_CODE_SIZE	; D:A = length
	MOVZ D:A, B
	MOVW B:C, J:I			; B:C = source
	MOVW J:I, [uvar_here]	; J:I = destination
	
	ADD I, A				; update HERE
	ADC J, D
	XCHGW J:I, [uvar_here]
	
	CALL kernel_memcopy		; copy
	
	POPW D:A
	JMP .repeat

.compile_word_not_inline:
	CMP byte [uvar_inlinable], 0	; if INLINABLE is nonzero, dont use relative stuff
	JNZ .compile_word_inlinable

.compile_word_non_inlinable:
	PUSH A
	PUSHW L:K
	
	; Compile CALL <word>
	MOV A, 0x01_3B			; offset 1; compute difference; signed; 4, 2, 1 bytes allowed
	MOVW B:C, 0xD6_00_D5_D4	; CALL i32, n/a, CALL i16, CALL i8
	MOVW L:K, [uvar_here]	; destination
	CALL kernel_compile_number
	MOVW [uvar_here], L:K	; and update HERE
	
	POPW L:K
	POP A
	JMP .repeat

.compile_word_inlinable:
	; Compile CALLA <word>
	PUSH DL
	
	MOVW B:C, [uvar_here]
	MOV DL, 0xD8		; CALLA i32
	MOV [B:C], DL		; opcode
	MOVW [B:C + 1], J:I	; pointer
	
	ADD C, 5	; update HERE
	ICC B
	MOVW [uvar_here], B:C
	
	POP DL
	JMP .repeat

	; run the word
.interpret_word:
	MOV CL, [J:I + 4]		; get length/flags
	TST CL, HFLAG_INLINE	; skip 2 bytes if inlinable
	MOV CH, 5
	CMOVNZ CH, 7
	
	AND CL, HMASK_LENGTH	; C = name length + header size
	ADD CL, CH			
	MOV CH, 0
	
	ADD I, C				; call the word
	ICC J
	CALLA J:I

.repeat:
	CALL kernel_check_overflow
	JMP fword_interpret

.ret:
	RET



; DOT ( n -- )
; Displays n
fhead_dot:
	dp fhead_interpret
	db 1
	db "."
fword_dot:
	; print n
	MOV BH, 1					; signed
	MOV BL, [uvar_base]			; use base
	MOVW J:I, D:A				; number
	CALL kernel_print_number	; print
	BPOPW D:A					; pop
	
	; print space
	CALL fword_space
	
	; good time for this
	CALL kernel_check_overflow
	RET



; UDOT ( u -- )
; Display u
fhead_udot:
	dp fhead_dot
	db 2
	db "U."
fword_udot:
	; print u
	MOV BH, 0					; unsigned
	MOV BL, [uvar_base]			; use base
	MOVW J:I, D:A				; number
	CALL kernel_print_number	; print
	BPOPW D:A					; pop
	
	CALL fword_space			; space
	
	CALL kernel_check_overflow
	RET



; CR ( -- )
; Print a newline
fhead_cr:
	dp fhead_udot
	db 2
	db "CR"
fword_cr:
	MOV CL, CHAR_NEWLINE
	CALL kernel_print_char
	RET



; SPACE ( -- )
; Prints a space
fhead_space:
	dp fhead_cr
	db 5
	db "SPACE"
fword_space:
	MOV CL, CHAR_SPACE
	CALL kernel_print_char
	RET



; SPACES ( n -- )
; Prints n spaces for n > 0
fhead_spaces:
	CMP D, 0
	JL .done
	CMP A, 0
	JE .done

.loop:
	MOV CL, CHAR_SPACE
	CALL kernel_print_char
	
	DEC A
	DCC D
	JNZ .loop
	CMP A, 0
	JNZ .loop

.done:
	BPOPW D:A
	RET



; EMIT ( x -- )
; Prints x
fhead_emit:
	dp fhead_space
	db 4
	db "EMIT"
fword_emit:
	MOV CL, AL
	CALL kernel_print_char
	
	BPOPW D:A
	RET



; TYPE ( c-addr u -- )
; Prints u characters from c-addr
fhead_type:
	dp fhead_emit
	db 4
	db "TYPE"
fword_type:
	MOVW B:C, D:A
	MOVW J:I, [BP]
	MOV A, OS_WRITE_FILE
	MOV D, OS_STDOUT
	SYSCALL
	
	ADD BP, 4
	BPOPW D:A
	RET



; CATCH ( xt -- exception# | 0 )
; Execute xt and catch any exception it might throw
fhead_catch:
	dp fhead_type
	db 5
	db "CATCH"
fword_catch:
	MOVW J:I, [uvar_exceptions_handler]
	
	PUSHW BP							; save psp
	PUSHW L:K							; save lsp
	PUSHW J:I							; save prev. handler
	MOVW [uvar_exceptions_handler], SP	; set handler
	
	MOVW B:C, D:A	; execute xt
	BPOPW D:A
	CALLA B:C
	
	POPW B:C	; restore prev. handler
	MOVW [uvar_exceptions_handler], B:C
	ADD SP, 8	; discard saved lsp & psp
	
	BPUSHW D:A	; signal no exception
	MOVW D:A, 0
	RET



; THROW ( ? exception# -- ? exception# )
; Throw an exception.
fhead_throw:
	dp fhead_catch
	db 5
	db "THROW"
fword_throw:
	CMP A, 0
	JNZ .nonzero
	CMP D, 0
	JNZ .nonzero
	
	; exception 0 = no throw
	BPOPW D:A
	RET

	; return to saved context
.nonzero:
	MOVW SP, [uvar_exceptions_handler]	; get SP
	POPW ptr [uvar_exceptions_handler]	; pop prev. handler
	POPW L:K							; pop lsp
	POPW BP								; pop psp
	RET									; return to CATCH caller



; ABORT ( ? -- ? )
; Perform -1 THROW
fhead_abort:
	dp fhead_throw
	db 5
	db "ABORT"
fword_abort:
	BPUSHW D:A
	MOVW D:A, -1
	JMP fword_throw



; LBRACKET ( -- )
; Enter interpretation state
fhead_lbracket:
	dp fhead_abort
	db 1 | HFLAG_IMMEDIATE
	db "["
fword_lbracket:
	MOVZ B:C, 0
	MOVW [uvar_state], B:C
	RET



; RBRACKET ( -- )
; Enter compilation state
fhead_rbracket:
	dp fhead_lbracket
	db 1
	db "]"
fword_rbracket:
	MOVZ B:C, 1
	MOVW [uvar_state], B:C
	RET



; QUIT ( -- ) (R: i*x -- )
; Reset return stack & input source, interpret
fhead_quit:
	dp fhead_rbracket
	db 4
	db "QUIT"
fword_quit:
	; Reset return stack & input
	MOVW SP, [uvar_return_stack_origin]
	
	MOVW B:C, [uvar_term_buffer_start]	; set input to terminal
	MOVW [uvar_input_buffer_start], B:C
	MOVW B:C, [uvar_term_buffer_size]
	MOVW [uvar_input_buffer_size], B:C
	MOVW B:C, 0
	MOVW [uvar_input_buffer_contents], B:C
	MOVW [uvar_input_buffer_index], B:C
	MOVW [uvar_source_id], B:C
	
	; STATE <= interpret
	CALL fword_lbracket
	
	; Interpretation loop
.loop:
	; fill input buffer
	CALL fword_refill
	CMP A, 0
	BPOPW D:A
	JE fword_bye
	
	; interpret it
	BPUSHW D:A
	MOVW D:A, fword_interpret
	CALL fword_catch
	
	; exception handling
	CMP D, 0
	JG .exception_unknown
	JZ .exception_nonnegative
	CMP D, -1
	JNE .exception_unknown
	
.exception_nonnegative:
	CMP A, 0
	JE .exception_ok
	JG .exception_unknown
	
	CMP A, TCODE_DICTIONARY_OVERFLOW
	JGE .exception_table
	
	CMP A, TCODE_OUT_OF_RANGE
	JE .exception_out_of_range
	
	CMP A, TCODE_UNDEFINED_WORD
	JE .exception_undef_word
	CMP A, TCODE_COMPILE_ONLY
	JE .exception_compile_only
	
	CMP A, TCODE_ZERO_LENGTH_NAME
	JE .exception_zero_length_name
	
	CMP A, TCODE_PARSED_OVERFLOW
	JE .exception_parsed_overflow
	CMP A, TCODE_NAME_TOO_LONG
	JE .exception_name_too_long
	
	CMP A, TCODE_COMPILER_NESTING
	JE .exception_compiler_nesting
	
	CMP A, TCODE_LSTACK_OVERFLOW
	JE .exception_lstack_overflow
	CMP A, TCODE_LSTACK_UNDERFLOW
	JE .exception_lstack_underflow
	CMP A, TCODE_MALFORMED_LOCALS
	JE .exception_locals_malformed
	CMP A, TCODE_TOO_MANY_LOCALS
	JE .exception_locals_too_many
	
	; unknown exception
.exception_unknown:
	CALL kernel_print_inline
	db 20, "Uncaught exception: "
	
	MOV B, 0x010A	; signed decimal
	MOVW J:I, D:A
	CALL kernel_print_number
	CALL fword_cr
	
	JMP .exception_end

	; Continuous exceptions, use a jump table
.exception_table:
	MOV I, A
	NOT I	; abs(exception) - 1
	SHL I, 1
	JMP word [IP + I]
	dw @.exception_abort
	dw @.exception_abort_string
	dw @.exception_pstack_overflow
	dw @.exception_pstack_underflow
	dw @.exception_rstack_overflow
	dw @.exception_rstack_underflow
	dw @.exception_unknown
	dw @.exception_dictionary_overflow
	
	; display "ok." if in interpretation state
.exception_ok:
	CMP byte [uvar_state], 0
	JNE .cont
	
	CALL kernel_print_inline
	db 4, "ok.", CHAR_NEWLINE
	JMP .cont

	; abort. Say so.
.exception_abort:
	CALL kernel_print_inline
	db 9, "Aborted.", CHAR_NEWLINE
	JMP .exception_end

	; Aborted with a string
.exception_abort_string:
	MOVW J:I, [uvar_exceptions_string]
	CALL kernel_print_counted
	CALL fword_cr
	JMP .exception_end

.exception_pstack_overflow:
	CALL kernel_print_inline
	db 25, "Aborted: Stack overflow.", CHAR_NEWLINE
	JMP .exception_end
	
.exception_pstack_underflow:
	CALL kernel_print_inline
	db 26, "Aborted: Stack underflow.", CHAR_NEWLINE
	JMP .exception_end
	
.exception_rstack_overflow:
	CALL kernel_print_inline
	db 32, "Aborted: Return stack overflow.", CHAR_NEWLINE
	JMP .exception_end
	
.exception_rstack_underflow:
	CALL kernel_print_inline
	db 33, "Aborted: Return stack underflow.", CHAR_NEWLINE
	JMP .exception_end
	
.exception_lstack_overflow:
	CALL kernel_print_inline
	db 32, "Aborted: Locals stack overflow.", CHAR_NEWLINE
	JMP .exception_end
	
.exception_lstack_underflow:
	CALL kernel_print_inline
	db 33, "Aborted: Locals stack underflow.", CHAR_NEWLINE
	JMP .exception_end

.exception_locals_malformed:
	CALL kernel_print_inline
	db 38, "Aborted: Malformed locals definition.", CHAR_NEWLINE
	JMP .exception_end

.exception_locals_too_many:
	CALL kernel_print_inline
	db 26, "Aborted: Too many locals.", CHAR_NEWLINE
	JMP .exception_end
	
.exception_dictionary_overflow:
	CALL kernel_print_inline
	db 30, "Aborted: Dictionary overflow.", CHAR_NEWLINE
	JMP .exception_end

.exception_out_of_range:
	CALL kernel_print_inline
	db 30, "Aborted: Result out of range.", CHAR_NEWLINE
	JMP .exception_end

.exception_undef_word:
	CALL kernel_print_inline			; start of message
	db 23, "Aborted: Undefined word"
	
	; if there's a non-counted string, consume that as the word name
	MOVZ B:C, [uvar_exceptions_length]
	CMP C, 0
	JZ .exception_undef_word_noname
	
	PUSHW B:C
	CALL kernel_print_inline
	db 2, ": "
	
	POPW B:C
	MOVW J:I, [uvar_exceptions_string]
	CALL kernel_print_string
	
	MOV CL, CHAR_NEWLINE
	CALL kernel_print_char
	
	MOVW B:C, 0	; consume
	MOVW [uvar_exceptions_length], B:C
	MOVW [uvar_exceptions_string], B:C
	JMP .exception_end

.exception_undef_word_noname:
	CALL kernel_print_inline
	db 2, ".", CHAR_NEWLINE
	JMP .exception_end

.exception_compile_only:
	CALL kernel_print_inline
	db 38, "Aborted: Interpreted compile-only word"

	; if there's a header pointer, that's the word
	MOVW J:I, [uvar_exceptions_thrower]
	CMP I, 0
	JNZ .exception_compile_only_name
	CMP J, 0
	JNZ .exception_compile_only_name
	
	; no name
	CALL kernel_print_inline
	db 2, ".", CHAR_NEWLINE
	JMP .exception_end

.exception_compile_only_name:
	PUSHW J:I
	CALL kernel_print_inline
	db 2, " '"
	
	POPW J:I
	CALL kernel_print_name
	
	CALL kernel_print_inline
	db 3, "'.", CHAR_NEWLINE
	JMP .exception_end

.exception_zero_length_name:
	CALL kernel_print_inline
	db 27, "Aborted: Zero-length name.", CHAR_NEWLINE
	JMP .exception_end

.exception_parsed_overflow:
	CALL kernel_print_inline
	db 33, "Aborted: Parsed string overflow.", CHAR_NEWLINE

.exception_name_too_long:
	CALL kernel_print_inline
	db 24, "Aborted: Name too long.", CHAR_NEWLINE
	JMP .exception_end
	
.exception_compiler_nesting:
	CALL kernel_print_inline
	db 34, "Aborted: Cannot nest compilation.", CHAR_NEWLINE
	JMP .exception_end

	; end of exception handling
.exception_end:
	BPOPW D:A					; consume exception number
	CALL kernel_reset_locals	; make sure locals aren't a thing
	CALL fword_lbracket			; enter interpretation state
	JMP .loop

.cont:
	BPOPW D:A	; consume exception number
	JMP .loop



; WORDS ( -- )
; Displays all words visible in the dictionary
fhead_words:
	dp fhead_quit
	db 5
	db "WORDS"
fword_words:
	PUSHW L:K
	
	; get LATEST, print
	CMP byte [uvar_locals_count], 0
	JNZ .locals_latest
	
	MOVW L:K, [uvar_latest]
	JMP .loop

.locals_latest:
	MOVW L:K, [uvar_locals_latest]
	
.loop:
	MOVZ C, [L:K + 4]		; get length/flags
	TST CL, HFLAG_SMUDGE	; skip if smudged
	JNZ .next
	
	MOVW J:I, L:K			; print
	CALL kernel_print_name
	
	MOV CL, CHAR_SPACE		; separate
	CALL kernel_print_char
	
.next:
	MOVW L:K, [L:K]			; next header
	CMP K, 0
	JNZ .loop
	CMP L, 0
	JNZ .loop
	
	; done
	MOV CL, CHAR_NEWLINE
	CALL kernel_print_char
	
	POPW L:K
	RET



; COLON IT: ( "<spaces>name" -- colon-sys )
; Create a definition for name. Enter compilation state.
fhead_colon:
	dp fhead_words
	db 1 | HFLAG_IMMEDIATE
	db ":"
fword_colon:
	; check STATE
	CMP byte [uvar_state], 0
	JNZ .compiler_nesting

	; parse name
	MOV CL, CHAR_SPACE
	CALL kernel_parse_token
	
	; validate length
	CMP C, 0
	JZ .no_name
	
	CMP C, HMASK_LENGTH
	JA .name_too_large
	
	; create word
	OR CL, HFLAG_SMUDGE	; add smudge
	CALL kernel_create_word
	
	; return HERE
	BPUSHW D:A
	MOVW D:A, J:I
	
	; set STATE
	MOVW B:C, 1
	MOVW [uvar_state], B:C
	
	; reset locals
	CALL kernel_reset_locals
	RET

	; exceptions
.compiler_nesting:
	BPUSHW D:A
	MOVW D:A, TCODE_COMPILER_NESTING
	JMP fword_throw
	
.no_name:
	BPUSHW D:A
	MOVW D:A, TCODE_ZERO_LENGTH_NAME
	JMP fword_throw

.name_too_large:
	BPUSHW D:A
	MOVW D:A, TCODE_NAME_TOO_LONG
	JMP fword_throw



; COMPILE-ONLY ( nt -- )
; Throws exception -14 if not compiling, setting thrower to nt
fhead_compile_only:
	dp fhead_colon
	db 12
	db "COMPILE-ONLY"
fword_compile_only:
	CMP byte [uvar_state], 0
	JZ .throw
	BPOPW D:A
	RET

.throw:
	MOVW [uvar_exceptions_thrower], D:A
	MOVW D:A, TCODE_COMPILE_ONLY
	JMP fword_throw



; SEMICOLON CT: ( colon-sys -- )
; Ends the current definition. 
fhead_semicolon:
	dp fhead_compile_only
	db 1 | HFLAG_IMMEDIATE
	db ";"
fword_semicolon:
	BPUSHW D:A
	MOVW D:A, fhead_semicolon
	CALL fword_compile_only
	
	; Remove locals
	MOV CL, [uvar_locals_count]
	CALL kernel_remove_locals
	CALL kernel_reset_locals
	
	; Compile RET
	MOVW J:I, [uvar_here]
	MOV CL, 0xE0	; RET
	MOV [J:I], CL
	
	INC I
	ICC J
	MOVW [uvar_here], J:I
	
	; make definition visible
	MOV CL, ~HFLAG_SMUDGE
	AND [D:A + 4], CL
	
	; clear STATE
	MOVW B:C, 0
	MOVW [uvar_state], B:C
	
	; pop colon-sys
	BPOPW D:A
	RET



; DROP ( x -- )
; Drops TOS
fhead_drop:
	dp fhead_semicolon
	db 4 | HFLAG_INLINE
	db "DROP"
	dw HFLAG_INLINE_STRICT | (fword_drop.end - fword_drop)
fword_drop:
	BPOPW D:A	;	2	2
.end:
	RET



; 2DROP ( x1 x2 -- )
; Drops TOS pair
fhead_2drop:
	dp fhead_drop
	db 5 | HFLAG_INLINE
	db "2DROP"
	dw HFLAG_INLINE_STRICT | (fword_2drop.end - fword_2drop)
fword_2drop:
	ADD BP, 4	;	2	2
	BPOPW D:A	;	2	4
.end:
	RET



; DUP ( x -- x x )
; Duplicate x
fhead_dup:
	dp fhead_2drop
	db 3 | HFLAG_INLINE
	db "DUP"
	dw HFLAG_INLINE_STRICT | (fword_dup.end - fword_dup)
fword_dup:
	BPUSHW D:A	;	2	2
.end:
	RET



; ?DUP ( x -- 0 | x x )
; Duplicates x if x != 0
fhead_qdup:
	dp fhead_dup
	db 4
	db "?DUP"
fword_qdup:
	CMP D, 0	;	2	2
	JNZ .dup	;	2	4
	CMP A, 0	;	2	6
	JZ .end		;	2	8
.dup:
	BPUSHW D:A	;	2	10
.end:
	RET



; 2DUP ( x1 x2 -- x1 x2 x1 x2 )
; Duplicate pair x1,x2
fhead_2dup:
	dp fhead_qdup
	db 4 | HFLAG_INLINE
	db "2DUP"
	dw HFLAG_INLINE_STRICT | (fword_2dup.end - fword_2dup)
fword_2dup:
	MOVW B:C, [BP]	; get x1	3	3
	BPUSHW D:A		; place x2	2	5
	BPUSHW B:C		; place x1	2	7
.end:
	RET



; SWAP ( x1 x2 -- x2 x1 )
; Swaps TOS and NOS
fhead_swap:
	dp fhead_2dup
	db 4 | HFLAG_INLINE
	db "SWAP"
	dw HFLAG_INLINE_STRICT | (fword_swap.end - fword_swap)
fword_swap:
	XCHGW D:A, [BP]	;	3	3
.end:
	RET



; 2SWAP ( x1 x2 x3 x4 -- x3 x4 x1 x2 )
; Swaps cell pairs TOS and NOS
fhead_2swap:
	dp fhead_swap
	db 5
	db "2SWAP"
fword_2swap:
	XCHGW [BP + 4], D:A	; xchg x2, x4	4	4
	MOVW B:C, [BP]		; get x3		3	7
	XCHGW B:C, [BP + 8]	; xchg x3, x1	4	11
	MOVW [BP], B:C		; place x1		3	14
	RET



; OSWAP ( x1 x2 x3 -- x3 x2 x1 )
; Swaps x1 and x3
fhead_oswap:
	dp fhead_2swap
	db 5 | HFLAG_INLINE
	db "OSWAP"
	dw HFLAG_INLINE_STRICT | (fword_oswap.end - fword_swap)
fword_oswap:
	XCHGW D:A, [BP + 4]	;	4	4
.end:
	RET



; 2OSWAP ( x1 x2 x3 x4 x5 x6 -- x5 x6 x3 x4 x1 x2 )
; Swaps cell pairs TOS and NOS
fhead_2oswap:
	dp fhead_oswap
	db 5
	db "2OSWAP"
fword_2oswap:
	XCHGW D:A, [BP + 12]	; place x6, get x2	4	4
	MOVW B:C, [BP]			; get x5			3	7
	XCHGW B:C, [BP + 16]	; place x5, get x1	4	11
	MOVW [BP], B:C			; place x1			3	14
	RET



; OVER ( x1 x2 -- x1 x2 x1 )
; Duplicates NOS
fhead_over:
	dp fhead_2swap
	db 4 | HFLAG_INLINE
	db "OVER"
	dw HFLAG_INLINE_STRICT | (fword_over.end - fword_over)
fword_over:
	BPUSHW D:A			;	2	2
	MOVW D:A, [BP + 4]	;	4	6
.end:
	RET



; 2OVER ( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 )
; Duplicates cell pair NOS
fhead_2over:
	dp fhead_over
	db 5
	db "2OVER"
fword_2over:
	BPUSHW D:A			; place x4	2	2
	MOVW D:A, [BP]		; get x2	3	5
	SUB BP, 4			;			2	7
	MOVW B:C, [BP + 8]	; get x1	4	11
	MOVW [BP], B:C		; place x1	3	14
	RET



; ROT ( x1 x2 x3 -- x2 x3 x1 )
; Rotates top 3 on stack
fhead_rot:
	dp fhead_2over
	db 3 | HFLAG_INLINE
	db "ROT"
	dw HFLAG_INLINE_STRICT | (fword_rot.end - fword_rot)
fword_rot:
	XCHGW D:A, [BP]		; place x3, get x2	3	3
	XCHGW D:A, [BP + 4]	; place x2, get x1	4	7
.end:
	RET



; -ROT ( x1 x2 x3 -- x3 x1 x2 )
; Reverse pf ROT
fhead_nrot:
	dp fhead_rot
	db 4 | HFLAG_INLINE
	db "-ROT"
	dw HFLAG_INLINE_STRICT | (fword_nrot.end - fword_nrot)
fword_nrot:
	XCHGW D:A, [BP + 4]	; place x3, get x1	4	4
	XCHGW D:A, [BP]		; place x1, get x2	3	7
.end:
	RET



;	x1	+16	->	+0
;	x2	+12	->	D:A
;	x3	+8	->	+16
;	x4	+4	->	+12
;	x5	+0	->	+8
;	x6	D:A	->	+4

; 2ROT ( x1 x2 x3 x4 x5 x6 -- x3 x4 x5 x6 x1 x2 )
; ROT for cell pairs
fhead_2rot:
	dp fhead_nrot
	db 4
	db "2ROT"
fword_2rot:
	XCHGW D:A, [BP + 4]		; place x6, get x4
	XCHGW D:A, [BP + 12]	; place x4, get x2
	MOVW B:C, [BP]			; get x5
	XCHGW B:C, [BP + 8]		; place x5, get x3
	XCHGW B:C, [BP + 16]	; place x3, get x1
	MOVW [BP], B:C			; place x1
	RET



;	x1	+16	->	+8
;	x2	+12	->	+4
;	x3	+8	->	+0
;	x4	+4	->	D:A
;	x5	+0	->	+16
;	x6	D:A	->	+12

; -2ROT ( x1 x2 x3 x4 x5 x6 -- x5 x6 x1 x2 x3 x4 )
; -ROT for cell pairs
fhead_n2rot:
	dp fhead_2rot
	db 5
	db "-2ROT"
fword_n2rot:
	XCHGW D:A, [BP + 12]	; place x6, get x2
	XCHGW D:A, [BP + 4]		; place x2, get x4
	MOVW B:C, [BP]			; get x5
	XCHGW B:C, [BP + 16]	; place x5, get x1
	XCHGW B:C, [BP + 8]		; place x1, get x3
	MOVW [BP], B:C			; place x3, get x4
	RET



; >R ( x -- ) ( R: -- x )
; Moves x to the return stack
fhead_tor:
	dp fhead_n2rot
	db 2 | HFLAG_INLINE
	db ">R"
	dw HFLAG_INLINE_ALWAYS | (fword_tor.end - fword_tor)
fword_tor:
	PUSHW D:A	;	2	2
	BPOPW D:A	;	2	4
.end:
	BPUSHW D:A	; doesn't work if not inline
	MOVW D:A, TCODE_COMPILE_ONLY
	JMP fword_throw



; 2>R ( x1 x2 -- ) ( R: -- x1 x2 )
; Moves pair x1 x2 to return stack
fhead_2tor:
	dp fhead_tor
	db 3 | HFLAG_INLINE
	db "2>R"
	dw HFLAG_INLINE_ALWAYS | (fword_2tor.end - fword_2tor)
fword_2tor:
	PUSHW ptr [BP]	;	3	3
	PUSHW D:A		;	2	5
	ADD BP, 4		;	2	7
	BPOPW D:A		;	2	9
.end:
	BPUSHW D:A	; doesn't work if not inline
	MOVW D:A, TCODE_COMPILE_ONLY
	JMP fword_throw



; R@ ( -- x ) ( R: x -- x )
; Copies x from return stack to stack
fhead_rfetch:
	dp fhead_2tor
	db 2 | HFLAG_INLINE
	db "R@"
	dw HFLAG_INLINE_ALWAYS | (fword_rfetch.end - fword_rfetch)
fword_rfetch:
	BPUSHW D:A		;	2	2
	MOVW D:A, [SP]	;	3	5
.end:
	BPUSHW D:A	; doesn't work if not inline
	MOVW D:A, TCODE_COMPILE_ONLY
	JMP fword_throw



; 2R@ ( -- x1 x2 ) ( R: x1 x2 -- x1 x2 )
; Copies pair x1 x2 from return stack to stack
fhead_2rfetch:
	dp fhead_rfetch
	db 3 | HFLAG_INLINE
	db "2R@"
	dw HFLAG_INLINE_ALWAYS | (fword_2rfetch.end - fword_2rfetch)
fword_2rfetch:
	BPUSHW D:A			;	2	2
	MOVW D:A, [SP]		;	3	5
	MOVW B:C, [SP + 4]	;	4	9
	BPUSHW B:C			;	2	11
.end:
	BPUSHW D:A	; doesn't work if not inline
	MOVW D:A, TCODE_COMPILE_ONLY
	JMP fword_throw



; R> ( -- x ) ( R: x -- )
; Moves x from return stack to stack
fhead_rfrom:
	dp fhead_2rfetch
	db 2 | HFLAG_INLINE
	db "R>"
	dw HFLAG_INLINE_ALWAYS | (fword_rfrom.end - fword_rfrom)
fword_rfrom:
	BPUSHW D:A	;	2	2
	POPW D:A	;	2	4
.end:
	BPUSHW D:A	; doesn't work if not inline
	MOVW D:A, TCODE_COMPILE_ONLY
	JMP fword_throw



; 2R> ( -- x1 x2 ) ( R: x1 x2 -- )
; Moves pair x1 x2 from return stack to stack
fhead_2rfrom:
	dp fhead_rfrom
	db 3 | HFLAG_INLINE
	db "2R>"
	dw HFLAG_INLINE_ALWAYS | (fword_2rfrom.end - fword_2rfrom)
fword_2rfrom:
	BPUSHW D:A	;	2	2
	POPW D:A	;	2	4
	POPW B:C	;	2	6
	BPUSHW B:C	;	2	8
.end:
	BPUSHW D:A	; doesn't work if not inline
	MOVW D:A, TCODE_COMPILE_ONLY
	JMP fword_throw



; @ ( a-addr -- x )
; x = [a-addr]
fhead_fetch:
	dp fhead_2rfrom
	db 1 | HFLAG_INLINE
	db "@"
	dw HFLAG_INLINE_STRICT | (fword_fetch.end - fword_fetch)
fword_fetch:
	MOVW D:A, [D:A]	;	3	3
.end:
	RET



; C@ ( c-addr -- char )
; Fetch character from [c-addr]
fhead_cfetch:
	dp fhead_fetch
	db 2 | HFLAG_INLINE
	db "C@"
	dw HFLAG_INLINE_STRICT | (fword_cfetch.end - fword_cfetch)
fword_cfetch:
	MOVZ A, [D:A]	;	3	3
	MOVS D, 0		;	2	5
.end:
	RET



; 2@ ( a-addr -- x1 x2 )
; Fetch cell pair x1 x2 from [a-addr]. High cell -> x1.
fhead_2fetch:
	dp fhead_cfetch
	db 2 | HFLAG_INLINE
	db "2@"
	dw HFLAG_INLINE_STRICT | (fword_2fetch.end - fword_2fetch)
fword_2fetch:
	BPUSHW ptr [D:A + 4]	;	4	4
	MOVW D:A, [D:A]			;	3	7
.end:
	RET



; ! ( x a-addr -- )
; Store x at a-addr
fhead_store:
	dp fhead_2fetch
	db 1 | HFLAG_INLINE
	db "!"
	dw HFLAG_INLINE_STRICT | (fword_store.end - fword_store)
fword_store:
	BPOPW B:C		;	2	2
	MOVW [D:A], B:C	;	3	5
	BPOPW D:A		;	2	7
.end:
	RET



; +! ( x a-addr -- )
; Add x to [a-addr]
fhead_pstore:
	dp fhead_store
	db 2 | HFLAG_INLINE
	db "+!"
	dw (fword_pstore.end - fword_pstore)
fword_pstore:
	BPOPW B:C			;	2	2
	ADD [D:A], C		;	3	5
	ADC [D:A + 2], B	;	4	9
	BPOPW D:A			;	2	11
.end:
	RET



; -! ( x a-addr -- )
; Subtract x from [a-addr]
fhead_mstore:
	dp fhead_pstore
	db 2 | HFLAG_INLINE
	db "-!"
	dw (fword_mstore.end - fword_mstore)
fword_mstore:
	BPOPW B:C			;	2	2
	SUB [D:A], C		;	3	5
	SBB [D:A + 2], B	;	4	9
	BPOPW D:A			;	2	11
.end:
	RET



; C! ( char c-addr -- )
; Store char at [c-addr]
fhead_cstore:
	dp fhead_mstore
	db 2 | HFLAG_INLINE
	db "C!"
	dw HFLAG_INLINE_STRICT | (fword_cstore.end - fword_cstore)
fword_cstore:
	BPOPW B:C		;	2	2
	MOV [D:A], CL	;	3	5
	BPOPW D:A		;	2	7
.end:
	RET



; 2! ( x1 x2 a-addr -- )
; Store cell pair x1 x2 at a-addr. x1 -> high cell
fhead_2store:
	dp fhead_cstore
	db 2
	db "2!"
fword_2store:
	BPOPW B:C
	BPOPW J:I
	MOVW [D:A], B:C
	MOVW [D:A + 4], J:I
	BPOPW D:A
	RET



; , ( x -- )
; Reserve one cell of data space, store x in the cell
fhead_comma:
	dp fhead_2store
	db 1
	db ","
fword_comma:
	MOVW B:C, [uvar_here]	; HERE
	MOVW [B:C], D:A			; store
	ADD C, 4				; update
	ICC B
	MOVW [uvar_here], B:C
	BPOPW D:A				; pop
	RET



; C, ( char -- )
; Reserve one character of data space, store char in the space
fhead_ccomma:
	dp fhead_comma
	db 2
	db "C,"
fword_ccomma:
	MOVW B:C, [uvar_here]	; HERE
	MOV [B:C], AL			; store
	INC C					; update
	ICC B
	MOVW [uvar_here], B:C
	BPOPW D:A				; pop
	RET



; 2, ( x1 x2 -- )
; Reserve 2 cells of data space, store pair x1 x2 to them. High cell = x1
fhead_2comma:
	dp fhead_ccomma
	db 2
	db "2,"
fword_2comma:
	MOVW B:C, [uvar_here]	; HERE
	MOVW [B:C], D:A			; store
	BPOPW ptr [B:C + 4]
	ADD C, 8				; update
	ICC B
	MOVW [uvar_here], B:C
	BPOPW D:A				; pop
	RET



; + ( x1 x2 -- x3 )
; x3 = x1 + x2
fhead_plus:
	dp fhead_2comma
	db 1 | HFLAG_INLINE
	db "+"
	dw HFLAG_INLINE_STRICT | (fword_plus.end - fword_plus)
fword_plus:
	BPOPW B:C	;	2	2
	ADD A, C	;	2	4
	ADC D, B	;	2	6
.end:
	RET



; - ( x1 x2 -- x3 )
; x3 = x1 - x2
fhead_minus:
	dp fhead_plus
	db 1 | HFLAG_INLINE
	db "-"
	dw HFLAG_INLINE_STRICT | (fword_minus.end - fword_minus)
fword_minus:
	BPOPW B:C		;	2	2
	XCHGW D:A, B:C	;	2	4
	SUB A, C		;	2	6
	SBB D, B		;	2	8
.end:
	RET



; 1+ ( x1 -- x2 )
; x2 = x1 + 1
fhead_inc:
	dp fhead_minus
	db 2 | HFLAG_INLINE
	db "1+"
	dw HFLAG_INLINE_STRICT | (fword_inc.end - fword_inc)
fword_inc:
	INC A	;	2	2
	ICC D	;	1	3
.end:
	RET



; 1- ( x1 -- x2 )
; x2 = x1 - 1
fhead_dec:
	dp fhead_inc
	db 2 | HFLAG_INLINE
	db "1-"
	dw HFLAG_INLINE_STRICT | (fword_dec.end - fword_dec)
fword_dec:
	DEC A	;	2	2
	DCC D	;	1	3
.end:
	RET



; CELL+ ( a-addr1 -- a-addr2 )
; Increment a-addr1 by 1 cell
fhead_cellp:
	dp fhead_dec
	db 5 | HFLAG_INLINE
	db "CELL+"
	dw HFLAG_INLINE_STRICT | (fword_cellp.end - fword_cellp)
fword_cellp:
	ADD A, 4	;	2	2
	ICC D		;	1	3
.end:
	RET



; CHAR+ ( x1 -- x2 )
; x2 = x1 + 1
fhead_charp:
	dp fhead_cellp
	db 5 | HFLAG_INLINE
	db "CHAR+"
	dw HFLAG_INLINE_STRICT | (fword_charp.end - fword_charp)
fword_charp:
	INC A	;	2	2
	ICC D	;	1	3
.end:
	RET



; { ( -- )
; Begin a locals block
fhead_lbrace:
	dp fhead_charp
	db 1 | HFLAG_IMMEDIATE
	db "{"
fword_lbrace:
	PUSHW D:A
	PUSHW L:K

	; [SP + 1]	= number of locals
	; [SP]		= type of next local
	PUSH byte 0
	PUSH byte LTYPE_CELL_VAL
	
	; Parse locals
.parse_loop:
	MOV CL, CHAR_SPACE			; parse next token
	CALL kernel_parse_token
	
	CMP C, 0
	JE .exception_out_of_parse	; we expect to have stuff
	
	; what do we have
	CMP C, 1	; might be end
	JE .parse_loop_check_end
	
	CMP C, 2
	JNE .parse_loop_add_local
	
	MOV A, [J:I]
	
	CMP A, 0x3A_57	; "W:"
	JE .parse_loop_type_cell_val
	
	CMP A, 0x3A_43	; "C:"
	JE .parse_loop_type_char_val
	
	CMP A, 0x5E_57	; "W^"
	JE .parse_loop_type_cell_var
	
	CMP A, 0x5E_43	; "C^"
	JE .parse_loop_type_char_var
	
	CMP A, 0x2D_2D	; "--"
	JNE .parse_loop_add_local
	
	; token was "--"
	MOV CL, "}"		; parse and discard the rest of the local block
	CALL kernel_parse_token
	JMP .done_parsing

	; token was "W:"
.parse_loop_type_cell_val:
	MOV AL, LTYPE_CELL_VAL
	MOV [SP], AL
	JMP .parse_loop

	; token was "W^"
.parse_loop_type_cell_var:
	MOV AL, LTYPE_CELL_VAR
	MOV [SP], AL
	JMP .parse_loop

	; token was "C:"
.parse_loop_type_char_val:
	MOV AL, LTYPE_CHAR_VAL
	MOV [SP], AL
	JMP .parse_loop

	; token was "C^"
.parse_loop_type_char_var:
	MOV AL, LTYPE_CHAR_VAR
	MOV [SP], AL
	JMP .parse_loop

.parse_loop_check_end:
	CMP byte [J:I], "}"	; end of block?
	JE .done_parsing

	; token is neither a type, --, or }
.parse_loop_add_local:
	INC byte [SP + 1]	; track count
	MOV CH, [SP]		; get type, other args already ready
	CALL kernel_create_local
	JMP .parse_loop

.done_parsing:
	ADD SP, 1	; discard type
	
	; init locals
	POP CL
	CALL kernel_init_locals
	
	POPW L:K
	POPW D:A
	RET

	; exceptions
.exception_out_of_parse:
	BPUSHW D:A
	MOVW D:A, TCODE_MALFORMED_LOCALS
	JMP fword_throw



; STATE ( -- a-addr )
; Gets the address of the STATE variable
fhead_state:
	dp fhead_lbrace
	db 5
	db "STATE"
fword_state:
	BPUSHW D:A
	MOVW D:A, uvar_here
	RET



; BASE ( -- a-addr)
; Gets the address of the BASE variable
fhead_base:
	dp fhead_state
	db 4
	db "BASE"
fword_base:
	BPUSHW D:A
	MOVW D:A, uvar_base
	RET



; DECIMAL ( -- )
; Sets BASE to 10
fhead_decimal:
	dp fhead_base
	db 7
	db "DECIMAL"
fword_decimal:
	MOVW B:C, 10
	MOVW [uvar_base], B:C
	RET



; HEX ( -- )
; Sets BASE to 16
fhead_hex:
	dp fhead_decimal
	db 3
	db "HEX"
fword_hex:
	MOVW B:C, 16
	MOVW [uvar_base], B:C
	RET



; PAGE ( -- )
; Clears the screen and sends the cursor home
fhead_page:
	dp fhead_hex
	db 4
	db "PAGE"
fword_page:
	CALL kernel_print_inline
	db 7, CHAR_ESCAPE, "[2J", CHAR_ESCAPE, "[H"
	RET



; DEPTH ( -- +n )
; +n is the number of cells on the parameter stack before it was pushed
fhead_depth:
	dp fhead_page
	db 5
	db "DEPTH"
fword_depth:
	; D:A = diff between origin and bp
	MOVW B:C, BP
	BPUSH D:A
	MOVW D:A, [uvar_param_stack_origin]
	SUB A, C
	SBB D, B
	
	; depth = diff / 4
	SHR D, 1	; / 4
	RCR A, 1
	SHR D, 1
	RCR A, 1
	RET



; .S ( -- )
; Display the contents of the parameter stack
fhead_dots:
	dp fhead_depth
	db 2
	db ".S"
fword_dots:
	; display <depth>
	MOV CL, "<"
	CALL kernel_print_char
	CALL fword_depth
	PUSHW D:A	; save
	CALL fword_dot
	CALL kernel_print_inline
	db 3, CHAR_BACKSPACE, "> "
	
	; Display stack
	POPW J:I							; depth
	CMP I, 0
	JNZ .not_empty
	CMP J, 0
	JZ .empty

.not_empty:
	MOVW B:C, [uvar_param_stack_origin]	; start of stack
	SUB C, 8							; skip 1st entry cause its not real
	DCC B
	JMP .cmp
	
.loop:
	BPUSHW D:A		; get item
	MOVW D:A, [B:C]
	
	PUSHW B:C
	PUSHW J:I
	
	CALL fword_dot	; print item
	
	POPW J:I
	POPW B:C
	
	SUB C, 4
	DCC B
	
	DEC I
	DCC J
	
.cmp:
	CMP I, 1	; 1 left = show D:A
	JNZ .loop
	CMP J, 0
	JNZ .loop
	
	BPUSHW D:A
	CALL fword_dot

.empty:	
	; CR0
	CALL fword_cr
	RET



; ( ( "ccc<rparen>" -- )
; Parse and discard until a )
fhead_paren:
	dp fhead_dots
	db 1 | HFLAG_IMMEDIATE
	db "("
fword_paren:
	MOV CL, ")"
	CALL kernel_parse_token
	RET



; \ ( "ccc<eol>" -- )
; Parse and discard the remainder of the line
fhead_backslash:
	dp fhead_paren
	db 1 | HFLAG_IMMEDIATE
	db "\"
fword_backslash:
	MOV CL, CHAR_NEWLINE
	CALL kernel_parse_token
	RET



; ? ( a-addr -- )
; Display the value at a-addr.
; : ? @ . ;
fhead_question:
	dp fhead_backslash
	db 1
	db "?"
fword_question:
	MOVW D:A, [D:A]	; fetch
	CALL fword_dot	; print
	RET



; DUMP ( addr u -- )
; Display the contents of u consecutive addresses
; Values are displayed as a hex dump in rows of 8 bytes
fhead_dump:
	dp fhead_question
	db 4
	db "DUMP"
fword_dump:
	CMP A, 0
	JNZ .nonzero
	CMP D, 0
	JNZ .nonzero
	
	ADD BP, 4
	BPOPW D:A
	RET

.nonzero:
	PUSHW L:K
	
	; B:C = count
	; J:I = address
	; L:K = target
	MOVW B:C, 0		; count
	BPOPW J:I		; addr
	MOVW L:K, D:A	; target
	JMP .skip_first_cr
	
.loop:
	; is this the start of a row
	TST CL, 0x07
	JNZ .not_row_start
	
	PUSHW B:C
	PUSHW J:I
	CALL fword_cr
	POPW J:I
	POPW B:C
	
	; display address
.skip_first_cr:
	MOVW D:A, J:I
	XCHG DH, DL
	CALL .sub_display_byte
	MOV DL, DH
	CALL .sub_display_byte
	MOV DL, AH
	CALL .sub_display_byte
	MOV DL, AL
	CALL .sub_display_byte
	
	PUSHW B:C
	PUSHW J:I
	CALL kernel_print_inline
	db 2, ": "
	POPW J:I
	POPW B:C

.not_row_start:
	; print byte
	MOV DL, [J:I]
	CALL .sub_display_byte
	
	; print space
	PUSHW B:C
	PUSHW J:I
	CALL fword_space
	POPW J:I
	POPW B:C
	
	; inc/dec
	INC C	; count
	ICC B
	INC I	; address
	ICC J
	
	DEC K	; remaining
	DCC L
	
	JNZ .loop	; done?
	CMP K, 0
	JNZ .loop
	
	CALL fword_cr
	POPW L:K
	BPOPW D:A	; pop
	RET

	; Displays byte in DL
.sub_display_byte:
	PUSHW B:C
	PUSHW J:I
	
	MOV CL, DL	; upper nybble
	SHR CL, 4
	CALL .sub_print_nybble
	
	MOV CL, DL
	AND CL, 0x0F
	CALL .sub_print_nybble
	
	POPW J:I
	POPW B:C
	RET

.sub_print_nybble:
	CMP CL, 10
	MOV CH, '0'
	CMOVAE CH, 'A' - 10
	ADD CL, CH
	CALL kernel_print_char
	RET



; MAX ( n1 n2 -- n3 )
; n3 = max(n1, n2)
fhead_max:
	dp fhead_dump
	db 3
	db "MAX"
fword_max:
	BPOPW B:C	; get n2
	CMP D, B
	JNE .move
	CMP A, C
.move:
	CMOVL D, B
	CMOVL A, C
	RET



; MIN ( n1 n2 -- n3 )
; n3 = min(n1, n2)
fhead_min:
	dp fhead_max
	db 3
	db "MIN"
fword_min:
	BPOPW B:C	; get n2
	CMP D, B
	JNE .move
	CMP A, C
.move:
	CMOVG D, B
	CMOVG A, C
	RET



; ABS ( n -- u )
; u is the absolute value of n
fhead_abs:
	dp fhead_min
	db 3 | HFLAG_INLINE
	db "ABS"
	dw (fword_abs.end - fword_abs)
fword_abs:
	CMP D, 0	;	2	2
	JNS .ok		;	2	4
	NOT D		;	2	6
	NEG A		;	2	8
	ICC D		;	1	9
.ok:
.end:
	RET



; TRUE ( -- true )
; Get a true flag
fhead_true:
	dp fhead_abs
	db 4 | HFLAG_INLINE
	db "TRUE"
	dw HFLAG_INLINE_STRICT | (fword_true.end - fword_true)
fword_true:
	BPUSHW D:A			;	2	2
	MOVW D:A, FLAG_TRUE	;	4	6
.end:
	RET



; FALSE ( -- false )
; Get a false flag
fhead_false:
	dp fhead_true
	db 5 | HFLAG_INLINE
	db "FALSE"
	dw HFLAG_INLINE_STRICT | (fword_false.end - fword_false)
fword_false:
	BPUSHW D:A				;	2	2
	MOVW D:A, FLAG_FALSE	;	4	6
.end:
	RET



; AND ( x1 x2 -- x3 )
; x3 is the bitwise AND of x1 and x2
fhead_and:
	dp fhead_false
	db 3 | HFLAG_INLINE
	db "AND"
	dw HFLAG_INLINE_STRICT | (fword_and.end - fword_and)
fword_and:
	BPOPW B:C	;	2	2
	AND A, C	;	2	4
	AND D, B	;	2	6
.end:
	RET



; OR ( x1 x2 -- x3 )
; x3 is the bitwise OR of x1 and x2
fhead_or:
	dp fhead_and
	db 2 | HFLAG_INLINE
	db "OR"
	dw HFLAG_INLINE_STRICT | (fword_or.end - fword_or)
fword_or:
	BPOPW B:C	;	2	2
	OR A, C		;	2	4
	OR D, B		;	2	6
.end:
	RET



; XOR ( x1 x2 -- x3 )
; x3 is the bitwise XOR of x1 and x2
fhead_xor:
	dp fhead_or
	db 3 | HFLAG_INLINE
	db "XOR"
	dw HFLAG_INLINE_STRICT | (fword_xor.end - fword_xor)
fword_xor:
	BPOPW B:C	;	2	2
	XOR A, C	;	2	4
	XOR D, B	;	2	6
.end:
	RET



; INVERT ( x1 -- x2 )
; Invert all bits of x1 to get x2
fhead_invert:
	dp fhead_xor
	db 6 | HFLAG_INLINE
	db "INVERT"
	dw HFLAG_INLINE_STRICT | (fword_invert.end - fword_invert)
fword_invert:
	NOT A	;	2	2
	NOT D	;	2	4
.end:
	RET



; NEGATE ( n1 -- n2 )
; n2 is the arithmetic inverse of n1
fhead_negate:
	dp fhead_invert
	db 6 | HFLAG_INLINE
	db "NEGATE"
	dw HFLAG_INLINE_STRICT | (fword_negate.end - fword_negate)
fword_negate:
	NOT D	;	2	2
	NEG A	;	2	4
	ICC D	;	1	5
.end:
	RET



; LSHIFT ( x1 u -- x2 )
; Shifts x1 left by u bits, filling with zeros.
fhead_lshift:
	dp fhead_negate
	db 6
	db "LSHIFT"
fword_lshift:
	BPOPW B:C	; B:C = u, D:A = x1
	XCHGW D:A, B:C
	
	CMP B, 0	; out-of-range = 0
	JA .zero
	CMP C, 32
	JAE .zero
	
	MOV I, C	; I = number of bytes to shift
	SHR I, 3
	AND C, 0x07	; C = number of bits to shift
	JMP byte [IP + I]
	db @.bits
	db @.1byte
	db @.2byte
	db @.3byte

.3byte:	; having A be zero is convenient
	MOV DH, AL
	MOV DL, 0
	MOV A, 0
	SHL D, C
	RET

.2byte:
	MOV D, A
	MOV A, 0
	SHL D, C
	RET

.1byte: ; having A be nonzero is inconvenient
	MOV DH, DL
	MOV DL, AH
	MOV AH, AL
	MOV AL, 0
	CMP C, 0
	JNE .bits
	RET

.bits:
	SHL A, 1
	RCL D, 1
	DEC C
	JNZ .bits
	RET

.zero:
	MOVW D:A, 0
	RET



; RSHIFT ( x1 u -- x2 )
; Shifts x1 right by u bits, filling with zeros.
fhead_rshift:
	dp fhead_lshift
	db 6
	db "RSHIFT"
fword_rshift:
	BPOPW B:C	; B:C = u, D:A = x1
	XCHGW D:A, B:C
	
	CMP B, 0	; out-of-range = 0
	JA .zero
	CMP C, 32
	JAE .zero
	
	MOV I, C	; I = number of bytes to shift
	SHR I, 3
	AND C, 0x07	; C = number of bits to shift
	JMP byte [IP + I]
	db @.bits
	db @.1byte
	db @.2byte
	db @.3byte

.3byte:	; having D be zero makes things convenient
	MOVZ A, DH
	MOV D, 0
	SHR A, C
	RET

.2byte:
	MOVZ D:A, D
	SHR A, C
	RET

.1byte:	; having D be nonzero makes thing inconvenient
	MOV AL, AH
	MOV AH, DL
	MOVZ D, DH
	CMP C, 0
	JNE .bits
	RET

.bits:
	SHR D, 1
	RCR A, 1
	DEC C
	JNZ .bits
	RET

.zero:
	MOVW D:A, 0
	RET



; 2* ( x1 -- x2 )
; : 2* 1 LSHIFT ;
fhead_2star:
	dp fhead_rshift
	db 2 | HFLAG_INLINE
	db "2*"
	dw HFLAG_INLINE_STRICT | (fword_2star.end - fword_2star)
fword_2star:
	SHL A, 1	;	4	4
	RCL D, 1	;	4	8
.end:
	RET



; 2/ ( x1 -- x2 )
; : 2/ 1 RSHIFT ;
fhead_2slash:
	dp fhead_2star
	db 2 | HFLAG_INLINE
	db "2/"
	dw HFLAG_INLINE_STRICT | (fword_2slash.end - fword_2slash)
fword_2slash:
	SHR D, 1	;	4	4
	RCR A, 1	;	4	8
.end:
	RET



; < ( n1 n2 -- flag )
; flag is true iff n1 < n2
fhead_less:
	dp fhead_2slash
	db 1
	db "<"
fword_less:
	BPOPW B:C
	CMP B, D
	JL .true
	JG .false
	CMP C, A
	JB .true

.false:
	MOVW D:A, FLAG_FALSE
	RET

.true:
	MOVW D:A, FLAG_TRUE
	RET



; U< ( u1 u2 -- flag )
; flag is true iff u1 < u2
fhead_uless:
	dp fhead_less
	db 2
	db "U<"
fword_uless:
	BPOPW B:C
	CMP B, D
	JB .true
	JA .false
	CMP C, A
	JB .true

.false:
	MOVW D:A, FLAG_FALSE
	RET

.true:
	MOVW D:A, FLAG_TRUE
	RET



; 0< ( n -- flag )
; flag is true iff n < 0
fhead_zeroless:
	dp fhead_uless
	db 2
	db "0<"
fword_zeroless:
	CMP D, 0
	JS .true
	MOVW D:A, FLAG_FALSE
	RET						
	
.true:
	MOVW D:A, FLAG_TRUE
	RET	



; = ( x1 x2 -- flag )
; flag is true iff x1 = x2
fhead_equal:
	dp fhead_zeroless
	db 1
	db "="
fword_equal:
	BPOPW B:C
	CMP B, D
	JNE .false
	CMP C, A
	JE .true

.false:
	MOVW D:A, FLAG_FALSE
	RET

.true:
	MOVW D:A, FLAG_TRUE
	RET



; 0= ( x -- flag )
; flag is true iff x = 0
fhead_zeroequal:
	dp fhead_equal
	db 2
	db "0<"
fword_zeroequal:
	CMP D, 0
	JNE .false
	CMP A, 0
	JE .true

.false:
	MOVW D:A, FLAG_FALSE
	RET						
	
.true:
	MOVW D:A, FLAG_TRUE
	RET



; <> ( x1 x2 -- flag )
; flag is true iff x1 != x2
fhead_notequal:
	dp fhead_zeroequal
	db 2
	db "<>"
fword_notequal:
	BPOPW B:C
	CMP B, D
	JNE .true
	CMP C, A
	JNE .true

.false:
	MOVW D:A, FLAG_FALSE
	RET

.true:
	MOVW D:A, FLAG_TRUE
	RET



; 0<> ( x -- flag )
; flag is true iff x != 0
fhead_zeronotequal:
	dp fhead_notequal
	db 3
	db "0<>"
fword_zeronotequal:
	CMP D, 0
	JNE .true
	CMP A, 0
	JNE .true

.false:
	MOVW D:A, FLAG_FALSE
	RET						
	
.true:
	MOVW D:A, FLAG_TRUE
	RET



; > ( n1 n2 -- flag )
; flag is true iff n1 > n2
fhead_greater:
	dp fhead_zeronotequal
	db 1
	db ">"
fword_greater:
	BPOPW B:C
	CMP B, D
	JG .true
	JL .false
	CMP C, A
	JA .true

.false:
	MOVW D:A, FLAG_FALSE
	RET

.true:
	MOVW D:A, FLAG_TRUE
	RET



; U> ( u1 u2 -- flag )
; flag is true iff u1 > u2
fhead_ugreater:
	dp fhead_greater
	db 2
	db "U>"
fword_ugreater:
	BPOPW B:C
	CMP B, D
	JA .true
	JB .false
	CMP C, A
	JA .true

.false:
	MOVW D:A, FLAG_FALSE
	RET

.true:
	MOVW D:A, FLAG_TRUE
	RET



; 0> ( n -- flag )
; flag is true iff n > 0
fhead_zerogreater:
	dp fhead_ugreater
	db 2
	db "0>"
fword_zerogreater:
	CMP D, 0
	JNS .true
	MOVW D:A, FLAG_FALSE
	RET						
	
.true:
	MOVW D:A, FLAG_TRUE
	RET



; RECURSE ( -- )
; Recursion
fhead_recurse:
	dp fhead_zerogreater
	db 7 | HFLAG_IMMEDIATE
	db "RECURSE"
fword_recurse:
	BPUSHW D:A
	MOVW D:A, fhead_recurse
	CALL fword_compile_only
	
	; Compile:
	; CALL <self>
	PUSHW D:A
	PUSHW L:K
	
	MOVW J:I, [uvar_latest]			; J:I = current definition body = value
	CALL kernel_get_body
	
	MOV A, 0x01_3B					; offset 1; compute difference; signed; 4, 2, 1 bytes allowed
	MOVW B:C, 0xD6_00_D5_D4			; CALL i32, n/a, CALL i16, CALL i8
	MOVW L:K, [uvar_here]			; destination
	CALL kernel_compile_number		; L:K = HERE
	MOVW [uvar_here], L:K
	
	POPW L:K
	POPW D:A
	RET



; EXIT ( -- ) ( R: nest-sys -- )
; Return from current definition
fhead_exit:
	dp fhead_recurse
	db 4 | HFLAG_IMMEDIATE
	db "EXIT"
fword_exit:
	BPUSHW D:A
	MOVW D:A, fhead_exit
	CALL fword_compile_only
	
	; Remove locals without taking them out of scope
	MOV CL, [uvar_locals_count]
	CALL kernel_compile_remove_locals
	
	; Compile RET
	MOV CL, 0xE0	; RET
	MOV [J:I], CL
	
	INC I
	ICC J
	MOVW [uvar_here], J:I
	RET
	



; AHEAD
; CT: ( C: -- orig )
;	Create unresolved forward reference orig
; RT: ( -- )
;	branch to resolution of orig
fhead_ahead:
	dp fhead_exit
	db 5 | HFLAG_IMMEDIATE
	db "AHEAD"
fword_ahead:
	BPUSHW D:A
	MOVW D:A, fhead_ahead
	CALL fword_compile_only

	; Compile:
	; JMP i16
	MOVW J:I, [uvar_here]
	MOV CL, 0xDB	; JMP i16
	MOV [J:I], CL
	
	INC I			; get orig address
	ICC J
	
	BPUSHW D:A		; push orig
	BPUSHW J:I
	MOVW D:A, [uvar_locals_count]
	
	ADD I, 2		; update HERE
	ICC J
	MOVW [uvar_here], J:I
	RET



; THEN
; CT: ( C: orig -- )
;	Resolve forward reference orig
; RT: ( -- )
;	Continue execution
fhead_then:
	dp fhead_ahead
	db 4 | HFLAG_IMMEDIATE
	db "THEN"
fword_then:
	BPUSHW D:A
	MOVW D:A, fhead_then
	CALL fword_compile_only
	
	; correct locals
	MOV CL, [uvar_locals_count]	; current number
	SUB CL, AL					; current - expected = remove
	CALL kernel_remove_locals
	
	; resolve reference
	PUSHW L:K
	
	BPOPW L:K		; destination
	MOV A, 0x00_32	; no prefix, compute, 2 bytes allowed
	MOVW J:I, [uvar_here]
	CALL kernel_compile_number
	CMP C, 0
	JZ .out_of_range
	
	POPW L:K
	BPOPW D:A
	RET

.out_of_range:
	BPUSHW D:A
	MOVW D:A, TCODE_OUT_OF_RANGE
	JMP fword_throw



; IF
; CT: ( C: -- orig )
; 	Create unresolved forward reference orig
; RT: ( x -- )
; 	If x = 0, branch to resolution of orig
fhead_if:
	dp fhead_then
	db 2 | HFLAG_IMMEDIATE
	db "IF"
fword_if:
	BPUSHW D:A
	MOVW D:A, fhead_if
	CALL fword_compile_only
	
	CMP byte [uvar_inlining_mode], INLINE_MODE_NEVER
	JNE .inline
	
.noinline:
	; Compile:
	;	CALL .do_if
	;	dw offset
	PUSHW D:A
	PUSHW L:K
	
	MOV A, 0x01_3B
	MOVW B:C, 0xD6_00_D5_D4
	MOVW J:I, .do_if
	MOVW L:K, [uvar_here]
	CALL kernel_compile_number
	
	MOVW J:I, L:K
	
	POPW L:K
	POPW D:A
	JMP .done
	
.inline:
	; Compile:
	;	CMP D, 0	;	2	2
	;	JNZ .nz		;	2	4
	;	CMP A, 0	;	2	6
	;.nz:
	;	BPOPW D:A	;	2	8
	;	JZ i16		;	4	12
	MOVW J:I, [uvar_here]
	MOVW B:C, 0x02_F2_18_6E	; CMP D, 0; JNZ 2
	MOVW [J:I], B:C
	MOVW B:C, 0x00_57_00_6E	; CMP A, 0; BPOPW D:A
	MOVW [J:I + 4], B:C
	MOV C, 0x40_F1			; JZ i16
	MOVW [J:I + 8], C
	
	ADD I, 10
	ICC J
	
.done:
	BPUSHW D:A	; orig
	BPUSHW J:I
	MOVW D:A, [uvar_locals_count]
	
	ADD I, 2	; HERE
	ICC J
	MOVW [uvar_here], J:I
	RET

	; do the action of IF
.do_if:
	POPW J:I		; J:I = return address
	MOV C, [J:I]	; C = offset
	ADD I, 2
	ICC J
	
	CMP D, 0
	JNZ .do_if_nz
	CMP A, 0
	JNZ .do_if_nz
	
	LEA J:I, [J:I + C]	; add offset to return address

.do_if_nz:
	JMPA J:I		; return



; ELSE
; CT: ( C: orig1 -- orig2 )
;	Resolve orig1 after RT semantics. Replace with orig2
; RT: ( -- )
;	Branch to resolution of orig2
fhead_else:
	dp fhead_if
	db 4 | HFLAG_IMMEDIATE
	db "ELSE"
fword_else:
	BPUSHW D:A
	MOVW D:A, fhead_else
	CALL fword_compile_only
	
	; correct locals
	MOV CL, [uvar_locals_count]
	SUB CL, AL
	CALL kernel_remove_locals
	
	PUSHW D:A
	PUSHW L:K
	
	; Compile:
	;	JMP i16
	MOVW L:K, [uvar_here]
	MOV CL, 0xDB	; JMP i16
	MOV [L:K], CL
	
	INC K			; orig2 address
	ICC L
	
	; resolve reference
	LEA J:I, [L:K + 2]	; J:I = orig1 target = value = HERE
	MOVW [uvar_here], J:I
	XCHGW L:K, [BP]		; replace orig1 with orig2, L:K = orig1 address = destination
	MOV A, 0x00_32		; no prefix, compute, 2 bytes allowed
	CALL kernel_compile_number
	CMP C, 0
	JZ .out_of_range
	
	POPW L:K
	POPW D:A
	RET

.out_of_range:
	BPUSHW D:A
	MOVW D:A, TCODE_OUT_OF_RANGE
	JMP fword_throw
