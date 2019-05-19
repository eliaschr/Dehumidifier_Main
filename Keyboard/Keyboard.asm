;*********************************************************************************************
;* Keyboard Library                                                                          *
;*-------------------------------------------------------------------------------------------*
;* Keyboard.asm                                                                              *
;* Author: eliaschr                                                                          *
;* Copyright (c) 2019, Elias Chrysocheris                                                    *
;*                                                                                           *
;* This program is free software: you can redistribute it and/or modify                      *
;* it under the terms of the GNU General Public License as published by                      *
;* the Free Software Foundation, either version 3 of the License, or                         *
;* (at your option) any later version.                                                       *
;*                                                                                           *
;* This program is distributed in the hope that it will be useful,                           *
;* but WITHOUT ANY WARRANTY; without even the implied warranty of                            *
;* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                             *
;* GNU General Public License for more details.                                              *
;*                                                                                           *
;* You should have received a copy of the GNU General Public License                         *
;* along with this program.  If not, see <https://www.gnu.org/licenses/>.                    *
;*-------------------------------------------------------------------------------------------*
;* Library of procedures for connecting a keyboard of 5 buttons to a MSP430 uP, using        *
;* 5 port bits. One for each key. The keyboard supports non-repetitive and repetitive keys,  *
;* long pressing and multipressing.                                                          *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"Keyboard Library"
			.width	94
			.tab	4

;*===========================================================================================*
;* Names And Values:                                                                         *
;* ------------------                                                                        *
;* KBD_KEY0   : First key of the keyboard mask (Lower bit).                                  *
;* KBD_KEY1   : Second key                                                                   *
;* KBD_KEY2   : Third key                                                                    *
;* KBD_KEY3   : Fourth key                                                                   *
;* KBD_KEY4   : Fifth key                                                                    *
;* KBD_KMASK  : The mask of all the keys that belong to keyboard                             *
;* KBD_KEYEND : The last key (Most Significant bit)                                          *
;* KBD_KEYPWR : The key ID for Power Button                                                  *
;* KBD_1sFACT : Number of Timer clock ticks that define 1 second delay                       *
;* KBD_LPCOUNT: Number of seconds until a long press is considered                           *
;*                                                                                           *
;*===========================================================================================*
;* Variables:                                                                                *
;* -----------                                                                               *
;* KeyBuffer : Cyclic buffer that holds the keystrokes until they are consumed               *
;* KBStPoint : Starting offset of first keystroke in buffer. The buffer is a circular one.   *
;* KBuffLen  : Length of keystrokes in keyboard buffer                                       *
;* LastKey   : Last key press read (to ensure stability)                                     *
;* LastDelay : Last time interval used for key acceptance                                    *
;* LPCounter : The Long Press conter of seconds                                              *
;*                                                                                           *
;*===========================================================================================*
;* Functions of the Library:                                                                 *
;* KBDPInit    : Initializes the ports used for keyboard controlling and reading             *
;* KBDTInit    : Initializes the timer used for keyboard timings                             *
;* KeyboardInit: Initializes the resourses of the uC needed for correct functioning of the   *
;*               keyboard                                                                    *
;* KBDEINT     : Enables interrupts from keyboard port                                       *
;* KBDDINT     : Disables interrupts from keyboard port                                      *
;* KBDREAD     : Reads a key from the keyboard and returns its code                          *
;* KBDReadKey  : Reads a key from the keyboard buffer, if there is any                       *
;* KBDKeyPress : The Interrupt Service Routine of a key press (I/O port pins)                *
;* KBRepInt    : The Interrupt Service Routine for key Debouncing and Repetition             *
;* KBDTimerISR : The Interrupt Service Routine of the associated timer module's CCR1         *
;* LongPrInt   : The Interrupt Service Routine of the associated timer module's CCR0         *
;*                                                                                           *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Board.h43"			;Hardware Connections
			.include "Definitions.h43"		;Global definitions
			.include "Keyboard.h43"			;Local definitions
			.include "KeybAutoDefs.h43"		;Auto definitions according to settings in
											; Keyboard.h43


;----------------------------------------
; Definitions
;========================================
;The code in this library expexts the following definitions
;Board_KeyPort								;The port number the keys are connected to
;Board_Key0									;Abstruct key 0
;Board_Key1									;Abstruct key 1
;Board_Key2									;Abstruct key 2
;Board_Key3									;Abstruct key 3
;Board_Key4									;Abstruct key 4
;
;KBD_DIN									;Data input register from keyboard
;KBD_DOUT									;Data output register for keyboard
;KDB_DIR									;Direction selection register for key pins
;KBD_REN									;Resistor setup register for key pins
;KBD_SEL0									;Special function selection registers
;KBD_SEL1
;KBD_INTE									;Interrupt enable register for keypresses
;KBD_INTES									;Interrupt edge selector register 
;KBD_INTF									;Interrupt flags reflecting the keypresses
;KBD_INTV									;Interrupt vector register
;KBD_Vector									;Interrupt Vector Segment

KBD_KEY0:	.equ	Board_Key0				;Selection of Key 0
KBD_KEY1:	.equ	Board_Key1				;Selection of Key 1
KBD_KEY2:	.equ	Board_Key2				;Selection of Key 2
KBD_KEY3:	.equ	Board_Key3				;Selection of Key 3
KBD_KEY4:	.equ	Board_Key4				;Selection of Key 4
KBD_KMASK:	.equ	(KBD_KEY0 | KBD_KEY1 | KBD_KEY2 | KBD_KEY3 | KBD_KEY4)
											;The bit mask of the keys for reading
KBD_KEYEND:	.equ	KBD_KEY4				;Final key to check
KBD_KEYPWR:	.equ	KEYPOWER				;Selection of Power Key

KBD_1sFACT:	.equ	08000h					;Factor for counting 1 second of Timer
KBD_LPCOUNT:.equ	3						;Number of times the CCR0 will be triggered to
											; evaluate Long Key press


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	KeyBuffer, KBUFSIZE		;Cyclic buffer that holds the keystrokes
			.bss	KBStPoint, 2			;Starting offset of first keystroke in buffer
			.bss	KBuffLen, 2				;Length of keystrokes in keyboard buffer
			.bss	LastKey, 2				;Last key press read (to ensure stability)
			.bss	LastDelay, 2			;Last time interval used for key acceptance
			.bss	LPCounter, 2			;The Long Press conter of seconds

			.global KeyBuffer				;Only for testing purposes. CCS needs to have it
											; global in order to watch it in memory pane


;----------------------------------------
; Functions
;========================================
			.text
;Interrupt Service Routines must be global
			.global KBDKeyPress
			.global KBRepInt
			.global LongPrInt
			.global	KBDTimerISR

;----------------------------------------
; KBDPInit
; Initializes the port pins the keyboard is connected to.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : KBD_DIR, KBD_INTE, KBD_INTES, KBD_INTF, KBD_KEYPWR, KBD_KMASK, KBD_SEL0,
;                 KBD_SEL1
; OTHER FUNCS   : None
KBDPInit:	BIC.B	#KBD_KMASK,&KBD_SEL0	;Keyboard input pins are used as simple I/O pins
			BIC.B	#KBD_KMASK,&KBD_SEL1
			BIC.B	#KBD_KMASK,&KBD_DIR		;Keyboard pins function as inputs
			BIC.B	#KBD_KMASK,&KBD_INTE	;Disable interrupts from this port pin
			BIS.B	#KBD_KMASK,&KBD_INTES	;Interrupt is fired by a High-To-Low transition
			;An example of a power key that provides the power through it, it usualy uses
			; the rising edge to fire an interrupt
;			BIC.B	#KBD_KEYPWR,&KBD_INTES	;Interrupt of power button is fired by Low-to-Hi
											; transition
			BIC.B	#KBD_KMASK,&KBD_INTF	;Interrupt flag is reset: No Pending Interrupt
			BIS.B	#KBD_KEYPWR,&KBD_INTE	;Enable the interrupt for Power Down key
			RET


;----------------------------------------
; KeyboardInit
; Initializes the port pins the keyboard is connected to.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 2 = 1 Call
; VARS USED     : None
; OTHER FUNCS   : KBDPInit, KBDTInit
KeyboardInit:
			CALL	#KBDPInit
			;JMP	KBDTInit				;Since KBDTInit follows there is not need to use
											; this instruction. It"s just placed here for
											; clarity.


;----------------------------------------
; KBDTInit
; Initializes the port pins the keyboard is connected to.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : KBDTCTL, KBDTCCTL0, KBDTCCTL1, KBDTR
; OTHER FUNCS   : None
KBDTInit:
			BIS		#TASSEL0,&KBDTCTL		;Keyboard Timer clocking from ACLK (32768 Hz)
			BIC		#CCIE+CCIFG,&KBDTCCTL0	;Clear interrupts from CC0
			BIC		#CCIE+CCIFG,&KBDTCCTL1	;Clear interrupts from CC1
			CLR		&KBDTR					;Clear Keyboard Timer counter register
			RET


;----------------------------------------
; KBDEINT
; Enables the keyboard interrupt.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : KBD_INTE, KBD_INTES, KBD_INTF, KBD_KMASK
; OTHER FUNCS   : None
KBDEINT:	BIS.B	#KBD_KMASK,&KBD_INTES	;Interrupt is fired by a High-To-Low transition
			BIC.B	#KBD_KMASK,&KBD_INTF	;Interrupt flag is reset: No Pending Interrupt
			BIS.B	#KBD_KMASK,&KBD_INTE	;Enable interrupts coming from this port pins
			RET


;----------------------------------------
; KBDDINT
; Disables the keyboard interrupt.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : KBD_INTE, KBD_KMASK
; OTHER FUNCS   : None
KBDDINT:	BIC.B	#KBD_KMASK,&KBD_INTE	;Disable interrupts from this port pin
			RET


;----------------------------------------
; KBDReadKey
; This process reads a key from the keyboard buffer. If the keyboard buffer is empty it
; returns zero and sets the carry flag.
; INPUT         : None
; OUTPUT        : R4 contains the keycode
;                 Carry flag is zero if there is a valid keycode, else it is set
; REGS USED     : R4
; REGS AFFECTED : R4
; STACK USAGE   : None
; VARS USED     : KBStPoint, KBuffLen, KBUFSIZE, KeyBuffer
; OTHER FUNCS   : None
KBDReadKey:	CMP		#00000h,&KBuffLen		;Is there any key in the buffer?
			JZ		KBDSetExit				;No => Exit
			MOV		&KBStPoint,R4			;else, get the starting offset of the key buffer
			ADD		#KeyBuffer,R4			;Add the Memory offset of the buffer
			MOV.B	@R4,R4					;Get the current key
			INC		&KBStPoint				;Advance the starting pointer of the buffer by 1
			AND		#KBUFSIZE-1,&KBStPoint	;MOD, the buffer is cyclic
			DEC		&KBuffLen				;Now the buffer contains one key less
			CLRC							;Clear Carry, R4 contains a valid key!
			RET								;Return to caller
KBDSetExit:	MOV.B	#000h,R4				;Clear R4
			SETC							;Set Carry, no more keys
			RET								;and return to calling process


;----------------------------------------
; KBDKeyPress Interrupt Service Routine
; Although this routine is written as an ISR, it may be called through a shared interrupt like
; the interrupt from Port 1 or Port 2. In this case a dispatcher routine is needed
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4, R5
; REGS AFFECTED : None
; STACK USAGE   : 4 = 2x Push
; VARS USED     : KBD_DIN, KBD_INTE, KBD_INTES, KBD_INTF, KBD_KMASK, KBD_KEYPWR, KBDTCCTL1,
;                 KBDTCCR1, KBDTCTL, KBDTR, KBUFSIZE, Key1stRep, KeyDebounc, LastKey
; OTHER FUNCS   : None
KBDKeyPress:
			BIT.B	#KBD_KMASK,&KBD_INTF	;Does this interrupt come from keyboard?
			JZ		NoKeyPress				;No => Ignore this interrupt, Exit
			PUSH	R4
			MOV.B	&KBD_DIN,R4				;Get the current status of the keys
			AND.B	#KBD_KMASK,R4			;Filter only the bits of the keys
			BIC.B	#KBD_KMASK,&KBD_INTES	;Set temporarilly all keyboard interrupts to be
											; triggered from a Low -> High transition (Break)
			BIS.B	R4,&KBD_INTES			;Depressed keys' interrupts are triggered by a
											; High -> Low transition.
			BIC.B	#KBD_KMASK,&KBD_INTF	;Clear spurious interrupt flags
			CMP.B	#KBD_KMASK,R4			;Are all the keys released?
			JEQ		KBDBreakK				;Yes, we have a complete break
			XOR		#KBD_KMASK,R4			;Invert all bits. That is the real key code

			;Now R4 contains the bitmap of the pressed keys.

			;The following code performs some filtering on accepted keystrokes. If an invalid
			; keystroke is recognised then R4 is cleared to simulate no keypress
			BIT.B	#KBD_MULTIMASK,R4		;Is there any key of the multipressed allowed ones
											; activated?
			JZ		KBRChkNorm				;No => OK, Check the normal keys one by one
			;At least one of the Nultipress group of keys is active. It is invalid to have one
			; active key at the same time that belongs to single press group.
			BIT.B	#~KBD_MULTIMASK,R4		;Is there any non-multi press key active?
			JNZ		KBRNotFnd				;Yes => Act as if no key is pressed (invalid
											; combination)
			JMP		KBRFound				;else, accept the keypress
			;The following code checks the keypresses that belong to the single press group.
			; Of course, multi pressed group is also acceptable (but this is filtered earlier)
KBRChkNorm:	PUSH	R5						;Need R5 to scan for the accepted keypresses
			MOV.B	#KBD_KEY0,R5			;R5 contains the first key mask
KBRChkNxt:	CMP.B	R4,R5					;Pressed key same as R5?
			JZ		KBRFoundR5				;Yes => Found, so exit
			CMP.B	#KBD_KEYEND,R5			;else, Does R5 contain the last key code?
			JZ		KBRNotFndR5				;Yes => then no clear key found
KBRAccept:	ADD		R5,R5					;Shift R5 to the next key code
			JMP		KBRChkNxt				;Repeat check
			
KBRNotFndR5:POP	R5							;Restore the used register, not needed anymore
KBRNotFnd:	XOR		R4,R4					;No key found or more than one keys are pressed,
											; so clear R4

			;A total key break means that the timer should be stopped
KBDBreakK:	POP		R4
NKPStop:	BIC 	#MC1,&KBDTCTL			;Stop TimerA running
			BIC		#CCIE+CCIFG,&KBDTCCTL1	;Stop the interrupts from debouncing CCR
			BIC		#CCIE+CCIFG,&KBDTCCTL0	;Stop the interrupts from Long Press CCR
			MOV		#00000h,&KBDTR			;Clear TimerA counter register
			MOV		#00000h,&LastKey		;Clear last key pressed
NKPNoStop:	BIC.B	#KBD_KMASK,&KBD_INTF	;Reset any pending keyboard interrupts
			RETI							;And return to interrupted process

KBRFoundR5:
			POP	R5							;Restore the used register, not needed anymore

			;Filtering of correct key combination is done. KBRFound is reached only when a
			; valid key combination is active
KBRFound:	;R4 Contains the accepted keypress code or Zero if there are more than one keys
			; pressed
			CMP		R4,&LastKey				;Do we have the same keypress as before?
			MOV		R4,&LastKey				;Store the found keycode in the LastKey variable
			JEQ		KBDSameKey				;No change since the last sensed keypress
											; so, do not do anything...
			MOV		#KeyDebounc,&KBDTCCR1	;Key debounce time set to 10ms
			MOV		#00000h,&LastDelay		;Clear the Last Delay used variable
			ADD		&KBDTR,&KBDTCCR1		;... from now
			BIC		#CCIFG+CCIE,&KBDTCCTL0	;Long press interrupts are not in use for the time
			BIC		#CCIFG,&KBDTCCTL1		;Clear the expiration flag of Compare 1
			BIS		#CCIE,&KBDTCCTL1		;Enable its interrupt
			BIS		#MC1,&KBDTCTL			;Start timer in continuous counting mode
KBDSameKey:
			POP		R4						;Restore registers
NoKeyPress:
			RETI							;Exit interrupt


;----------------------------------------
; Keyboard Timer CCR1 Interrupt (TimerA type)
; Interrupt of key debouncing and repetition
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : KBRepInt
KBDTimerISR:
			ADD		&KBDTIV,PC				;Jump to the correct element of the ISR table
			RETI							;Vector 0: No Interrupt
			JMP		KBRepInt				;Vector 2: Timer CCR1 CCIFG
			RETI							;Vector 4: Timer CCR2 CCIFG
			RETI							;Vector 6: Reserved
			RETI							;Vector 8: Reserved
			RETI							;Vector A: TAIFG


;----------------------------------------
; KBRepInt Interrupt Service Routine
; This is an Interrupt Service Routine, that is called by the Keyboard Timer CCR1 interrupt
; vector. It inserts another 'Last Key' in the keyboard buffer at the right time intervals as
; long as this key is still pressed.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4, R15
; REGS AFFECTED : None
; STACK USAGE   : 4 = 2x Push
; VARS USED     : KBD_1sFACT, KBD_DIN, KBD_INTE, KBD_INTES, KBD_KEYPWR, KBD_KMASK,
;                 KBD_LONGMASK, KBD_LPFLAG, KBD_SINGLEMASK, KBDTCCR0, KBDTCCR1, KBDTCCTL0,
;                 KBDTCCTL1, KBDTCTL, KBDTR, KBUFSIZE, KBStPoint, KBuffLen, Key1stRep,
;                 KeyBuffer, KeyUpdRep, LastDelay, LastKey, LPCounter
; OTHER FUNCS   : None
KBRepInt:
			PUSH	R4						;Store R4, we are going to need it
			;First check if there is any key pressed
			MOV.B	&KBD_DIN,R4				;Get the key that is being pressed now
			AND.B	#KBD_KMASK,R4			;Filter only the key bits
			XOR.B	#KBD_KMASK,R4			;Invert all bits. That is the real key code
			JZ		KBTimStop				;If there is no key pressed then stop repetition
			;Now lets see if the keypress is the same as earlier. Only the key bits must be
			; checked; the special bits (as Long Press flag) must be filtered out
			PUSH	R15						;Need R15 to compare the filter key combination
			MOV.B	&LastKey,R15			;Get the last key
			AND.B	#KBD_KMASK,R15			;Keep only the keypress code
			CMP.B	R15,R4					;Is this key the same as the previous?
			JNZ		KBTimStopR15			;No => Stop repetition
			;Try to store the keypress in the buffer. The key to be stored is the same as the
			; one at LastKey variable, to include the special flags, as those reflect a state
			; that is not changed
			CMP		#KBUFSIZE,&KBuffLen		;Is the keyboard buffer full?
			JZ		KBTNoStoreR15			;Ignore this key, but continue the repetition
			MOV		&KBStPoint,R15			;Get the starting offset of the keyboard buffer
			ADD		&KBuffLen,R15			;Add the number of the occupied cells
			AND		#KBUFSIZE-1,R15			;MOD because this is a circular buffer
			ADD		#KeyBuffer,R15			;Add the starting memory of the buffer. Now R15
											; points to the first free cell in the keyboard
											; circular buffer
			MOV.B	&LastKey,0(R15)			;Store key again
			INC		&KBuffLen				;Increment the buffer size
			BIC		#SCG0+SCG1+OSCOFF+CPUOFF,4(SP)	;Wake up the system to use the new key
											;Need 4 bytes offset since R15 and R4 are still in
											; the stack.

			;Another key is inserted in the keyboard buffer
KBTNoStoreR15:
			POP		R15						;Restore R15
KBTNoStore:			
			;In case of a non-repeatable key there should be no retriggering of the interrupt
			BIT.B	#KBD_SINGLEMASK & ~KBD_LONGMASK,R4	;So, filter single press keys
			JNZ		KBTimStop				;If any => DO NOT RETRIGGER CCR1
			;In case of a Long-press key (single press or not) after debouncing we have to
			; use CCR0 to evaluate the long press.
			BIT.B	#KBD_LONGMASK,R4		;Long press evaluation needed?
			JZ		KBTRetrigger			;No => Then we need to retrigger the repetition
			BIT.B	#KEY_LPFLAG,&LastKey	;Did we perform long press already?
			JNZ		KBTRetrigger			;Yes => Perform a normal retrigger
			;Setup CCR0 to perform Long press evaluation
			MOV		#00000h,&LPCounter		;Clear the long press coutner.
			MOV		#KBD_1sFACT,R4
			MOV		R4,&LastDelay			;Set the last delay factor used
			ADD		#KBDTR,R4				;Add now
			MOV		R4,&KBDTCCR0			;Set CCR0 for 1 second counting
			BIC		#CCIFG,&KBDTCCTL0		;Clear any pending interrupt from CCR0
			BIS		#CCIE,&KBDTCCTL0		;Enable CCR0 interrupt
			BIC		#CCIE+CCIFG,&KBDTCCTL1	;Stop interrupts from CCR1 (No debouncing or rep.)
			;BIS	#MC1,&KBDTCTL			;Should start timer counting, but it is already
											; running. This line is for clarity only
			POP		R4						;Restore R4
			RETI							;Return to interrupted process
			
			;The code enters this part if it needs to retrigger the keypress (Repetition)
KBTRetrigger:
			MOV		#KeyUpdRep,R4			;Setup the repeat time interval
			CMP		#00000h,&LastDelay		;Is the Last Delay used?
			JNE		KBTStoreD				;Yes => then store this value
			MOV		#Key1stRep,R4			;else, set the first repetition time
KBTStoreD:	MOV		R4,&LastDelay			;Store this value to Last Delay used
			MOV		R4,&KBDTCCR1			;Set the Update Repetition time
			POP		R4
			ADD		&KBDTR,&KBDTCCR1		;Add the 'Now' value of TimerA
			BIC		#CCIFG,&KBDTCCTL1		;Clear the interval expiration flag
			BIC		#CCIE+CCIFG,&KBDTCCTL0	;Stop interrupts from CCR0 (Long pressing)
			RETI

			;When the keypress is wrong, the timer should be stopped
KBTimStopR15:
			POP		R15						;Restore R15
KBTimStop:
			BIC		#MC1,&KBDTCTL			;Stop TimerA from counting
			BIC		#CCIFG+CCIE,&KBDTCCTL1	;Clear the interval expiration flag and
											; disable TimerA Compare 1 interrupt
			BIC		#CCIFG+CCIE,&KBDTCCTL0	;Clear the long press expiration flag and
											; disable TimerA Compare 0 interrupt
			MOV		#00000h,&KBDTR			;Clear TimerA counter register
			MOV		#00000h,&LastKey		;Also, clear the 'Last Pressed Key'
			POP		R4
			RETI


;----------------------------------------
; LongPrInt
; This is an Interrupt Service Routine, that counts the time until it reaches the Long Key
; pressing limit. Since the period of the timer cannot reach the Long Press value, a counter
; is implemented to count the number of times the ISR has been triggered. When it reaches the
; specified value, it considers the key press as a long one and according to the type of the
; key used, it may trigger CCR1 again, to enable repetition
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 4 = 2x Push
; VARS USED     : KBD_1sFACT, KBD_DIN, KBD_KMASK, KBD_SINGLEMASK, KBDTCCR0, KBDTCCTL0,
;                 KBDTCCTL1, KBStPoint, KBuffLen, KBUFSIZE, KEY_LPFlag, KeyBuffer, KeyUpdRep,
;                 LastKey, LPCounter
; OTHER FUNCS   : KBTimStop, KBTStoreD
LongPrInt:
			PUSH	R4						;Store R4, we are going to need it
			;First check if there is any key pressed
			MOV.B	&KBD_DIN,R4				;Get the key that is being pressed now
			AND.B	#KBD_KMASK,R4			;Filter only the key bits
			XOR.B	#KBD_KMASK,R4			;Invert all bits. That is the real key code
			JZ		KBTimStop				;No keypress => Stop Keyboard Timer
			CMP		R4,&LastKey				;Should be equal (No LP Flag, yet)
			JNE		KBTimStop				;Not equal to the last key => Stop Keyboard Timer
			
			;We have the same keypress...
			DEC		&LPCounter				;Decrease the long press timer counter
			JZ		LPI_Accept				;Reached 0? => Accept the long press
			ADD		#KBD_1sFACT,&KBDTCCR0	;Add another second interval
			BIC		#CCIFG,&KBDTCCTL0		;Clear spurious interrupt from LP Timer CCR0
			;Timer keeps running. The ISR will be retriggered after 1 sec
			POP		R4						;Restore R4
			RETI							;Return to interrupted process
			
			;At this point, the key is pressed for the correct long-press time. Need to store
			; the key in the buffer, update the last key variable, check if the key is set as
			; single press and if not, re-enable CCR1 and wake the system up to consume the
			; keypress.
LPI_Accept:	BIS.B	#KEY_LPFLAG,R4			;Raise Long Press flag of the key
			MOV		R4,&LastKey				;Update LastKey value
			PUSH	R15						;Need R15 to store the keypress in buffer
			CMP		#KBUFSIZE,&KBuffLen		;Is the keyboard buffer full?
			JZ		LPI_SkipKeyR15			;Ignore this key, but continue the repetition
			MOV		&KBStPoint,R15			;Get the starting offset of the keyboard buffer
			ADD		&KBuffLen,R15			;Add the number of the occupied cells
			AND		#KBUFSIZE-1,R15			;MOD because this is a circular buffer
			ADD		#KeyBuffer,R15			;Add the starting memory of the buffer. Now R15
											; points to the first free cell in the keyboard
											; circular buffer
			MOV.B	R4,0(R15)				;Store long Pressed key
			INC		&KBuffLen				;Increment the buffer size
			BIC		#SCG0+SCG1+OSCOFF+CPUOFF,4(SP)	;Wake up the system to use the new key
											;Need 4 bytes offset since R15 and R4 are still in
											; the stack.
LPI_SkipKeyR15:
			POP		R15						;Restore R15
			AND.B	#KBD_SINGLEMASK,R4		;Filter only the single press mask to find out if
											; the key belongs to the single pressed group
			JNZ		KBTimStop				;Yes => Do not repeat the key (Stop timer)
			MOV		#KeyUpdRep,R4			;Setup the repeat time interval
			BIS		#CCIE,&KBDTCCTL1		;Enable interrupts from CCR1
			JMP		KBTStoreD				;Prepare the repetition timer
			NOP								;Silicon Errata CPU40: JMP at the end of a section
											; should be followed by a NOP


;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	KBD_Vector				;MSP430 Keyboard Port Interrupt Vector
			.short	KBDKeyPress

			.sect	KBDTVECTOR1				;Keyboard Timer Vector for CCR1 etc. (Debouncing,
			.short	KBDTimerISR				; Repetition)

			.sect	KBDTVECTOR0				;Keyboard Timer Vector for CCR0 (Long press)
			.short	LongPrInt
