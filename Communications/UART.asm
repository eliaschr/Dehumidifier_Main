;*********************************************************************************************
;* UART - RS232 Library                                                                      *
;*-------------------------------------------------------------------------------------------*
;* UART.asm                                                                                  *
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
;* Library needed for RS232 connectivity to other hardware subsystems.                       *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"UART - RS232 Library"
			.width	94
			.tab	4

;*===========================================================================================*
;* Names And Values:                                                                         *
;* ------------------                                                                        *
;* The UARTFlags variable is consisted of bit flags that present the current status of the   *
;* UART subsystem. Their meanings are explained in the following definitions                 *
;* RSServe   : Flags that RS232 subsystem needs attention                                    *
;* RSRxError : Flags that a character was received while the buffer was full                 *
;* RS0A      : Last character received was 0Ah (perhaps part of a newline character)         *
;* RS0D      : Last character received was 0Dh (perhaps part of a newline character)         *
;* RSRxEol   : Flags that the system has just received a new line character (force wake up   *
;*              by RX ISR)                                                                   *
;* RSBinary  : Flags binary mode. It does not filter any characters and the wake up is       *
;*              controlled by timer                                                          *
;*                                                                                           *
;*===========================================================================================*
;* Variables:                                                                                *
;* -----------                                                                               *
;* UARTFlags   : Flags to control the functionality of RS232 subsystem                       *
;* UARTTxStrt  : Offset in transmition buffer of the first character to be transmitted       *
;* UARTTxLen   : Length of data waiting to be sent in the transmition buffer                 *
;* UARTRxStrt  : Offset in reception buffer of the first character received earlier by RS232 *
;* UARTRxLen   : Number of bytes waiting to be read in the reception buffer                  *
;* UARTWakeLim : The wake up buffer limit. When the receiving buffer reaches this limit it   *
;*                wakes up the system to handle received data                                *
;* UARTTxCBuf  : Cyclic buffer to hold the data to be sent                                   *
;* UARTRxCBuf  : Cyclic buffer to hold the data received                                     *
;*                                                                                           *
;*===========================================================================================*
;* Functions of the Library:                                                                 *
;* --------------------------                                                                *
;* UARTPInit       : Initialises the port pins used for the serial bus                       *
;* UARTCInit       : Initialises the USCI that is used for RS232 communications              *
;* UARTSysInit     : Initialises the UART-RS232 system variables and Timer module            *
;* UARTEnableInts  : Enables the receiving interrupt of UART                                 *
;* UARTDisableInts : Disables the receiving interrupt of UART                                *
;* UARTSetBinMode  : Sets the systen to binary mode, no EOL filtering is done, data are      *
;*                    considered binary                                                      *
;* UARTSetTxtMode  : Sets the system to Text mode. EOL filtering is performed by checking    *
;*                    the existance of at least one character of CR or LF (or both)          *
;* UARTGetMode     : Returnes the current mode of reception (text or binary)                 *
;* UARTSetupTimer  : Starts or restarts the timeout reception timer                          *
;* UARTCheckServe  : Checks if there is the need to consume received data                    *
;* UARTSend        : Sends a byte of data to the UART stream                                 *
;* UARTReceive     : Gets the current byte from the reception queue                          *
;* UARTTimerISR    : The TimerA timeout interrupt service routine                            *
;* UARTTxISR       : Transmission interrupt service routine                                  *
;* UARTRxISR       : Reception interrupt service routine                                     *
;* UARTIDispatcher : UART Interrupt Service Dispatcher. The interrupt of the UART is multi-  *
;*                    plexed, so the dispatcher looks which one is the source of the         *
;*                    interrutp and dispatches the code to the correct service routine       *
;*                                                                                           *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Board.h43"			;Hardware Connections
			.include "Definitions.h43"		;Global definitions
			.include "UART.h43"				;Local definitions
			.include "UARTAutoDefs.h43"		;Auto definitions according to settings in
											; UART.h43


;----------------------------------------
; Definitions
;========================================
RSServe:	.equ	BIT0					;Flags that RS232 subsystem needs attention
RSRxError:	.equ	BIT1					;Flags that a character was received while the
											; buffer was full
RS0A:		.equ	BIT2					;Last character received was 0Ah (perhaps part of
											; a newline character)
RS0D:		.equ	BIT3					;Last character received was 0Dh (perhaps part of
											; a newline character)
RSRxEol:	.equ	BIT4					;Flags that the system has just received a new
											; line character (force wake up by RX ISR)
RSBinary:	.equ	BIT5					;Flags binary mode. It does not filter any
											; characters and the wake up is controlled by
											; timer


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	UARTFlags, 2			;Flags to control the functionality of RS232
											; subsystem
			.bss	UARTTxStrt, 2			;Offset in transmition buffer of the first
											; character to be transmitted
			.bss	UARTTxLen, 2			;Length of data waiting to be sent in the
											; transmition buffer
			.bss	UARTRxStrt, 2			;Offset in reception buffer of the first character
											; received earlier by RS232
			.bss	UARTRxLen, 2			;Number of bytes waiting to be read in the
											; reception buffer
			.bss	UARTWakeLim, 2			;The wake up buffer limit. When the receiving
											; buffer reaches this limit it wakes up the system
											; to handle received data
			.bss	UARTTxCBuf, UARTTXSIZE	;Cyclic buffer to hold the data to be sent
			.bss	UARTRxCBuf, UARTRXSIZE	;Cyclic buffer to hold the data received


;----------------------------------------
; Constants
;========================================


;----------------------------------------
; Functions
;========================================
			.text
;Interrupt Service Routines must be global
			.global	UARTIDispatcher
			.global	UARTTimerISR


;----------------------------------------
; UARTPInit
; Initialises the port pins used for the serial bus
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : COMM_ALL, COMM_SEL0, COMM_SEL0VAL, COMM_SEL1, COMM_SEL1VAL
; OTHER FUNCS   : None
UARTPInit:
			BIC.B	#COMM_ALL,&COMM_SEL0	;Clear the selector flags
			BIC.B	#COMM_ALL,&COMM_SEL1
			BIS.B	#COMM_SEL0VAL,&COMM_SEL0;Set them according to the selected eUSCI_A port
			BIS.B	#COMM_SEL1VAL,&COMM_SEL1
			RET


;----------------------------------------
; UARTCInit
; Initialises the USCI that is used for RS232 communications
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : BRx, CTL0VAL, CTL1VAL, MCTLVAL, COMM_BRW, COMM_CTLW0, COMM_CTLW1, COMM_MCTLW
; OTHER FUNCS   : None
UARTCInit:
			BIS.B	#UCSWRST,&COMM_CTLW1	;Keep USCI in reset mode
			MOV.B	#BRx,&COMM_BRW			;Set the baud rate prescaler
			MOV.B	#CTL0VAL,&COMM_CTLW0	;Set Data format
			MOV.B	#CTL1VAL,&COMM_CTLW1	;Set the control of the bus
			MOV.B	#MCTLVAL,&COMM_MCTLW	;Set the Modulation Control register
			BIC.B	#UCSWRST,&COMM_CTLW1	;Release Serial module
			RET


;----------------------------------------
; UARTSysInit
; Initialises the UART-RS232 system variables and Timer module
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : COMMTCCR1, COMMTCCTL1, UARTFlags, UARTRxLen, UARTRxStrt, UARTRXWAKELIM,
;                 UARTTxLen, UARTTxStrt, UARTWakeLim
; OTHER FUNCS   : None
UARTSysInit:
			MOV		#000h,&UARTTxStrt		;Move starting pointer to the beginning of buffer
			MOV		#000h,&UARTTxLen		;Transmition buffer does not contain data
			MOV		#000h,&UARTRxStrt		;Move starting pointer to the beginning of buffer
			MOV		#000h,&UARTRxLen		;Reception buffer does not contain data
			MOV		#00000h,&UARTFlags		;Reset flags

			MOV		#UARTRXWAKELIM,&UARTWakeLim	;Setup the default wake up limit
			
			MOV		#TASSEL_1,&COMMTCTL		;Timer is clocked by AClk (32768)
			MOV		#00000h,&COMMTR			;Clear "Now"
			MOV		#00000h,&COMMTCCTL0		;Compare mode, no interrupts (yet)
			MOV		#00000h,&COMMTEX0		;No extension to input clock divider
			MOV		#UARTWAKEUPTICKS,&COMMTCCR0	;Set the point of interrupt to 10 characters
			RET


;----------------------------------------
; UARTEnableInts
; Enables the receiving interrupt of RS232
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : COMM_IE, COMM_IFG
; OTHER FUNCS   : None
UARTEnableInts:
			BIC.B	#UCRXIFG,&COMM_IFG		;Clear any pending interrupts of UCAxRX
			BIS.B	#UCRXIE,&COMM_IE		;Enable the reception interrupt of RS232
			RET


;----------------------------------------
; UARTDisableInts
; Disables the receiving interrupt of UART. Transmition interrupt is disabled automatically
; when there is no data to be sent
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : COMM_IE, COMM_IFG
; OTHER FUNCS   : None
UARTDisableInts:
			BIC.B	#UCRXIFG,&COMM_IFG		;Clear any pending interrupts of UCAxRX
			BIC.B	#UCRXIE,&COMM_IE		;Disable the reception interrupt of RS232
			RET


;----------------------------------------
; UARTSetBinMode
; Sets the receiving mode to Binary. No data is filtered upon receiving. Timer wakes up the
; system to handle the received data
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RSBinary, UARTFlags
; OTHER FUNCS   : None
UARTSetBinMode:
			BIS		#RSBinary,&UARTFlags	;Set binary flag
			RET


;----------------------------------------
; UARTSetTxtMode
; Sets the receiving mode to text. New line sequences are filtered. No timer is used
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RSBinary, UARTFlags
; OTHER FUNCS   : None
UARTSetTxtMode:
			BIC		#CCIE | CCIFG,&UARTCCTL1;Disable timer interrupt in this mode
			BIC		#RSBinary,&UARTFlags	;Clear binary flag
			RET


;----------------------------------------
; UARTGetMode
; Gets the receiving mode
; INPUT         : None
; OUTPUT        : Carry flag is set on binary mode, reset on text mode
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RSBinary, UARTFlags
; OTHER FUNCS   : None
UARTGetMode:
			BIT		#RSBinary,&UARTFlags	;Test binary flag
			RET


;----------------------------------------
; UARTSetupTimer
; (Re)Starts the timeout timer counting for binary reception.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 2 = 1x Push
; VARS USED     : COMMTCCR0, COMMTCTL, COMMTCCTL0, COMMTR, UARTWAKEUPTICKS
; OTHER FUNCS   : None
UARTSetupTimer:
			PUSH	SR						;Keep the state of general interrupts flag
			DINT							;Timer should not disturb us
			NOP
			MOV		#UARTWAKEUPTICKS,&COMMTCCR0	;Set the offset in timer ticks
			ADD		#COMMTR,&COMMTCCR0		;Add "Now"
			BIC		#CCIFG,&COMMTCCTL0		;No pending interrupt from timer CCR0 limit
			BIS		#CCIE,&COMMTCCTL0		;Enable interrut of CCR0 limit
			BIS		#MC_2,&COMMTCTL			;Start in Continuous mode
			POP		SR						;Restore interrupt state
			RET


;----------------------------------------
; UARTCheckServe
; Gets the status of Serve flag. After reading the RSServe flag, it resets it
; INPUT         : None
; OUTPUT        : Carry flag is set on need to get the reception buffer's data
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RSServe, UARTFlags
; OTHER FUNCS   : None
UARTCheckServe:
			BIT		#RSServe,&UARTFlags		;Carry flag contains the value of Serve flag
			BIC		#RSServe,&UARTFlags		;Clear this flag
			RET


;----------------------------------------
; UARTSend
; Sends a byte to the RS232 bus
; INPUT         : R4 contains the byte to be sent
; OUTPUT        : Carry flag is set on error (buffer full), cleared on success
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 2 = 1x Push
; VARS USED     : COMM_IE, COMM_IFG, COMM_TXBUF, UARTTxCBuf, UARTTxLen, UARTTXSIZE, UARTTxStrt
; OTHER FUNCS   : None
UARTSend:
			CMP		#000h,&UARTTxLen		;Do we have characters in the buffer?
			JZ		RSS_Send				;No => Try to send the byte at once
			CMP		#UARTTXSIZE,&UARTTxLen	;Is the buffer full?
			JHS		RSS_Exit				;Yes => exit with carry flag set
			PUSH	SR						;Store the state of interrupts
			DINT							;Pause interrupts for a little bit
			NOP
RSS_Store:	MOV		&UARTTxStrt,R5			;Get the strting offset of the first character
			ADD		&UARTTxLen,R5			;Add the length of data stored in the buffer to
											; find the first empty cell in it
			POP		SR						;Restore interrupts
			CMP		#UARTTXSIZE,R5			;Passed the end of physical buffer?
			JLO		RSSNoRvt				;No => Do not revert to its beginning
			SUB		#UARTTXSIZE,R5			;else bring it inside buffer's bounds
RSSNoRvt:	MOV.B	R4,UARTTxCBuf(R5)		;Store the byte into the buffer
			INC		&UARTTxLen				;Increment the stored buffer data length by one
			CLRC							;Clear carry to flag success
RSS_Exit:	RET
RSS_Send:	PUSH	SR						;Store interrupts' status
			DINT							;Disable them
			NOP
			BIT.B	#UCTXIFG,&COMM_IFG		;Is the buffer in use?
			JZ		RSS_Store				;Yes => Store the byte for later transmition
			POP		SR						;Restore interrupts' status
			MOV.B	R4,&COMM_TXBUF			;Send it now
			BIS.B	#UCTXIE,&COMM_IE		;Enable transmit interrupt
			CLRC							;Clear carry to flag success
			RET								;and exit


;----------------------------------------
; UARTReceive
; Fetches a byte from the RS232 reception buffer
; INPUT         : None
; OUTPUT        : R4 contains the byte fetched. Carry flag is set on error (buffer full) or
;                 cleared on success
; REGS USED     : R4, R5
; REGS AFFECTED : R4, R5
; STACK USAGE   : 2 = 1x Push
; VARS USED     : UARTRxCBuf, UARTRxLen, UARTRXSIZE, UARTRxStrt
; OTHER FUNCS   : None
UARTReceive:
			CMP		#00000h,&UARTRxLen		;Is there any data in the receiving buffer?
			JZ		RSRecFail				;No => exit with carry flag set
			MOV		&UARTRxStrt,R5			;Get the starting offset of the first character
			MOV.B	UARTRxCBuf(R5),R4		;Get this byte
			PUSH	SR						;Store the state of interrupts
			DINT							;Both start and length should be changed before
											; another process use them
			DEC		&UARTRxLen				;One character less in the buffer
			INC		R5						;Advance the starting pointer to the next stored
											; character
			CMP		#UARTRXSIZE,R5			;Crossed the physical buffer's boundary?
			JLO		RSRecNoRvt				;No => do not revert to the beginning
			MOV		#00000h,R5				;else, move pointer to the beginning of the buffer
RSRecNoRvt:	MOV		R5,&UARTRxStrt			;Store the starting pointer
			POP		SR						;Restore interrupts
			CLRC							;Flag success
RSRecFail:	RET								;and return to caller


;----------------------------------------
; Interrupt Service Routines
;========================================
;----------------------------------------
; UARTTimerISR
; When the timer is fired, the system has been idle for 10 characters time length. This means
; that if there are any characters in the reception buffer, the system needs to wake up and
; consume these characters
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : COMMTCCTL0, COMMTR, RSServe, UARTFlags, UARTRxLen
; OTHER FUNCS   : None
UARTTimerISR:
			CMP		#00000h,&UARTRxLen		;Are there any characters waiting in the queue?
			JEQ		TISR_Unused				;No => exit. No reason to wake up the system
TISR_WakeUp:
			BIC		#LPM4,0(SP)				;Wake up
			BIS		#RSServe,&UARTFlags		;Flag the necessity to be serviced
TISR_Unused:
			MOV		#00000h,&COMMTR			;Clear the counter
			BIC		#CCIE+CCIFG,&COMMTCCTL0	;Clear any pending interrupts and disable this
											; timer's interrupt
			RETI							;Return to interrupted process


;----------------------------------------
; UARTTxISR
; Interrupt Service Routine that handles outgoing data
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 2 = 1x Push
; VARS USED     : COMM_IE, COMM_TXBUF, UARTTxCBuf, UARTTxLen, UARTTXSIZE, UARTTxStrt
; OTHER FUNCS   : None
UARTTxISR:
			CMP		#00000h,&UARTTxLen		;Are there any data in transmit buffer?
			JZ		RTX_Exit				;No => Exit
			PUSH	R4
			MOV		&UARTTxStrt,R4			;Get the starting pointer of transmit buffer
			MOV.B	UARTTxCBuf(R4),&COMM_TXBUF	;Send one byte from the buffer to the bus
			INC		R4						;Advance the starting pointer to the next byte
			CMP		#UARTTXSIZE,R4			;Did we reach the end of physical buffer space?
			JNE		TxSR_RvtBuf				;No => Do not revert to the beginning
			MOV		#00000h,R4				;else move the pointer to the beginning of buffer
TxSR_RvtBuf:
			MOV		R4,&UARTTxStrt			;Store the new starting pointer
			DEC		&UARTTxLen				;One character less in transmit buffer
			JNZ		TxSR_NoDis				;Reached the end?
			BIC.B	#UCTXIE,&COMM_IE		;Yes => Disable this interrupt
TxSR_NoDis:	POP		R4						;else, just exit,restoring registers used
RTX_Exit:	RETI


;-------------------------------------------
; UARTRxISR
; Interrupt Service Routine that handles incomng data
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : COMM_RXBUF, RS0A, RS0D, RSBinary, RSRxError, RSRxEol, RSServe, UARTFlags,
;                 UARTRxCBuf, UARTRxLen, UARTRXSIZE, UARTRxStrt, UARTWakeLim
; VARS USED     : 8 = 2x Push + 1x Call + 2 by called function
; OTHER FUNCS   : UARTSetupTimer
UARTRxISR:
			CMP		#UARTRXSIZE,&UARTRxLen	;Is the receive buffer full?
			JEQ		RxSRFail				;Yes => Flag the failure and exit
			PUSH	R4						;Store used registers
			PUSH	R5
			MOV		&UARTRxStrt,R4			;Get the starting pointer of the buffer
			ADD		&UARTRxLen,R4			;Add the length of stored data
			CMP		#UARTRXSIZE,R4			;Is it above the physical boundary of buffer?
			JL		RxSR_NoRvt				;No => Skip revert to its beginning
			SUB		#UARTRXSIZE,R4			;else, Subtract the length of buffer to revert it
											; to its beginning
RxSR_NoRvt:	MOV.B	&COMM_RXBUF,R5			;Get incoming byte
			BIT		#RSBinary,&UARTFlags	;Are we in binary mode?
			JNZ		RxSRBinTim				;If yes => Do not filter incoming character; store
											; it as is
			CMP.B	#00Ah,R5				;Is it 0Ah (One of the line terminating values)
			JNE		RxSRNo0A				;No => OK, Check for other
			BIS		#RS0A | RSRxEol,&UARTFlags;Flag the character reception and the need to
											; wake up the system
			BIT		#RS0D,&UARTFlags		;Was the last character 0Dh (the other new line
											; character)
			JZ		RxSRStore				;No => OK, Keep going on storing it
			BIC		#RS0A | RS0D,&UARTFlags	;else, Clear both flags for character reception
			JMP		RxSR_WakeUp				;The second character is not stored. It just wakes
											; up the system
RxSRNo0A:	CMP.B	#00Dh,R5				;Is the received character 0Dh?
			JNE		RxSRNo0D				;No => OK, Store the character
			BIS		#RS0D | RSRxEol,&UARTFlags;Flag the reception of this character and the
											; necessity to wake up the system
			BIT		#RS0A,&UARTFlags		;Was the last character a 0A?
			JZ		RxSRStore				;No => just store the character
			BIC		#RS0A | RS0D,&UARTFlags	;else, clear the character reception flags
			JMP		RxSR_WakeUp				;and wake up the system. No need to store the
											; second character of the "New Line" sequence
RxSRBinTim:	CALL	#UARTSetupTimer			;Reset timeout counter
RxSRNo0D:	BIC		#RS0A | RS0D,&UARTFlags	;Ordinary character => No 0Ah or 0Dh
RxSRStore:	MOV.B	R5,UARTRxCBuf(R4)		;Insert the newly received value
			INC		&UARTRxLen				;Increment the length of stored data in the buffer
			BIT		#RSRxEol,&UARTFlags		;Do we need to force wake up?
			JNZ		RxSR_WakeUp				;Yes => Wake the system up
			CMP		&UARTWakeLim,&UARTRxLen	;Do we need to wake the system up?
			JL		RxSR_NoWake				;No =>  Skip waking up
RxSR_WakeUp:
			BIC		#RSRxEol,&UARTFlags		;Clear this flag if it is set
			BIS		#RSServe,&UARTFlags		;Flag the need to be served
			BIC		#LPM4,4(SP)				;Wake the system up
RxSR_NoWake:
			POP		R5						;Restore used registers
			POP		R4
			RETI
RxSRFail:	BIS		#RSRxError,&UARTFlags	;Flag the reception error
			BIC		#RS0A | RS0D,&UARTFlags	;No matter what the previous character was...
			RETI
			
			
;----------------------------------------
; UARTIDispatcher
; This is the Interrupt Service Routine called whenever there is eUSCI event. It dispatches
; to the real ISR that will serve the specific event.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : According to the ISR called
; VARS USED     : COMM_IV
; OTHER FUNCS   : UARTRxISR, UARTTxISR
UARTIDispatcher:
			ADD		&COMM_IV,PC
			RETI							;0: No interrupt
			JMP		UARTRxISR				;2: Received a byte (UCRXIFG)
			JMP		UARTTxISR				;4: Transit buffer ready (UCTXIFG)
			RETI							;6: Start bit received (UCSTTIFG)
			RETI							;8: Transmission completed (UCTXCPTIFG)


;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	COMMU_Vector			;UART vector
			.short	UARTIDispatcher			;Points to the dispatcher ISR

			.sect	COMMTVECTOR0			;UART Timer vector
			.short	UARTTimerISR			;Currently to timeout service routine
