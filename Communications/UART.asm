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
;*                                                                                           *
;*===========================================================================================*
;* Variables:                                                                                *
;* -----------                                                                               *
;*                                                                                           *
;*===========================================================================================*
;* Functions of the Library:                                                                 *
;* --------------------------                                                                *
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
RSUpDown:	.equ	BIT6					;Flags that the timer is used in Up/Down mode
RSCountDown:.equ	BIT7					;Flags that the timer counts towards down
											; direction
RSNeedDown:	.equ	BIT8					;Flags that a full period is considered when
											; counting down


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	UARTFlags, 2			;Flags to control the functionality of RS232
											; subsystem
			.bss	UARTTCounter, 4			;Counter for hit itterations of the timer until
											; considered expired (Long number = QuadByte)
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
; STACK USAGE   :
; VARS USED     :
; OTHER FUNCS   :
UARTTimerISR:
			CMP		#00000h,&UARTRxLen		;Are there any characters waiting in the queue?
			JEQ		TISR_Unused				;No => exit. No reason to wake up the system
			CMP		#00000h,&UARTTCounter+2	;Is the high word zeroed?
			JNE		TISR_NoWake				;No => Do not wake up the system... Keep counting
			CMP		#00000h,&UARTTCounter	;Is the itteration counter zeroed?
			JEQ		TISR_WakeUp				;Yes => Wake up the system
TISR_NoWake:
			DEC		&UARTTCounter			;else, decrement the itteration counter
			SUBC	#00000h,&UARTTCounter+2	;... all 32 bit counter value
			RETI							;and return to interrupted process

TISR_WakeUp:
			BIC		#LPM4,0(SP)				;Wake up
			BIS		#RSServe,&UARTFlags		;Flag the necessity to be serviced
TISR_Unused:
			MOV		#00000h,&COMMT_CCR		;Clear the counter to have the advantage of OUTx
											; following the counting direction in Up/Down mode
			BIC		#CCIE+CCIFG,&COMMT_CCTL	;Clear any pending interrupts and disable this
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
; VARS USED     : 6 = 2x Push + 1x Call
; OTHER FUNCS   : SetupTimer
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
RxSRBinTim:	CALL	#SetupTimer
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
