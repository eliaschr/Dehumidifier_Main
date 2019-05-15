;*********************************************************************************************
;* Cursor Keyboard Library                                                                   *
;*-------------------------------------------------------------------------------------------*
;* Library of procedures for connecting a keyboard of 4 cursors to a MSP430 uP, using        *
;* 5 port bits. One is the enable and the other four get the pressed keys. The library       *
;* must be included to the main program listing to gain access to the library functions      *
;*-------------------------------------------------------------------------------------------*
;* Names And Values:                                                                         *
;* KBD_COLIN  : is the port of Data bus of the LCD Module                                    *
;* KBD_COLDIR : is the register that specifies the direction of data port                    *
;* KBD_COLSEL : is the Function Select register for the data port                            *
;* KBD_INTF   : is the register that monitors the interrupt flags from keyboard              *
;* KBD_INTS   : is the register that selects the interrupt edge level trigger                *
;* KBD_INTE   : is the keyboard associated interrupt enable register                         *
;* KBD_ROWOUT : is the row port register                                                     *
;* KBD_ROWDIR : is the row port direction register                                           *
;* KBD_ROWSEL : is the row port function select register                                     *
;* KBD_ROWS   : is the mask of the row bits for row port                                     *
;* KBD_KEY0   : is the mask for row 0 selection                                              *
;* KBD_KEY1   : is the mask for row 1 selection                                              *
;* KBD_KEY2   : is the mask for row 2 selection                                              *
;* KBD_KEY3   : is the mask for row 3 selection                                              *
;* KBD_KEY4   : is the mask for row 4 selection                                              *
;* KBD_KEYPWR : is the value of Power button single press                                    *
;* KBD_KEYEND : is the final KBD_KEYx value to be checked while keyboard scanning            *
;*===========================================================================================*
;* Functions of the Library:                                                                 *
;* KBDPINIT   : Initializes the ports used for keyboard controlling and reading              *
;* KBDREAD    : Reads a key from the keyboard and returns its code                           *
;* KBDEINT    : Enables interrupt from keyboard port                                         *
;* KBDDINT    : Disables interrupts from keyboard port                                       *
;* KBDReadKey : Reads a key from the keyboard buffer, if there is any                        *
;* KBDKeyPress: The Interrupt Service Routine of a key press                                 *
;* KBRepInt   : The Interrupt Service Routine when a key is still repeated                   *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
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

;KBD_COLIN:	.equ	P1IN					;The input port of data from keyboard
;KBD_COLDIR:	.equ	KBD_COLIN+2				;Keyboard data port direction register
;KBD_COLSEL:	.equ	KBD_COLIN+3				;Keyboard data port function select register

;KBD_INTDIR:	.equ	P1DIR					;Keyboard Interrupt Port direction register
;KBD_INTF:	.equ	KBD_INTDIR+1			;Keyboard data port interrupt flags
;KBD_INTS:	.equ	KBD_INTDIR+2			;Keyboard data port interrupt edge select
;KBD_INTE:	.equ	KBD_INTDIR+3			;Keyboard data port interrupt enable
;KBD_ISEL:	.equ	KBD_INTDIR+4			;Keyboard Interrupt Port selection register
;KBD_IMASK:	.equ	01Fh					;The interrupt pin mask when a key is pressed
;KBD_PWRMSK:	.equ	POWERINT				;The interrupt pin mask for power button
;KBD_MSKALL:	.equ	KBD_IMASK+KBD_PWRMSK	;Mask for all keyboard interrupt pins


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	KeyBuffer, KBUFSIZE		;Cyclic buffer that holds the keystrokes
			.bss	KBStPoint, 2			;Starting offset of first keystroke in buffer
			.bss	KBuffLen, 2				;Length of keystrokes in keyboard buffer
			.bss	LastKey, 2				;Last key press read (to ensure stability)
			.bss	LastDelay, 2			;Last time interval used for key acceptance
			.bss	PDCounter, 2			;The Countdown while trying to switch on/off

			.global KeyBuffer				;Only for testing purposes. CCS needs to have it
											; global in order to watch it in memory pane


;----------------------------------------
; Functions
;========================================
			.text

;----------------------------------------
; KBDPINIT
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
			JMP		KBDBreakK				;All keys are depressed
			
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
			BIC		#CCIFG,&KBDTCCTL1		;Clear the expiration flag of Compare 1
			BIS		#CCIE,&KBDTCCTL1		;Enable its interrupt
			BIS		#MC1,&KBDTCTL			;Start timer in continuous counting mode
KBDSameKey:
			POP		R4						;Restore registers
NoKeyPress:
			RETI							;Exit interrupt

			;A total key break means that the timer should be stopped
KBDBreakK:	POP		R4
			MOV		#00000h,&LastKey		;Clear last key pressed
			BIC		#CCIE+CCIFG,&KBDTCCTL1	;Stop the interrupts from debouncing CCR
NKPStop:	BIC 	#MC1,&KBDTCTL			;Stop TimerA running
			MOV		#00000h,&KBDTR			;Clear TimerA counter register
NKPNoStop:	BIC.B	#KBD_KMASK,&KBD_INTF	;Reset any pending keyboard interrupts
			RETI							;And return to interrupted process


;----------------------------------------
; Keyboard Timer CCR1 Interrupt (TimerA type)
; Interrupt of key debouncing and repetition
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
KBDTimerISR:
			ADD		&KBDTIV,PC				;Jump to the correct element of the ISR table
			RETI							;Vector 0: No Interrupt
			JMP		KBRepInt				;Vector 2: Timer CCR1 CCIFG
			RETI							;Vector 4: Timer CCR2 CCIFG
			RETI							;Vector 6: Reserved
			RETI							;Vector 8: Reserved
;			JMP		WakeMeUp				;Vector A: TAIFG


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
; VARS USED     : KBD_DIN, KBD_INTE, KBD_INTES, KBD_KEYPWR, KBD_KMASK, KBDTCCR1, KBDTCCTL1,
;                 KBDTCTL, KBDTR, KBUFSIZE, KBStPoint, KBuffLen, Key1stRep, KeyBuffer,
;                 KeyUpdRep, LastDelay, LastKey
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
KBTNoStoreR15:
			POP		R15						;Restore R15
			;Another key is inserted in the keyboard buffer
KBTNoStore:			
			;In case of a non-repeatable key there should be no retriggering of the interrupt
			BIT.B	#KBD_SINGLEMASK & ~KBD_LONGMASK,R4	;So, filter single press keys
			JNZ		KBTimStop				;If any => DO NOT RETRIGGER CCR1
			;In case of a Long-press key (single press or not) after debouncing we have to
			; use CCR0 to evaluate the long press.
			BIT.B	#KBD_LONGMASK,R4		;Long press evaluation needed?
			JZ		KBTSetupLP				;No => 
			BIT.B	#KBD_LPFLAG,&LastKey	;Did we perform long press already?
			JZ		KBTRetrigger			;Yes => Perform a normal retrigger
			;Setup CCR0 to perform Long press evaluation
			
			
			
KBTRetrigger:
			MOV		#KeyUpdRep,R4			;Setup the repeat time interval
			CMP		#00000h,&LastDelay		;Is the Last Delay used?
			JNE		KBTStoreD				;Yes => then store this value
			MOV		#Key1stRep,R4			;else, set the first repetition time
KBTStoreD:	MOV		R4,&LastDelay			;Store this value to Last Delay used
			MOV		R4,&KBDTCCR1			;Set the Update Repetition time
			POP		R4
			BIC		#SCG0+SCG1+OSCOFF+CPUOFF,0(SP)	;Wake up the system to use the new key
			ADD		&KBDTR,&KBDTCCR1		;Add the 'Now' value of TimerA
			BIC		#CCIFG,&KBDTCCTL1		;Clear the interval expiration flag
			RETI

KBTimStopR15:
			POP		R15						;Restore R15
KBTimStop:
			BIT.B	#KBD_KEYPWR,&KBD_INTE	;Is the Power Button Interrupt enabled?
			JZ		NKPStop					;No => Stop timer
			BIT.B	#KBD_KEYPWR,&KBD_INTES	;Does it need the TimerA?
			JC		KBTNoTStop				;Yes => Do not stop TimerA
			BIC		#MC1,&KBDTCTL			;Stop TimerA from counting
			MOV		#00000h,&KBDTR			;Clear TimerA counter register
KBTNoTStop:
			BIC		#CCIFG+CCIE,&KBDTCCTL1	;Clear the interval expiration flag and
											; disable TimerA Compare 1 interrupt
			MOV		#00000h,&LastKey		;Also, clear the 'Last Pressed Key'
			POP		R4
			RETI


;----------------------------------------
; KBPwrInt Interrupt Service Routine (Called as simple function - Serviced by the dispatcher)
; This is an Interrupt Service Routine, that is called by Power Key press, while the CPU is
; powered up. It starts a counter, which when reaches the limit of 3 seconds, and the power
; key is still pressed, it switches off the circuitry, and enters an internal sleep!
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     :
; OTHER FUNCS   : None
KBPwrInt:	BIT.B	#KBD_KEYPWR,&KBD_INTES	;Make, or Break?
			JC		KBPIBreak				;Set => Break
			MOV		#PWOFFCNT +1,&PDCounter	;Setup the power off counter (+1 is for additional
											; debouncing time interrupt of Timer)
			MOV		#KeyDebounc,KBDTCCR0	;Setup TACCR0 for key debouncing time. This is the
											; first expiration checked for this key
			ADD		&KBDTR,&KBDTCCR0		;Add now
			BIC		#CCIFG,&KBDTCCTL0		;Clear timer expiration flag of Compare 2
			BIS		#CCIE,&KBDTCCTL0		;Enable Power Key interrupt
			BIS.B	#KBD_KEYPWR,&KBD_INTES	;Next interrupt is on Power button depressing
			BIC.B	#KBD_KEYPWR,&KBD_INTF	;Clear any pending interrupt from power button
			BIS		#MC1,&KBDTCTL			;Start TimerA Continuous Counting
;			BIC		#SCG0+SCG1+OSCOFF+CPUOFF,2(SP)	;Wake up the system if needed (uncomment)
			RET

KBPIBreak:	CMP		#PWOFFCNT +1,&PDCounter	;Is the key debouncing time expired?
			JEQ		KBPIB_NoKey				;No => Do not assume a Power Key pressing
			CMP		#KBUFSIZE,&KBuffLen		;Is the keyboard buffer full?
			JZ		KBPIB_NoPress			;Yes => Ignore the key pressing
			PUSH	R15
			MOV		&KBStPoint,R15			;Get the starting offset of the keyboard buffer
			ADD		&KBuffLen,R15			;Add the number of the occupied cells
			AND		#KBUFSIZE-1,R15			;MOD because this is a circular buffer
			ADD		#KeyBuffer,R15			;Add the starting memory of the buffer. Now R15
											; points to the first free cell in the keyboard
											; circular buffer
			MOV.B	#KBD_KEYPWR,0(R15)		;Store the current key press in buffer
			INC		&KBuffLen				;One more keypress in the key buffer
			POP		R15
			BIC		#SCG0+SCG1+OSCOFF+CPUOFF,2(SP)	;Wake up the system to use the new key
KBPIB_NoKey:MOV		#0FFFFh,&PDCounter		;Reset Power Down counter
			BIC.B	#KBD_KEYPWR,&KBD_INTES	;Next interrupt is when Power button is pressed
			BIC.B	#KBD_KEYPWR,&KBD_INTF	;Reset pending interrupt from Power button
			BIC		#CCIE+CCIFG,&KBDTCCTL0	;Stop interrupts from Timer Counter 0
			BIC		#MC1,&KBDTCTL
			MOV		#00000h,&KBDTR
KBPIB_NoPress:
			RET


;----------------------------------------
; P1Dispatch Interrupt Service Routine
; This is the dispatcher for directing the shared interrupt of Port1 to the corresponding
; interrupt handler, according to the interrupt source. When the interrupt source is the power
; button, the process called is the KBPwrInt. When the source is the keyboard then the
; function called if the KBDKeyPress!
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 2 (Call of the KBPwrInt)
; VARS USED     :
; OTHER FUNCS   : None
P1Dispatch:	BIT.B	#KBD_KEYPWR,&KBD_INTE	;Is the Power Button Interrupt enabled?
			JZ		P1DKbdInt
			BIT.B	#KBD_KEYPWR,&KBD_INTF	;Test for Power Key interrupt flag
			JZ		P1DKbdInt
			CALL	#KBPwrInt
P1DKbdInt:	BIT.B	#KBD_KMASK,&KBD_INTE	;Is the keyboard interrupt enabled?
			JNZ		KBDKeyPress
P1DEnd:		;MOV.B	#00000h,&KBD_INTF		;Clear interrupt flags of this port
			RETI


;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	KBD_Vector				;MSP430 Port 1 Interrupt Vector
			.short	P1Dispatch

			.sect	KBDTVECTOR1				;Keyboard Timer Vector for CCR1 etc. (Debouncing,
			.short	KBDTimerISR				; Repetition)

			.sect	KBDTVECTOR0				;Keyboard Timer Vector for CCR0 (Long press)
			.short	WakeMeUp
