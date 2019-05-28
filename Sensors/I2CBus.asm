;*********************************************************************************************
;* I2C Bus Support Library                                                                   *
;*-------------------------------------------------------------------------------------------*
;* I2CBus.asm                                                                                *
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
;* Library that creates the infastructure to use the I2C bus of the microcontroller. It can  *
;* be used to communicate to EEPROMs, Sensorc e.t.c.                                         *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"I2C Bus Support Library"
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
;*===========================================================================================*
;* Predefined Definitions Expected by the Library:                                           *
;* ------------------------------------------------                                          *
;*                                                                                           *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Board.h43"			;Hardware Connections
			.include "Definitions.h43"		;Global definitions
			.include "I2CBus.h43"			;Local definitions
			.include "I2CAutoDefs.h43"		;Auto definitions according to settings in
											; I2CBus.h43


;----------------------------------------
; Definitions
;========================================


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	I2CTxBuff, TXBUFFLEN	;I2C Transmission buffer
			.bss	I2CRxBuff, RXBUFFLEN	;I2C Transmission buffer
			.bss	I2CTxStrt, 2			;Starting offset of transmission buffer
			.bss	I2CTxLen, 2				;Length of data in transmission buffer
			.bss	I2CRxStrt, 2			;Starting offset of reception buffer
			.bss	I2CRxLen, 2				;Length of data written in reception buffer


;----------------------------------------
; Constants
;========================================


;----------------------------------------
; Functions
;========================================
			.text


;----------------------------------------
; I2CPInit
; Initialize the associated eUSCI pins to be used as I2C
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : I2C_SEL0VAL, I2C_SEL1VAL, I2CP_MASK, I2CP_SEL0, I2CP_SEL1
; OTHER FUNCS   : None
I2CPInit:	BIC.B	#I2CP_MASK,&I2CP_SEL0	;Clear the selection bits used byt this I2C
			BIC.B	#I2CP_MASK,&I2CP_SEL1	; in both Special Function Selection registers
			BIS.B	#I2C_SEL0VAL,&I2CP_SEL0	;Now set them as supposed to use them as I2C
			BIS.B	#I2C_SEL1VAL,&I2CP_SEL1
			RET


;----------------------------------------
; I2CInit
; Initialize the I2C bus to be used for Humidity and Temperature sensor
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : I2C_BPSDIV, I2CU_BRW, I2CU_CTLW0, I2CU_CTLW1, 
; OTHER FUNCS   : None
I2CInit:	BIS		#UCSWRST,&I2CU_CTLW0	;Keep associated module in reset to configure it
			BIS		#UCMODE_3 | UCMST | UCSYNC,&I2CU_CTLW0
											;Set I2C master mode, in sync
			BIC		#UCASTP_3,&I2CU_CTLW1	;Clear both bits of STOP generation mode (No auto-
											; matic STOP condition)
			MOV		#I2C_BPSDIV,&I2CU_BRW	;Set divider for the correct bit rate
			BIC		#UCSWRST,&I2CU_CTLW0	;Stop reset mode. I2C is ready to be used
			RET
			

;----------------------------------------
; I2CStartTx
; Produces a Start condition on I2C bus and sends the Address byte. After that, it is ready to
; transmit more bytes
; INPUT         : R4 contains the Slave to be addressed
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : I2CU_CTLW0, I2CU_I2CSA
; OTHER FUNCS   : None
I2CStartTx:	MOV		R4,&I2CU_I2CSA			;Set the slave address to be transmitted
			BIS		#UCTR,&I2CU_CTLW0		;Going to transmit data to the slave
			BIS		#UCTXSTT,&I2CU_CTLW0	;Generate the Start condition and send the address
			RET


;----------------------------------------
; I2CStartRx
; Produces a Start condition on I2C bus and sends the Address byte. The bus is configures in
; Receiver mode, so it expects to receive data from the slave
; INPUT         : R4 contains the Slave to be addressed
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : I2CU_CTLW0, I2CU_I2CSA
; OTHER FUNCS   : None
I2CStartRx:	MOV		R4,&I2CU_I2CSA			;Set the slave address to be transmitted
			BIC		#UCTR,&I2CU_CTLW0		;Going to receive data to the slave
			BIS		#UCTXSTT,&I2CU_CTWL0	;Generate the Start condition and send the address
			RET


;----------------------------------------
; I2CReadBuf
; Reads a byte from the reception buffer, if there is any
; INPUT         : None
; OUTPUT        : R4 contains the byte read from I2C Reception Buffer. If there was no data
;                  available, R4 is reset and Carry Flag is set.
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : 
; OTHER FUNCS   : None
I2CReadBuf:	MOV.B	#000h,R4
			CMP		#00000h,&I2CRxLen
			JNE		I2CRxNo
			PUSH	SR						;Store the state of the interrupts
			MOV		&I2CRxStrt,R4			;Get the starting pointer
			ADD		#I2CRxBuff,R4			;Add the starting offset of the buffer
			MOV.B	@R4,R4					;Get the byte from the buffer
			DEC		&I2CRxLen				;One byte less in buffer
			POP		SR						;Restore Interrupts
			CLRC							;Clear carry. R4 contains a byte
I2CRxNo:	;SETC							;Came here from a CMP #O,... When 0, the carry
											; flag is set, so no need to do it again here.
											; Added only for clarity
			RET


;----------------------------------------
; Interrupt Service Routines
;========================================


;----------------------------------------
; Interrupt Vectors
;========================================

