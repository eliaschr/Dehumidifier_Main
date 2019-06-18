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
			.bss	RSFlags, 2				;Flags to control the functionality of RS232
											; subsystem
			.bss	TCounter, 4				;Counter for hit itterations of the timer until
											; considered expired (Long number = QuadByte)
			.bss	TxBufStrt, 2			;Offset in transmition buffer of the first
											; character to be transmitted
			.bss	TxBufLen, 2				;Length of data waiting to be sent in the
											; transmition buffer
			.bss	RxBufStrt, 2			;Offset in reception buffer of the first character
											; received earlier by RS232
			.bss	RxBufLen, 2				;Number of bytes waiting to be read in the
											; reception buffer
			.bss	WakeLim, 2				;The wake up buffer limit. When the receiving
											; buffer reaches this limit it wakes up the system
											; to handle those data
			.bss	TxCBuf, TXBUFLEN		;Cyclic buffer to hold the data to be sent
			.bss	RxCBuf, RXBUFLEN		;Cyclic buffer to hold the data received


;----------------------------------------
; Constants
;========================================


;----------------------------------------
; Functions
;========================================
			.text
;Interrupt Service Routines must be global


;----------------------------------------
; UARTPInit
; Initialises the port pins used for the serial bus
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RS232ALL, RS232DIR, RS232RXD, RS232SEL, RS232TXD
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
; RS232TxISR
; Interrupt Service Routine that handles outgoing data
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 
; VARS USED     : None
; OTHER FUNCS   : 
RS232TxISR:
			CMP		#00000h,&TxBufLen		;Are there any data in transmit buffer?
			JZ		RTX_Exit				;No => Exit
			PUSH	R4
			MOV		&TxBufStrt,R4			;Get the starting pointer of transmit buffer
			MOV.B	TxCBuf(R4),&RS232TXBUF	;Send one byte from the buffer to the bus
			INC		R4						;Advance the starting pointer to the next byte
			CMP		#TXBUFLEN,R4			;Did we reach the end of physical buffer space?
			JNE		TxSR_RvtBuf				;No => Do not revert to the beginning
			MOV		#00000h,R4				;else move the pointer to the beginning of buffer
TxSR_RvtBuf:
			MOV		R4,&TxBufStrt			;Store the new starting pointer
			DEC		&TxBufLen				;One character less in transmit buffer
			JNZ		TxSR_NoDis				;Reached the end?
			BIC.B	#RS232TXIE,&RS232IE		;Yes => Disable this interrupt
TxSR_NoDis:	POP		R4						;else, just exit,restoring registers used
RTX_Exit:	RETI


;-------------------------------------------
; RS232RxISR
; Interrupt Service Routine that handles incomng data
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : According to the ISR called
; VARS USED     : None
; OTHER FUNCS   : 
RS232RxISR:
			CMP		#RXBUFLEN,&RxBufLen		;Is the receive buffer full?
			JEQ		RxSRFail				;Yes => Flag the failure and exit
			PUSH	R4						;Store used registers
			PUSH	R5
			MOV		&RxBufStrt,R4			;Get the starting pointer of the buffer
			ADD		&RxBufLen,R4			;Add the length of stored data
			CMP		#RXBUFLEN,R4			;Is it above the physical boundary of buffer?
			JL		RxSR_NoRvt				;No => Skip revert to its beginning
			SUB		#RXBUFLEN,R4			;else, Subtract the length of buffer to revert it
											; to its beginning
RxSR_NoRvt:	MOV.B	&RS232RXBUF,R5			;Get incoming byte
			BIT		#RSBinary,&RSFlags		;Are we in binary mode?
			JNZ		RxSRBinTim				;If yes => Do not filter incoming character; store
											; it as is
			CMP.B	#00Ah,R5				;Is it 0Ah (One of the line terminating values)
			JNE		RxSRNo0A				;No => OK, Check for other
			BIS		#RS0A+RSRxEol,&RSFlags	;Flag the character reception and the need to wake
											; up the system
			BIT		#RS0D,&RSFlags			;Was the last character 0Dh (the other new line
											; character)
			JZ		RxSRStore				;No => OK, Keep going on storing it
			BIC		#RS0A+RS0D,&RSFlags		;else, Clear both flags for character reception
			JMP		RxSR_WakeUp				;The second character is not stored. It just wakes
											; up the system
RxSRNo0A:	CMP.B	#00Dh,R5				;Is the received character 0Dh?
			JNE		RxSRNo0D				;No => OK, Store the character
			BIS		#RS0D+RSRxEol,&RSFlags	;Flag the reception of this character and the
											; necessity to wake up the system
			BIT		#RS0A,&RSFlags			;Was the last character a 0A?
			JZ		RxSRStore				;No => just store the character
			BIC		#RS0A+RS0D,&RSFlags		;else, clear the character reception flags
			JMP		RxSR_WakeUp				;and wake up the system. No need to store the
											; second character of the "New Line" sequence
RxSRBinTim:	CALL	#SetupTimer
RxSRNo0D:	BIC		#RS0A+RS0D,&RSFlags		;Ordinary character => No 0Ah or 0Dh
RxSRStore:	MOV.B	R5,RxCBuf(R4)			;Insert the newly received value
			INC		&RxBufLen				;Increment the length of stored data in the buffer
			BIT		#RSRxEol,&RSFlags		;Do we need to force wake up?
			JNZ		RxSR_WakeUp				;Yes => Wake the system up
			CMP		&WakeLim,&RxBufLen		;Do we need to wake the system up?
			JL		RxSR_NoWake				;No =>  Skip waking up
RxSR_WakeUp:
			BIC		#RSRxEol,&RSFlags		;Clear this flag if it is set
			BIS		#RSServe,&RSFlags		;Flag the need to be served
			BIC		#CPUOFF+SCG0+SCG1+OSCOFF,4(SP)	;Wake the system up
RxSR_NoWake:
			POP		R5						;Restore used registers
			POP		R4
			RETI
RxSRFail:	BIS		#RSRxError,&RSFlags		;Flag the reception error
			BIC		#RS0A+RS0D,&RSFlags		;No matter what the previous character was...
			BIC.B	#RS232RXIE,&RS232IFG	;Clear receive interrupt
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
; VARS USED     : None
; OTHER FUNCS   : 
UARTIDispatcher:
			ADD		&UART_IV,PC
			RETI							;0: No interrupt
			JMP		RS232RxISR				;2: Received a byte (UCRXIFG)
			JMP		RS232TxISR				;4: Transit buffer ready (UCTXIFG)
			RETI							;6: Start bit received (UCSTTIFG)
			RETI							;8: Transmission completed (UCTXCPTIFG)


;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	COMMU_Vector			;UART vector
			.short	UARTIDispatcher			;Points to the dispatcher ISR
