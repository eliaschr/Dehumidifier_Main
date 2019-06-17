;*********************************************************************************************
;* Math Library                                                                              *
;*-------------------------------------------------------------------------------------------*
;* Library with math procedures.                                                             *
;*-------------------------------------------------------------------------------------------*
;* Names And Values:                                                                         *
;* DIV_QSIGN : is the bit mask for storing the resulting sign of quotient                    *
;* DIV_RSIGN : is the bit mask for storing the resulting sign of remainder                   *
;*===========================================================================================*
;* Functions of the Library:                                                                 *
;* Div32By16 : Divides a 32 Bit signed number by a 16 Bit Signed number                      *
;* LineFunc  : Gives the resulting f(x)=ax+b, by giving the Min, Max and x                   *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Math.h43"				;Global Math definitions


;----------------------------------------
; Definitions
;========================================
DIV_QSIGN:	.equ	08000h					;The bit mask in R15 which stores the
											; sign of the Quotient
DIV_RSIGN:	.equ	04000h					;The bit mask in R15 which stores the
											; sign of the Remainder


;----------------------------------------
; Variables
;========================================
			.bss	Divident, 8
			.bss	Divisor, 4


;----------------------------------------
; Functions
;========================================
			.text

;----------------------------------------
; Div64By32
; Devides a 64 bit number by a 32 bit number.
; INPUT         : R4 points to the divident (8 bytes).
;                 R5 points to the divisor (4 bytes).
;                 R6 points to the remainder buffer (4 bytes)
;                 R7 points to the quotient buffer (8 bytes)
; OUTPUT        : Carry Flag is set if division by zero attempted, else it is cleared
; REGS USED     : R4, R5, R6, R7, R14, R15
; REGS AFFECTED : R14, R15
; STACK USAGE   : 4 (2x Push)
; VARS USED     : DIV_QSIGN, DIV_RSIGN, Divident, Divisor
; OTHER FUNCS   : None
Div64By32:
			MOV		@R5+,R14				;Check if the divisor is 0
			BIS		@R5,R14
			SUB		#00002h,R5				;Move R5 pointer to its place
			CMP		#00000h,R14				;Is it 0?
			JZ		Div64by0				;Yes => Divide by zero detected

			MOV		@R4+,R14				;else, lets check if the divident is 0
			BIS		@R4+,R14
			BIS		@R4+,R14
			BIS		@R4,R14
			SUB		#00006h,R4				;Move R4 pointer to its original place
			CMP		#00000h,R14				;Is the result 0?
			JNZ		Div64Start				;No => perform the division

			MOV		#00000h,R14				;else, going to zero the result
			CLRC							;and keep carry flag cleared
			JMP		Div64Exit				;Store the result and exit

Div64by0:	SETC							;Carry flag is set
			MOV		#0FFFFh,R14				;Division by zero means...
Div64Exit:	MOV		R14,0(R6)				;Store remainder
			MOV		R14,2(R6)
			MOV		R14,0(R7)				;Store quotient
			MOV		R14,2(R7)
			MOV		R14,4(R7)
			MOV		R14,6(R7)
			RET								;Return to caller

Div64Start:	PUSH	R4
			PUSH	R5
			MOV		#Divident,R14			;Copy input divident to a temporary space
			MOV		@R4+,0(R14)
			MOV		@R4+,2(R14)
			MOV		@R4+,4(R14)
			MOV		@R4,6(R14)
			MOV		#Divident,R4			;Going to use the temporary divident
			MOV		#Divisor,R14			;Copy the divider to a temporary space
			MOV		@R5+,0(R14)
			MOV		@R5,2(R14)
			MOV		#Divisor,R5				;Going to use the temporary divider

			MOV		#00040h,R15				;Counter of bits to process
			MOV		#0FFFFh,R14				;Helper register to invert numbers if negative
			BIC		#DIV_QSIGN+DIV_RSIGN,R15
											;Clear the flag bit of the results of the division
											; High byte of R15 serves as helper flags
			BIT		#08000h,6(R4)			;Is Divident negative?
			JZ		Div64PDvdnt				;NO=>Keep on PlusDvdnt
			BIS		#DIV_RSIGN,R15			;Remainder should be negative in that case
			XOR		#DIV_QSIGN,R15			;else, Change quotient sign
			XOR		R14,0(R4)				;and make divident a positive number
			XOR		R14,2(R4)
			XOR		R14,4(R4)
			XOR		R14,6(R4)
			INC		0(R4)
			ADC		2(R4)
			ADC		4(R4)
			ADC		6(R4)

Div64PDvdnt:
			BIT		#08000h,2(R5)			;Is Divisor a negative number?
			JZ		Div64PDvsr				;NO=>Keep on PlusDvsr
			XOR		#DIV_QSIGN,R15			;else, Change the sign of quotient
			XOR		R14,0(R5)				;and make the divisor a positive number
			XOR		R14,2(R5)
			INC		0(R5)
			ADC		2(R5)

Div64PDvsr:
			MOV		#00000h,R14				;Going to zero the result
			MOV		R14,0(R6)				;Clear remainder
			MOV		R14,2(R6)
			MOV		R14,0(R7)				;Store quotient
			MOV		R14,2(R7)
			MOV		R14,4(R7)
			MOV		R14,6(R7)

Div64Rpt:	ADD		@R4,0(R4)				;Shift Divident one bit left. The MSb is ...
			ADDC	2(R4),2(R4)
			ADDC	4(R4),4(R4)
			ADDC	6(R4),6(R4)
			ADDC	@R6,0(R6)				;...pushed into the Remainder, and the LSb is 0
			ADDC	2(R6),2(R6)

			CMP		2(R5),2(R6)				;Is current Remainder>=Divisor (High word...)
			JLO		D64InsZero				;Lower? => Don't add anything
			JEQ		D64TestLow				;Equal? => Need to test lower word also
			;Remainder is greater than divisor...
			BIS		#00001h,0(R4)			;Set BIT0 of Quotient (in place of divident)
			SUB		@R5,0(R6)				;SUB Divisor from Remainder
			SUBC	2(R5),2(R6)
			JMP		D64InsZero

D64TestLow:	CMP		@R5,0(R6)				;Remainder>=Divisor? (again, lower word now)
			JLO		D64InsZero				;No => Keep on...
			BIS		#00001h,0(R4)			;else, Set BIT0 of Quotient
			SUB		@R5,0(R6)				;SUB Divisor from Remainder
			SUBC	2(R5),2(R6)
D64InsZero:	DEC		R15						;Decrement number of bits remain to process
			BIT		#000FFh,R15				;Test if low byte is 0
			JNZ		Div64Rpt				;Any bits left?=>RepeatDiv

			MOV		@R4+,0(R7)
			MOV		@R4+,2(R7)
			MOV		@R4+,4(R7)
			MOV		@R4,6(R7)
			MOV		#0FFFFh,R14				;prepare for sign inversion
			BIT		#DIV_QSIGN,R15			;else, check the sign of the quotient
			JZ		Div64Rem				;If should be positive, then Div32x16Out

			XOR		R14,0(R7)				;else, make the quotient negative
			XOR		R14,2(R7)
			XOR		R14,4(R7)
			XOR		R14,6(R7)
			INC		0(R7)
			ADC		2(R7)
			ADC		4(R7)
			ADC		6(R7)

Div64Rem:	BIT		#DIV_RSIGN,R15			;Should Remainder be negative?
			JZ		Div64Out				;NO=>Exit
			XOR		R14,0(R6)				;else, make the Remainder negative
			XOR		R14,2(R6)
			INC		0(R6)
			ADC		2(R6)
Div64Out:	POP		R5						;Restore input variables
			POP		R4
			CLRC							;Clear carry flag (Division OK)
			RET								;and return to caller


;----------------------------------------
; Div32By16
; Devides a 32 bit number by a 16 bit number.
; INPUT         : R4R5 contains the divident.
;                 R6 contains the divisor.
; OUTPUT        : R4R5 contains the quotient
;                 R7 contains the remainder
;                 Carry Flag is set if division by zero attempted, else it is cleared
; REGS USED     : R4, R5, R6, R7, R15
; REGS AFFECTED : R4, R5, R7
; STACK USAGE   : 4 (2x Push)
; VARS USED     : DIV_QSIGN, DIV_RSIGN
; OTHER FUNCS   : None
Div32By16:	CMP		#00000h,R6				;Is the Divisor 0? (Div By Zero)
			JZ		DivByZero				;YES=>Exit With DivByZero
			CMP		#00000h,R5				;else, is the divident equal to zero?
			JNZ		StartDiv
			CMP		#00000h,R4
			JNZ		StartDiv				;NO=>OK Start Division Procedure
			MOV		R4,R7					;else exit with all zero
			CLRC							;even carry=0
			RET								;Return to caller
DivByZero:	MOV		#0FFFFh,R4				;Div By Zero means quotient=max
			MOV		R4,R5
			MOV		R4,R7					;remainder=max
			SETC							;carry is set
			RET								;Return to caller
StartDiv:	PUSH	R6
			PUSH	R15
			MOV.B	#020h,R15				;The number of bits to be processed is 32
			BIC		#DIV_QSIGN+DIV_RSIGN,R15
											;Clear the flag bit of the results of the division
											; High byte of R15 serves as helper flags
			BIT		#08000h,R4				;Is Divident negative?
			JZ		PlusDvdnt				;NO=>Keep on PlusDvdnt
			BIS		#DIV_RSIGN,R15			;Remainder should be negative in that case
			XOR		#DIV_QSIGN,R15			;else, Change quotient sign
			XOR		#0FFFFh,R5				;and make divident a positive number
			XOR		#0FFFFh,R4
			INC		R5
			ADC		R4
PlusDvdnt:	BIT		#08000h,R6				;Is Divisor a negative number?
			JZ		PlusDvsr				;NO=>Keep on PlusDvsr
			XOR		#DIV_QSIGN,R15			;else, Change the sign of quotient
			XOR		#0FFFFh,R6				;and make the divisor a positive number
			INC		R6
PlusDvsr:
			CLR		R7						;Remainder is cleared
RepeatDiv:	ADD		R5,R5					;Shift Divident one bit left. The MSb is
			ADDC	R4,R4					; pushed into the Remainder, and the LSb is 0
			ADDC	R7,R7
			CMP		R6,R7					;Is current Remainder>=Divisor
			JNC		DInsZero				;NO=>(Carry=0) Keep on DInsZero
			BIS		#00001h,R5				;else, Set BIT0 of Quotient
			SUB		R6,R7					;and SUB Divisor from Remainder
DInsZero:	DEC		R15						;Decrement number of bits remain to process
			BIT		#000FFh,R15				;Test if low byte is 0
			JNZ		RepeatDiv				;Any bits left?=>RepeatDiv
			BIT		#DIV_QSIGN,R15			;else, check the sign of the quotient
			JZ		Div32x16Rem				;If should be positive, then Div32x16Out
			XOR		#0FFFFh,R5				;else, change quotient to negative
			XOR		#0FFFFh,R4
			INC		R5
			ADC		R4
Div32x16Rem:BIT		#DIV_RSIGN,R15			;Should Remainder be negative?
			JZ		Div32x16Out				;NO=>Exit
			XOR		#0FFFFh,R7				;else, make the Remainder negative
			INC		R7
Div32x16Out:POP		R15
			POP		R6
			CLRC							;Clear carry flag (Division OK)
			RET								;and return to caller


;----------------------------------------
; LineFunc
; Returns the result of the line function f(x)=ax+b, calculated by Minimum and
; Maximum values of f(x) for x=[0, 4096]. The actual function is:
; f(x) = [(Max - Min)/4096]x + Min
; INPUT         : R4R5 is the Max value (21 bit signed number)
;                 R6R7 is the Min value (21 bit signed number)
;                 R8 is the x value (12 bit unsigned number)
; OUTPUT        : R4R5 contains the f(x)
; REGS USED     : R4, R5, R6, R7, R8
; REGS AFFECTED : R4, R5, R8
; STACK USAGE   : 2 (1x Push)
; VARS USED     : None
; OTHER FUNCS   : None
LineFunc:	SUB		R7,R5					;R4R5 = R4R5-R6R7
			SUBC	R6,R4					;22 bit signed sum
			ADD		R8,R8					;This is another trick! Multiply x by 16
			ADD		R8,R8					; and then make the multiplication of
			ADD		R8,R8					; x times (Max-Min). Then divide the
			ADD		R8,R8					; result by 65536 instead of 4096.
											;This is faster because no real division is
											; made. Instead a moving of whole words is
											; the solution and is faster than anything
											; else.
			PUSH	SR						;Multiplier needs interrupts to
											; be disabled, so store interrupts
			DINT							; status and disable them
			NOP								;A little wait, for DINT
			MOV		R8,&MPY					;x times R5, unsigned multiplication
			MOV		R5,&OP2					;Start it
			MOV		&RESHI,R5				;Get the high word of the result and ignore
											; low word.
			MOV		R4,&OP2					;x times R4, unsigned multiplication
			ADD		&RESLO,R5
			MOV		&RESHI,R4
			POP		SR						;Restore interrupt flag
			ADD		R7,R5					;Add Min value to R4R5
			ADDC	R6,R4					;and now R4R5 contains the result of the
											; formula needed
			RET


;----------------------------------------
; Mul32x32
; Performs the multiplication of two unsigned 32 bit numbers. The function uses the hardware
; multiplier of the microcontroller
; INPUT         : R4 points to the first 32 bit number to be multiplied
;                 R5 points to the second 32 bit number
;                 R15 points to the target buffer that will hold the result (8 bytes)
; OUTPUT        : R15 points to the 64 bit buffer that contains the result
;                 Carry Flag contains the resulting carry of the operation
; REGS USED     : R4, R5, R6, R7, R8
; REGS AFFECTED : R6, R7, R8
; STACK USAGE   : 6 bytes (=3x Push)
; VARS USED     : None
; OTHER FUNCS   : None
Mul32x32:
			PUSH	R4						;Store the input registers
			PUSH	R5
			MOV		@R4+,R6					;R7:R6 contains the first number
			MOV		@R4,R7
			MOV		R15,R4					;Now R4 points to the target buffer
			PUSH	SR						;Store interrupt status in stack
			DINT							;Ensure interrupts are disabled
			NOP
			MOV		R6,&MPY					;Going to unsigned multiply W1l by W2l
			MOV		@R5,&OP2				;(R5 points to W2l)
			NOP
			MOV		&RESLO,0(R4)			;Store the 32 bits result to lower space
			MOV		&RESHI,2(R4)
			INCD	R4
			MOV		&RESHI,&RESLO			;Shift the result 16 bit right
			MOV		#00000h,&RESHI
			MOV		@R5+,&MAC				;Going to multiply W1h x W2l and add it to the
			MOV		R7,&OP2					; previously shifted result (R5 after that points
											; to W2h)
			NOP
			MOV		&SUMEXT,R8				;Get the possible carry from the previous MAC
			MOV		@R5,&MAC				;Going to multiply W1l x W2h
			MOV		R6,&OP2
			NOP
			ADD		&SUMEXT,R8				;Now RESHI:RESLO contain the two middle words
			MOV		&RESLO,0(R4)
			MOV		&RESHI,2(R4)
			MOV		&RESHI,&RESLO			;Shift the result 16 bits right
			MOV		R8,&RESHI
			INCD	R4						;R4 points to the two higher words of the result
			MOV		@R5,&MAC				;Going to multiply W1h x W2h and add it to the
			MOV		R7,&OP2					; previously shifted result
			NOP
			MOV		&RESLO,0(R4)
			MOV		&RESHI,2(R4)
			POP		SR						;Restore interrupts
			POP		R5						;Restore the input registers
			POP		R4
			CMP		#00001h,&SUMEXT			;Fix the carry flag
			RET

