# Locals
 The Locals word list implements locals similar to GForth's.
 
 Locals may be created at any time within a definition. Locals remain visible until code is reached
 where they may not have been created. `orig`, `dest`, and other control flow structures include a count
 of the number of locals at the time of their creation. A given block of locals must be defined on one line.
 
 A given word can make use of up to 128 bytes of locals.
 
 Syntax `{ [type1] <name1> [[type2] <name2> ... ] [ -- comment ] }`
 
 | Type | Description |
 | --- | --- |
 | W: | Cell Value |
 | W^ | Cell Variable |
 | C: | Character Value |
 | C^ | Character Variable |

 Value locals produce their value, and can be changed via `TO`. Variable locals produce their address.
 
 Aside from value-vs-variable, types currently have no effect.
 
 * [\{](/locals/lbrace.md)
 